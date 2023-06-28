package manager

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sort"
	"strconv"
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
	"github.com/uesyn/devbox/ssh"
	"github.com/uesyn/devbox/template"
	"github.com/uesyn/devbox/util"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/cache"
)

type Manager interface {
	Run(ctx context.Context, templateName, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Delete(ctx context.Context, devboxName, namespace string) error
	Update(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Exec(ctx context.Context, devboxName, namespace string, opts ...ExecOption) error
	PortForward(ctx context.Context, devboxName, namespace string, opts ...PortForwardOption) error
	SSH(ctx context.Context, devboxName, namespace string, containerSSHPort int, opts ...SSHOption) error
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

	logger.Info("create devbox release")
	d, err := m.loader.Load(templateName, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to load template")
		return err
	}
	r := &release.Release{
		Name:         devboxName,
		Namespace:    namespace,
		TemplateName: templateName,
		Objects:      d.ToUnstructureds(),
	}

	if err := m.store.Create(ctx, devboxName, namespace, r); err != nil {
		logger.Error(err, "failed to create devbox release")
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
		logger.Error(err, "failed to apply devbox object")
		return err
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

var protectedError = errors.New("protected")

func (m *manager) Delete(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if apierrors.IsNotFound(err) {
		logger.Info("devbox already has been deleted")
		return nil
	}
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	if r.Protect {
		logger.Error(protectedError, "failed to delete devbox")
		return protectedError
	}

	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		logger.Error(err, "failed to load devbox object from release")
		return err
	}
	if err := m.deleteDevbox(ctx, d); err != nil {
		logger.Error(err, "failed to delete devbox")
		return err
	}
	if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, d.GetDevbox()); err != nil {
		logger.Error(err, "failed to wait for devbox to be deleted")
		return err
	}
	if err := m.store.Delete(ctx, devboxName, namespace); err != nil {
		logger.Error(err, "failed to clean up devbox release")
		return err
	}
	logger.Info("devbox was deleted")
	return nil
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

type ExecOption interface {
	apply(opts *client.ExecOptions) *client.ExecOptions
}

func WithExecCommand(command []string) ExecOption {
	return &withExecCommand{command: command}
}

type withExecCommand struct {
	command []string
}

func (o *withExecCommand) apply(opts *client.ExecOptions) *client.ExecOptions {
	opts.Command = o.command
	return opts
}

func WithExecEnvs(envs map[string]string) ExecOption {
	return &withExecEnvs{envs: envs}
}

type withExecEnvs struct {
	envs map[string]string
}

func (o *withExecEnvs) apply(opts *client.ExecOptions) *client.ExecOptions {
	opts.Envs = o.envs
	return opts
}

func (m *manager) Exec(ctx context.Context, devboxName, namespace string, opts ...ExecOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		logger.Error(err, "failed to load devbox")
		return err
	}

	pod, err := m.getDevboxPod(ctx, d)
	if err != nil {
		logger.Error(err, "failed to load devbox pod")
		return err
	}

	stdin, stdout, stderr := term.StdStreams()
	execOpts := &client.ExecOptions{
		Stdin:     stdin,
		Stdout:    stdout,
		Stderr:    stderr,
		Container: pod.Spec.Containers[0].Name, // TODO: Select container with selector.
	}

	for _, o := range opts {
		execOpts = o.apply(execOpts)
	}

	obj := d.GetDevbox()
	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, obj, "ContainersReady"); err != nil {
		logger.Error(err, "failed to wait for devbox to be deleted")
		return err
	}

	if err := m.unstructured.Exec(ctx, obj, *execOpts); err != nil {
		logger.Error(err, "failed to exec")
		return err
	}
	return nil
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

type PortForwardOption interface {
	apply(opts *client.PortForwardOptions) *client.PortForwardOptions
}

func WithPortForwardPorts(ports []string) PortForwardOption {
	return &withPortFowardPorts{
		ports: ports,
	}
}

type withPortFowardPorts struct {
	ports []string
}

func (o *withPortFowardPorts) apply(opts *client.PortForwardOptions) *client.PortForwardOptions {
	opts.Ports = o.ports
	return opts
}

func WithPortForwardAddresses(addresses []string) PortForwardOption {
	return &withPortFowardAddresses{
		addresses: addresses,
	}
}

type withPortFowardAddresses struct {
	addresses []string
}

func (o *withPortFowardAddresses) apply(opts *client.PortForwardOptions) *client.PortForwardOptions {
	opts.Addresses = o.addresses
	return opts
}

func (m *manager) PortForward(ctx context.Context, devboxName, namespace string, opts ...PortForwardOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		logger.Error(err, "failed to load devbox")
		return err
	}

	obj := d.GetDevbox()
	pfOpts := &client.PortForwardOptions{}
	for _, o := range opts {
		pfOpts = o.apply(pfOpts)
	}

	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, obj, "ContainersReady"); err != nil {
		logger.Error(err, "failed to wait for devbox to become ready")
		return err
	}

	logger.Info("enable port forward", "ports", pfOpts.Ports, "addresses", pfOpts.Addresses)
	if err := m.unstructured.PortForward(ctx, obj, *pfOpts); err != nil {
		logger.Error(err, "failed to forward ports")
		return err
	}
	return nil
}

type SSHOption interface {
	apply(opts *ssh.Options) *ssh.Options
}

func WithSSHUser(user string) SSHOption {
	return &withSSHUser{user: user}
}

type withSSHUser struct {
	user string
}

func (o *withSSHUser) apply(opts *ssh.Options) *ssh.Options {
	opts.User = o.user
	return opts
}

func WithSSHIdentityFile(file string) SSHOption {
	return &withSSHIdentityFile{file: file}
}

type withSSHIdentityFile struct {
	file string
}

func (o *withSSHIdentityFile) apply(opts *ssh.Options) *ssh.Options {
	opts.IdentityFile = o.file
	return opts
}

func WithSSHCommand(command []string) SSHOption {
	return &withSSHCommand{command: command}
}

type withSSHCommand struct {
	command []string
}

func (o *withSSHCommand) apply(opts *ssh.Options) *ssh.Options {
	opts.Command = o.command
	return opts
}

func WithSSHEnvs(envs map[string]string) SSHOption {
	return &withSSHEnvs{envs: envs}
}

type withSSHEnvs struct {
	envs map[string]string
}

func (o *withSSHEnvs) apply(opts *ssh.Options) *ssh.Options {
	opts.Envs = o.envs
	return opts
}

func WithSSHForwardedPorts(ports []string) SSHOption {
	return &withSSHForwardedPorts{ports: ports}
}

type withSSHForwardedPorts struct {
	ports []string
}

func (o *withSSHForwardedPorts) apply(opts *ssh.Options) *ssh.Options {
	opts.ForwardedPorts = o.ports
	return opts
}

func (m *manager) SSH(ctx context.Context, devboxName, namespace string, containerSSHPort int, opts ...SSHOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		logger.Error(err, "failed to load devbox")
		return err
	}

	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, d.GetDevbox(), "ContainersReady"); err != nil {
		logger.Error(err, "failed to wait for devbox to become ready")
		return err
	}

	localPort, err := getFreePort()
	if err != nil {
		logger.Error(err, "failed to get free port for SSH")
		return err
	}

	const localhost = "127.0.0.1"
	sshOpts := &ssh.Options{Address: localhost, Port: localPort}
	for _, o := range opts {
		sshOpts = o.apply(sshOpts)
	}

	if err := sshOpts.Complete(); err != nil {
		logger.Error(err, "failed to complete ssh options")
		return err
	}

	// Port forward to connect ssh to container.
	go func() {
		opts := []PortForwardOption{
			WithPortForwardAddresses([]string{localhost}),
			WithPortForwardPorts([]string{fmt.Sprintf("%d:%d", localPort, containerSSHPort)}),
		}
		err := m.PortForward(ctx, devboxName, namespace, opts...)
		if err != nil {
			logger.Error(err, "failed to forward ports")
		}
	}()

	err = wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, 30*time.Second, true, func(context.Context) (bool, error) {
		if isListening(localhost, localPort) {
			return true, nil
		}
		return false, nil
	})

	if err != nil {
		logger.Error(err, "failed to wait for the ssh server to be listened")
		return err
	}

	if err := sshOpts.Run(ctx); err != nil {
		logger.Error(err, "failed to run ssh")
		return err
	}
	return nil
}

func isListening(addr string, port int) bool {
	address := net.JoinHostPort(addr, strconv.Itoa(port))
	conn, err := net.DialTimeout("tcp", address, time.Second)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}

func getFreePort() (int, error) {
	const invalidPort = -1

	a, err := net.ResolveTCPAddr("tcp", "localhost:0")
	if err != nil {
		return invalidPort, err
	}

	l, err := net.ListenTCP("tcp", a)
	if err != nil {
		return invalidPort, err
	}

	if err := l.Close(); err != nil {
		return invalidPort, err
	}
	return l.Addr().(*net.TCPAddr).Port, nil
}

func (m *manager) Start(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		logger.Error(err, "failed to load devbox from release")
		return err
	}

	obj := d.GetDevbox()
	if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, obj); err != nil {
		logger.Error(err, "failed to wait for devbox object to be terminated")
		return err
	}

	mutated, err := m.mutateDevbox(ctx, obj, mutators...)
	if err != nil {
		logger.Error(err, "failed to mutate devbox")
		return err
	}
	if err := m.apply(ctx, mutated); err != nil {
		logger.Error(err, "failed to start devbox")
		return err
	}
	return nil
}

func (m *manager) Stop(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		logger.Error(err, "failed to load devbox from release")
		return err
	}
	if err := m.delete(ctx, d.GetDevbox()); err != nil {
		logger.Error(err, "failed to delete devbox object")
		return err
	}
	return nil
}

func (m *manager) Update(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	d, err := devbox.NewDevbox(r.Objects)
	if err != nil {
		logger.Error(err, "failed to load devbox from release")
		return err
	}
	obj := d.GetDevbox()
	if err := m.delete(ctx, obj); err != nil {
		logger.Error(err, "failed to delete devbox object")
		return err
	}
	if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, obj); err != nil {
		logger.Error(err, "failed to wait devbox object terminated")
		return err
	}

	d, err = m.loader.Load(r.TemplateName, r.Name, r.Namespace)
	if err != nil {
		logger.Error(err, "failed to load template")
		return err
	}
	r.Objects = d.ToUnstructureds()
	if err := m.store.Update(ctx, devboxName, namespace, r); err != nil {
		logger.Error(err, "failed to update release")
		return err
	}
	if err := m.applyDevbox(ctx, d, mutators...); err != nil {
		logger.Error(err, "failed to apply devbox object")
		return err
	}
	return nil
}

func (m *manager) Protect(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	r.Protect = true
	if err := m.store.Update(ctx, devboxName, namespace, r); err != nil {
		logger.Error(err, "failed to update release")
		return err
	}
	return nil
}

func (m *manager) Unprotect(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	r.Protect = false
	if err := m.store.Update(ctx, devboxName, namespace, r); err != nil {
		logger.Error(err, "failed to update release")
		return err
	}
	return nil
}

func (m *manager) List(ctx context.Context, namespace string) ([]info.DevboxInfoAccessor, error) {
	logger := logr.FromContextOrDiscard(ctx).WithValues("namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	releases, err := m.store.List(ctx, namespace)
	if err != nil {
		logger.Error(err, "failed to update release")
		return nil, err
	}

	factory := informers.NewSharedInformerFactoryWithOptions(m.clientset, 0, informers.WithNamespace(namespace))
	informer := factory.Core().V1().Pods()
	go informer.Informer().Run(ctx.Done())
	if !cache.WaitForCacheSync(ctx.Done(), informer.Informer().HasSynced) {
		logger.Error(err, "failed to cache sync for informer")
		return nil, err
	}

	var infos []info.DevboxInfoAccessor
	for _, r := range releases {
		d, err := devbox.NewDevbox(r.Objects)
		if err != nil {
			logger.Error(err, "failed to load devbox from release")
			return nil, err
		}
		obj := d.GetDevbox()
		info := info.NewDevboxInfoAccessor(
			informer.Lister(),
			r.Name,
			obj.GetName(),
			obj.GetNamespace(),
			r.TemplateName,
			r.Protect,
		)
		infos = append(infos, info)
	}
	return infos, nil
}

func (m *manager) Events(ctx context.Context, devboxName, namespace string) (*corev1.EventList, error) {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
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
			logger.Error(err, "failed to get event list")
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
