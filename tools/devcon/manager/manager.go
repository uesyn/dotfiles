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
	"github.com/uesyn/dotfiles/tools/devcon/devbox"
	"github.com/uesyn/dotfiles/tools/devcon/kubernetes/client"
	"github.com/uesyn/dotfiles/tools/devcon/kubernetes/scheme"
	kubeutil "github.com/uesyn/dotfiles/tools/devcon/kubernetes/util"
	"github.com/uesyn/dotfiles/tools/devcon/manager/info"
	"github.com/uesyn/dotfiles/tools/devcon/mutator"
	"github.com/uesyn/dotfiles/tools/devcon/release"
	"github.com/uesyn/dotfiles/tools/devcon/ssh"
	"github.com/uesyn/dotfiles/tools/devcon/template"
	"github.com/uesyn/dotfiles/tools/devcon/util"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/apimachinery/pkg/util/wait"
	pkgwatch "k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/cache"
)

const (
	sshPortName = "ssh"
	localhost   = "127.0.0.1"
)

type Manager interface {
	Run(ctx context.Context, templateName, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Delete(ctx context.Context, devboxName, namespace string) error
	Update(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Exec(ctx context.Context, devboxName, namespace string, opts ...ExecOption) error
	PortForward(ctx context.Context, devboxName, namespace string, opts ...PortForwardOption) error
	SSH(ctx context.Context, devboxName, namespace string, opts ...SSHOption) error
	Start(ctx context.Context, devboxName, namespace string, mutators ...mutator.PodMutator) error
	Stop(ctx context.Context, devboxName, namespace string) error
	List(ctx context.Context, namespace string) ([]info.DevboxInfoAccessor, error)
	Protect(ctx context.Context, devboxName, namespace string) error
	Unprotect(ctx context.Context, devboxName, namespace string) error
	Events(ctx context.Context, devboxName, namespace string, watch bool, handler func(obj runtime.Object) error) error
}

type manager struct {
	scheme       *runtime.Scheme
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
	var objs []*unstructured.Unstructured
	objs = append(objs, d.GetDevbox())
	objs = append(objs, d.GetDependencies()...)
	r := &release.Release{
		Name:         devboxName,
		Namespace:    namespace,
		TemplateName: templateName,
		Objects:      objs,
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
	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, obj, kubeutil.ConditionReady); err != nil {
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
	pod, err := m.clientset.CoreV1().Pods(obj.GetNamespace()).Get(ctx, obj.GetName(), metav1.GetOptions{})
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

	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, obj, kubeutil.ConditionReady); err != nil {
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

func (m *manager) SSH(ctx context.Context, devboxName, namespace string, opts ...SSHOption) error {
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

	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, d.GetDevbox(), kubeutil.ConditionReady); err != nil {
		logger.Error(err, "failed to wait for devbox to become ready")
		return err
	}

	sshAddr, sshPort, sshContainerPort, err := m.getSSHIPPort(ctx, d)
	if err != nil {
		logger.Error(err, "Failed to get IP and Port for SSH")
		return err
	}

	if !isListening(sshAddr, sshPort) {
		localPort, err := getFreePort()
		if err != nil {
			logger.Error(err, "failed to get free port for SSH")
			return err
		}
		sshAddr = localhost
		sshPort = localPort

		go func() {
			opts := []PortForwardOption{
				WithPortForwardAddresses([]string{localhost}),
				WithPortForwardPorts([]string{fmt.Sprintf("%d:%d", localPort, sshContainerPort)}),
			}
			err := m.PortForward(ctx, devboxName, namespace, opts...)
			if err != nil {
				logger.Error(err, "failed to forward ports")
			}
		}()
	}

	sshOpts := &ssh.Options{Address: sshAddr, Port: sshPort}
	for _, o := range opts {
		sshOpts = o.apply(sshOpts)
	}

	if err := sshOpts.Complete(); err != nil {
		logger.Error(err, "failed to complete ssh options")
		return err
	}

	err = wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, 30*time.Second, true, func(context.Context) (bool, error) {
		if isListening(sshAddr, sshPort) {
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

func (m *manager) getSSHService(ctx context.Context, d devbox.Devbox) (*corev1.Service, error) {
	obj := d.GetSSHService()
	if obj == nil {
		return nil, apierrors.NewNotFound(schema.GroupResource{Resource: "services"}, "")
	}
	return m.clientset.CoreV1().Services(obj.GetNamespace()).Get(ctx, obj.GetName(), metav1.GetOptions{})
}

func (m *manager) getSSHTargetPodAndService(ctx context.Context, d devbox.Devbox) (devboxPod *corev1.Pod, svc *corev1.Service, err error) {
	svc, err = m.getSSHService(ctx, d)
	if err != nil {
		return nil, nil, err
	}

	selector := labels.SelectorFromSet(svc.Spec.Selector)
	podList, err := m.clientset.CoreV1().Pods(svc.GetNamespace()).List(ctx, metav1.ListOptions{
		LabelSelector: selector.String(),
	})
	if err != nil || len(podList.Items) == 0 {
		return nil, nil, err
	}
	devboxPod = &podList.Items[0]
	return
}

func getPortFromTargetPort(targetPort intstr.IntOrString, ports []corev1.ContainerPort) (int, error) {
	if targetPort.Type == intstr.Int {
		return int(targetPort.IntValue()), nil
	}

	portName := targetPort.String()
	for _, pp := range ports {
		if pp.Name == portName {
			return int(pp.ContainerPort), nil
		}
	}
	return -1, errors.New("port not found")
}

func (m *manager) getSSHIPPort(ctx context.Context, d devbox.Devbox) (ip string, svcPort int, containerPort int, err error) {
	var pod *corev1.Pod
	var svc *corev1.Service

	pod, svc, err = m.getSSHTargetPodAndService(ctx, d)
	if err != nil {
		return "", -1, -1, err
	}

	for _, p := range svc.Spec.Ports {
		if p.Name != sshPortName {
			continue
		}

		switch svc.Spec.Type {
		case corev1.ServiceTypeNodePort:
			ip = pod.Status.HostIP
			svcPort = int(p.NodePort)
		case corev1.ServiceTypeClusterIP:
			ip = pod.Status.PodIP
			svcPort = int(p.Port)
		default:
			return "", -1, -1, fmt.Errorf("%s is not supported service type", svc.Spec.Type)
		}

		containerPort, err = getPortFromTargetPort(p.TargetPort, pod.Spec.Containers[0].Ports)
		if err != nil {
			return "", -1, -1, err
		}
		return ip, svcPort, containerPort, nil
	}

	return "", -1, -1, errors.New("ssh service targets were not found")
}

func isListening(addr string, port int) bool {
	address := net.JoinHostPort(addr, strconv.Itoa(port))
	conn, err := net.DialTimeout("tcp", address, 3*time.Second)
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
	r.Objects = []*unstructured.Unstructured{d.GetDevbox()}
	r.Objects = append(r.Objects, d.GetDependencies()...)
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

func (m *manager) Events(ctx context.Context, devboxName, namespace string, watch bool, handler func(obj runtime.Object) error) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", devboxName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devboxName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	var eventList corev1.EventList
	eventCh := make(chan *corev1.Event, 1)
	errCh := make(chan error, 1)
	for _, obj := range r.Objects {
		fieldSelector := fields.AndSelectors(
			fields.OneTermEqualSelector("involvedObject.kind", obj.GetKind()),
			fields.OneTermEqualSelector("involvedObject.name", obj.GetName()),
			fields.OneTermEqualSelector("metadata.namespace", namespace),
		).String()
		opts := metav1.ListOptions{
			FieldSelector: fieldSelector,
			Limit:         100,
		}
		el, err := m.clientset.CoreV1().Events(namespace).List(ctx, opts)
		if err != nil {
			logger.Error(err, "failed to get event list")
			return err
		}
		eventList.Items = append(eventList.Items, el.Items...)

		if watch {
			wOpts := metav1.ListOptions{
				FieldSelector:   fieldSelector,
				ResourceVersion: el.ListMeta.ResourceVersion,
			}
			wi, err := m.clientset.CoreV1().Events(namespace).Watch(ctx, wOpts)
			if err != nil {
				logger.Error(err, "failed to get watch interface")
				return err
			}
			go func() {
				for {
					select {
					case e := <-wi.ResultChan():
						switch e.Type {
						case pkgwatch.Added, pkgwatch.Deleted, pkgwatch.Modified:
							event, _ := e.Object.(*corev1.Event)
							eventCh <- event
						case pkgwatch.Error:
							errCh <- fmt.Errorf("failed to get watch object: %v", e.Object)
						}
					case <-ctx.Done():
						return
					}
				}
			}()
		}
	}

	sort.Sort(sortableEvents(eventList.Items))
	if err := handler(&eventList); err != nil {
		return err
	}
	if watch {
		for {
			select {
			case event := <-eventCh:
				if err := handler(event); err != nil {
					logger.Error(err, "failed to handle event")
					return err
				}
			case err := <-errCh:
				logger.Error(err, "failed to watch event")
				return err
			case <-ctx.Done():
				return nil
			}
		}
	}
	return nil
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
