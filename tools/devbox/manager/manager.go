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
	kubeutil "github.com/uesyn/devbox/kubernetes/util"
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
	"k8s.io/apimachinery/pkg/runtime/schema"
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
		if err := m.deleteDevbox(ctx, d); err != nil {
			logger.Error(err, "failed to clean up devbox objects")
			return
		}
		logger.Info("clean up devbox release")
		if err := m.store.Delete(ctx, devboxName, namespace); err != nil {
			logger.Error(err, "failed to clean up devbox release")
		}
	}

	if err := m.applyDevbox(ctx, d, mutators...); err != nil {
		failureHandler()
		return fmt.Errorf("failed to apply devbox object: %w", err)
	}
	return nil
}

func (m *manager) mutateDevbox(ctx context.Context, u *unstructured.Unstructured, mutators ...mutator.PodMutator) (*unstructured.Unstructured, error) {
	devboxPod := &corev1.Pod{}
	err := runtime.DefaultUnstructuredConverter.FromUnstructured(u.Object, &devboxPod)
	if err != nil {
		return nil, err
	}
	for _, m := range mutators {
		m.Mutate(devboxPod)
	}
	obj, err := runtime.DefaultUnstructuredConverter.ToUnstructured(devboxPod)
	if err != nil {
		return nil, err
	}
	unst := &unstructured.Unstructured{Object: obj}
	unst.SetGroupVersionKind(schema.GroupVersionKind{Version: "v1", Kind: "Pod"})
	return unst, nil
}

func (m *manager) applyDevbox(ctx context.Context, d devbox.Devbox, mutators ...mutator.PodMutator) error {
	var objs []*unstructured.Unstructured
	obj, err := m.mutateDevbox(ctx, d.GetDevbox(), mutators...)
	if err != nil {
		return fmt.Errorf("failed to mutate devbox: %w", err)
	}
	objs = append(objs, obj)
	objs = append(objs, d.GetDependencies()...)
	if err := m.apply(ctx, objs...); err != nil {
		return err
	}
	return nil
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
	if err := m.deleteDevbox(ctx, d); err != nil {
		return err
	}
	if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, d.GetDevbox()); err != nil {
		return fmt.Errorf("failed to wait devbox terminated: %w", err)
	}
	return m.store.Delete(ctx, devboxName, namespace)
}

func (m *manager) deleteDevbox(ctx context.Context, d devbox.Devbox) error {
	var objs []*unstructured.Unstructured
	objs = append(objs, d.GetDependencies()...)
	objs = append(objs, d.GetDevbox())
	if err := m.delete(ctx, objs...); err != nil {
		return fmt.Errorf("failed to delete devbox object: %w", err)
	}
	return nil
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

	pod, err := m.getDevboxPod(ctx, d)
	if err != nil {
		return fmt.Errorf("failed to get devbox pod: %w", err)
	}

	stdin, stdout, stderr := term.StdStreams()
	opts := client.ExecOptions{
		Stdin:     stdin,
		Stdout:    stdout,
		Stderr:    stderr,
		Container: pod.Spec.Containers[0].Name, // TODO: Select container with selector.
		Command:   command,
		Envs:      envs,
	}

	obj := d.GetDevbox()
	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, obj, "ContainersReady"); err != nil {
		return fmt.Errorf("could not wait for devbox pod ready: %w", err)
	}
	return m.unstructured.Exec(ctx, obj, opts)
}

var unsupportedDevboxKind = errors.New("unsupported devbox kind")

func (m *manager) getDevboxPod(ctx context.Context, d devbox.Devbox) (*corev1.Pod, error) {
	obj := d.GetDevbox()
	if obj.GetKind() != "Pod" {
		return nil, unsupportedDevboxKind
	}
	pod := &corev1.Pod{}
	err := runtime.DefaultUnstructuredConverter.FromUnstructured(obj.Object, &pod)
	if err != nil {
		return nil, err
	}
	return pod, nil
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

	obj := d.GetDevbox()
	opts := client.PortForwardOptions{
		Addresses: addresses,
		Ports:     forwardedPorts,
	}
	return m.unstructured.PortForward(ctx, obj, opts)
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

	obj := d.GetDevbox()
	if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, obj); err != nil {
		return fmt.Errorf("could not wait devbox object terminated: %w", err)
	}

	mutated, err := m.mutateDevbox(ctx, obj, mutators...)
	if err != nil {
		return fmt.Errorf("failed to mutate devbox: %w", err)
	}
	return m.apply(ctx, mutated)
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
	if err := m.delete(ctx, d.GetDevbox()); err != nil {
		return fmt.Errorf("failed to delete devbox object: %w", err)
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
	obj := d.GetDevbox()
	if err := m.delete(ctx, obj); err != nil {
		return fmt.Errorf("failed to delete devbox object: %w", err)
	}
	if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, obj); err != nil {
		return fmt.Errorf("failed to wait devbox object terminated: %w", err)
	}

	d, err = m.loader.Load(r.TemplateName, r.Name, r.Namespace)
	if err != nil {
		return fmt.Errorf("failed to load template: %w", err)
	}
	r.Objects = d.ToUnstructureds()
	if err := m.store.Update(ctx, devboxName, namespace, r); err != nil {
		return fmt.Errorf("failed to update release: %w", err)
	}
	if err := m.applyDevbox(ctx, d, mutators...); err != nil {
		return fmt.Errorf("failed to apply devbox object: %w", err)
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
		obj := d.GetDevbox()
		info := info.NewDevboxInfoAccessor(
			m.clientset,
			r.Name,
			obj.GetName(),
			obj.GetNamespace(),
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
