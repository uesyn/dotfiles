package manager

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"time"

	"github.com/go-logr/logr"
	"github.com/moby/term"
	"github.com/uesyn/devbox/devbox"
	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/uesyn/devbox/kubernetes/scheme"
	"github.com/uesyn/devbox/manager/info"
	"github.com/uesyn/devbox/mutator"
	"github.com/uesyn/devbox/release"
	"github.com/uesyn/devbox/template"
	"github.com/uesyn/devbox/util"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

type Manager interface {
	Run(ctx context.Context, templateName, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Delete(ctx context.Context, devboxName, namespace string) error
	Update(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Exec(ctx context.Context, devboxName, namespace string, command []string, envs map[string]string) error
	PortForward(ctx context.Context, devboxName, namespace string, forwardedPorts []string, addresses []string) error
	Start(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Stop(ctx context.Context, devboxName, namespace string) error
	List(ctx context.Context, namespace string) ([]info.DevboxInfoAccessor, error)
	Protect(ctx context.Context, devboxName, namespace string) error
	Unprotect(ctx context.Context, devboxName, namespace string) error
	Events(ctx context.Context, devboxName, namespace string) (*corev1.EventList, error)
}

type manager struct {
	scheme       *runtime.Scheme
	restConfig   *rest.Config
	unstructured *client.UnstructuredClient
	clientset    kubernetes.Interface
	loader       template.Loader
	store        release.Store
}

var _ Manager = (*manager)(nil)

func New(restConfig *rest.Config, s release.Store, loader template.Loader) *manager {
	return &manager{
		scheme:       scheme.Scheme,
		unstructured: client.NewUnstructuredClient(restConfig),
		clientset:    kubernetes.NewForConfigOrDie(restConfig),
		store:        s,
		loader:       loader,
	}
}

func (m *manager) Run(ctx context.Context, templateName, devboxName, namespace string, mutators ...mutator.PodMutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	logger.V(1).Info("create devbox release")
	d, err := m.loader.Load(templateName, devboxName, namespace)
	if err != nil {
		return fmt.Errorf("failed to load template: %w", err)
	}
	r := &release.Release{
		Name:         devboxName,
		Namespace:    namespace,
		TemplateName: templateName,
		Objects:      d.ToUnstructureds(),
	}

	if err := m.store.Create(ctx, devboxName, namespace, r); err != nil {
		return err
	}

	failureHandler := func() {
		if err := m.deleteDevboxPod(ctx, d); err != nil {
			logger.Error(err, "failed to clean up devbox pod")
			return
		}
		if err := m.deleteDependencies(ctx, d); err != nil {
			logger.Error(err, "failed to clean up devbox dependencies")
			return
		}
		logger.Info("clean up devbox release")
		if err := m.store.Delete(ctx, devboxName, namespace); err != nil {
			logger.Error(err, "failed to clean up devbox release")
		}
	}

	if err := m.applyDependencies(ctx, d); err != nil {
		failureHandler()
		return fmt.Errorf("failed to create devbox dependencies: %w", err)
	}
	if err := m.createDevboxPod(ctx, d, mutators...); err != nil {
		failureHandler()
		return fmt.Errorf("failed to create devbox devbox: %w", err)
	}
	return nil
}

func (m *manager) createDevboxPod(ctx context.Context, d devbox.Devbox, mutators ...mutator.PodMutator) error {
	pod, err := d.GetDevboxPod(mutators...)
	if err != nil {
		return err
	}
	return m.create(ctx, false, pod)
}

func (m *manager) create(ctx context.Context, ignoreAlreadyExists bool, objs ...*unstructured.Unstructured) error {
	for _, obj := range objs {
		gvk := obj.GroupVersionKind()
		l := logr.FromContextOrDiscard(ctx).WithValues("objKind", gvk.Kind, "objName", obj.GetName())
		l.V(2).Info("create object", "obj", obj)
		_, err := m.unstructured.Create(ctx, obj, client.CreateOptions{})
		if ignoreAlreadyExists && apierrors.IsAlreadyExists(err) {
			l.Info("object has already existed", "obj", obj)
			continue
		}
		if err != nil {
			l.Error(err, "failed to create")
			return err
		}
		l.Info("object was created")
	}
	return nil
}

func (m *manager) applyDependencies(ctx context.Context, d devbox.Devbox) error {
	return m.apply(ctx, d.GetDependencies()...)
}

func (m *manager) apply(ctx context.Context, objs ...*unstructured.Unstructured) error {
	for _, obj := range objs {
		gvk := obj.GroupVersionKind()
		l := logr.FromContextOrDiscard(ctx).WithValues("objKind", gvk.Kind, "objName", obj.GetName())
		l.V(2).Info("apply object", "obj", obj)
		opts := client.PatchOptions{
			Force:        util.Pointer(true),
			FieldManager: "devbox",
		}
		if _, err := m.unstructured.Apply(ctx, obj, opts); err != nil {
			l.Error(err, "failed to apply")
			return err
		}
		l.Info("object was applied")
	}
	return nil
}

func (m *manager) Delete(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if apierrors.IsNotFound(err) {
		logger.Info("devbox already deleted")
		return nil
	}
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	if r.Protect {
		return fmt.Errorf("protected")
	}

	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		return err
	}
	if err := m.deleteDevboxPod(ctx, d); err != nil {
		return fmt.Errorf("failed to delete devbox pod: %w", err)
	}
	if err := m.deleteDependencies(ctx, d); err != nil {
		return fmt.Errorf("failed to delete devbox dependencies: %w", err)
	}
	if err := m.waitForDevboxPodTerminated(ctx, d); err != nil {
		return fmt.Errorf("failed to wait devbox pod terminated: %w", err)
	}
	return m.store.Delete(ctx, devboxName, namespace)
}

func (m *manager) deleteDevboxPod(ctx context.Context, d devbox.Devbox) error {
	pod, err := d.GetDevboxPod()
	if err != nil {
		return err
	}
	return m.delete(ctx, pod)
}

func (m *manager) deleteDependencies(ctx context.Context, d devbox.Devbox) error {
	return m.delete(ctx, d.GetDependencies()...)
}

func (m *manager) delete(ctx context.Context, objs ...*unstructured.Unstructured) error {
	for _, obj := range objs {
		gvk := obj.GroupVersionKind()
		l := logr.FromContextOrDiscard(ctx).WithValues("objKind", gvk.Kind, "objName", obj.GetName())
		l.V(2).Info("delete object", "obj", obj)
		err := m.unstructured.Delete(ctx, obj, client.DeleteOptions{})
		if err != nil && !apierrors.IsNotFound(err) {
			return err
		}
		l.Info("object was deleted")
	}
	return nil
}

func (m *manager) Exec(ctx context.Context, devboxName, namespace string, command []string, envs map[string]string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return err
	}
	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		return fmt.Errorf("failed to load devbox: %w", err)
	}

	stdin, stdout, stderr := term.StdStreams()
	opts := client.ExecOptions{
		Stdin:     stdin,
		Stdout:    stdout,
		Stderr:    stderr,
		Container: "devbox", // TODO: Select container with selector.
		Command:   command,
		Envs:      envs,
	}

	if err := m.waitForDevboxPodReady(ctx, d); err != nil {
		return fmt.Errorf("coudn't wait for devbox pod ready")
	}

	pod, err := d.GetDevboxPod()
	if err != nil {
		return err
	}
	return m.unstructured.Exec(ctx, pod, opts)
}

func (m *manager) PortForward(ctx context.Context, devboxName, namespace string, forwardedPorts []string, addresses []string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	if len(forwardedPorts) == 0 {
		return errors.New("must set forwarded ports")
	}
	if len(addresses) == 0 {
		return errors.New("must set address to be bind")
	}

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return err
	}

	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		return fmt.Errorf("failed to load devbox: %w", err)
	}

	l := logr.FromContextOrDiscard(ctx)
	l.Info("enable port forward", "ports", forwardedPorts, "addresses", addresses)

	pod, err := d.GetDevboxPod()
	if err != nil {
		return fmt.Errorf("failed to get devbox pod object: %w", err)
	}

	opts := client.PortForwardOptions{
		Addresses: addresses,
		Ports:     forwardedPorts,
	}
	return m.unstructured.PortForward(ctx, pod, opts)
}

func (m *manager) Start(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return err
	}
	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		return fmt.Errorf("failed to load devbox from release: %w", err)
	}
	if err := m.waitForDevboxPodTerminated(ctx, d); err != nil {
		return fmt.Errorf("failed to wait devbox pod terminated: %w", err)
	}
	return m.createDevboxPod(ctx, d, mutators...)
}

func (m *manager) Stop(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return err
	}
	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		return fmt.Errorf("failed to load devbox from release: %w", err)
	}
	if err := m.deleteDevboxPod(ctx, d); err != nil {
		return fmt.Errorf("failed to delete devbox pod: %w", err)
	}
	return nil
}

func (m *manager) Update(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return err
	}
	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		return fmt.Errorf("failed to load devbox from release: %w", err)
	}
	if err := m.deleteDevboxPod(ctx, d); err != nil {
		return fmt.Errorf("failed to delete devbox pod: %w", err)
	}
	if err := m.waitForDevboxPodTerminated(ctx, d); err != nil {
		return fmt.Errorf("failed to wait devbox pod terminated: %w", err)
	}

	d, err = m.loader.Load(r.TemplateName, r.Name, r.Namespace)
	if err != nil {
		return fmt.Errorf("failed to load template: %w", err)
	}
	r.Objects = d.ToUnstructureds()
	if err := m.store.Update(ctx, devboxName, namespace, r); err != nil {
		return fmt.Errorf("failed to update release: %w", err)
	}
	if err := m.applyDependencies(ctx, d); err != nil {
		return fmt.Errorf("failed to create devbox dependencies: %w", err)
	}
	if err := m.createDevboxPod(ctx, d, mutators...); err != nil {
		return fmt.Errorf("failed to create devbox pod: %w", err)
	}
	return nil
}

func (m *manager) Protect(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return err
	}
	r.Protect = true
	if err := m.store.Update(ctx, devboxName, namespace, r); err != nil {
		return fmt.Errorf("failed to update release: %w", err)
	}
	return nil
}

func (m *manager) Unprotect(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return err
	}
	r.Protect = false
	if err := m.store.Update(ctx, devboxName, namespace, r); err != nil {
		return fmt.Errorf("failed to update release: %w", err)
	}
	return nil
}

func (m *manager) List(ctx context.Context, namespace string) ([]info.DevboxInfoAccessor, error) {
	releases, err := m.store.List(ctx, namespace)
	if err != nil {
		return nil, fmt.Errorf("failed to get releases: %w", err)
	}

	var infos []info.DevboxInfoAccessor
	for _, r := range releases {
		d, err := devbox.NewDevbox(r.Objects)
		if err != nil {
			return nil, fmt.Errorf("failed to load devbox from release: %w", err)
		}
		pod, err := d.GetDevboxPod()
		if err != nil {
			return nil, fmt.Errorf("failed to get devbox object: %w", err)
		}
		info := info.NewDevboxInfoAccessor(
			m.clientset,
			r.Name,
			pod.GetName(),
			pod.GetNamespace(),
			r.TemplateName,
			r.Protect,
		)
		if err != nil {
			return nil, err
		}
		infos = append(infos, info)
	}
	return infos, nil
}

func (m *manager) waitForDevboxPodTerminated(ctx context.Context, d devbox.Devbox) error {
	pod, err := d.GetDevboxPod()
	if err != nil {
		return err
	}
	logger := logr.FromContextOrDiscard(ctx).WithValues("podName", pod.GetName(), "namespace", pod.GetNamespace())
	for {
		fresh, err := m.clientset.CoreV1().Pods(pod.GetNamespace()).Get(ctx, pod.GetName(), metav1.GetOptions{})
		if err == nil {
			if fresh.DeletionTimestamp.IsZero() {
				return fmt.Errorf("devbox pod is not deleted")
			}
			logger.V(1).Info("devbox pod has not been terminated yet")
			time.Sleep(500 * time.Millisecond)
			continue
		}
		if err != nil && !apierrors.IsNotFound(err) {
			return err
		}
		return nil
	}
}

func (m *manager) waitForDevboxPodReady(ctx context.Context, d devbox.Devbox) error {
	pod, err := d.GetDevboxPod()
	if err != nil {
		return err
	}
	logger := logr.FromContextOrDiscard(ctx).WithValues("podName", pod.GetName(), "namespace", pod.GetNamespace())
	for {
		fresh, err := m.clientset.CoreV1().Pods(pod.GetNamespace()).Get(ctx, pod.GetName(), metav1.GetOptions{})
		if err != nil {
			return err
		}
		if !fresh.DeletionTimestamp.IsZero() {
			return fmt.Errorf("pod is terminating")
		}
		ready := false
		for _, cond := range fresh.Status.Conditions {
			if cond.Type != corev1.PodReady {
				continue
			}
			if cond.Status != corev1.ConditionTrue {
				continue
			}
			ready = true
			break
		}
		if !ready {
			logger.V(1).Info("devbox pod has not been ready yet")
			time.Sleep(500 * time.Millisecond)
			continue
		}
		return nil
	}
}

func (m *manager) Events(ctx context.Context, devboxName, namespace string) (*corev1.EventList, error) {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		return nil, err
	}

	var eventList corev1.EventList
	for _, obj := range r.Objects {
		kind := obj.GetKind()
		name := obj.GetName()
		opts := metav1.ListOptions{
			FieldSelector: fields.AndSelectors(
				fields.OneTermEqualSelector("involvedObject.kind", kind),
				fields.OneTermEqualSelector("involvedObject.name", name),
				fields.OneTermEqualSelector("metadata.namespace", namespace),
			).String(),
			Limit: 100,
		}
		el, err := m.clientset.CoreV1().Events(namespace).List(ctx, opts)
		if err != nil {
			return nil, err
		}
		eventList.Items = append(eventList.Items, el.Items...)
	}
	sort.Sort(sortableEvents(eventList.Items))
	return &eventList, nil
}

type sortableEvents []corev1.Event

func (list sortableEvents) Len() int {
	return len(list)
}

func (list sortableEvents) Swap(i, j int) {
	list[i], list[j] = list[j], list[i]
}

func (list sortableEvents) Less(i, j int) bool {
	return eventTime(list[i]).Before(eventTime(list[j]))
}

func eventTime(event corev1.Event) time.Time {
	if event.Series != nil {
		return event.Series.LastObservedTime.Time
	}
	if !event.LastTimestamp.Time.IsZero() {
		return event.LastTimestamp.Time
	}
	return event.EventTime.Time
}
