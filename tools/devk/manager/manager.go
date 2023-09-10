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
	"github.com/uesyn/dotfiles/tools/devk/common"
	"github.com/uesyn/dotfiles/tools/devk/config"
	"github.com/uesyn/dotfiles/tools/devk/kubernetes/client"
	"github.com/uesyn/dotfiles/tools/devk/kubernetes/scheme"
	kubeutil "github.com/uesyn/dotfiles/tools/devk/kubernetes/util"
	"github.com/uesyn/dotfiles/tools/devk/manager/info"
	"github.com/uesyn/dotfiles/tools/devk/manifest"
	"github.com/uesyn/dotfiles/tools/devk/mutator"
	"github.com/uesyn/dotfiles/tools/devk/release"
	"github.com/uesyn/dotfiles/tools/devk/ssh"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/wait"
	pkgwatch "k8s.io/apimachinery/pkg/watch"
	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/cache"
)

const (
	localhost = "127.0.0.1"
)

type Manager interface {
	Run(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error
	Delete(ctx context.Context, devkName, namespace string) error
	Update(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error
	Exec(ctx context.Context, devkName, namespace string, opts ...ExecOption) error
	PortForward(ctx context.Context, devkName, namespace string, opts ...PortForwardOption) error
	SSH(ctx context.Context, devkName, namespace string, opts ...SSHOption) error
	Start(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error
	Stop(ctx context.Context, devkName, namespace string) error
	List(ctx context.Context, namespace string) ([]info.DevkInfoAccessor, error)
	Protect(ctx context.Context, devkName, namespace string) error
	Unprotect(ctx context.Context, devkName, namespace string) error
	Events(ctx context.Context, devkName, namespace string, watch bool, handler func(obj runtime.Object) error) error
}

type manager struct {
	scheme       *runtime.Scheme
	unstructured *client.UnstructuredClient
	exec         *client.ExecClient
	portforward  *client.PortForwardClient
	clientset    kubernetes.Interface
	config       *config.Config
	store        release.Store
}

var _ Manager = (*manager)(nil)

func New(restConfig *rest.Config, s release.Store, c *config.Config) *manager {
	return &manager{
		scheme:       scheme.Scheme,
		unstructured: client.NewUnstructuredClient(restConfig),
		exec:         client.NewExecClient(restConfig),
		portforward:  client.NewPortForwardClient(restConfig),
		clientset:    kubernetes.NewForConfigOrDie(restConfig),
		store:        s,
		config:       c,
	}
}

func (m *manager) Run(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	logger.Info("create devk release")
	manifests := manifest.Generate(devkName, namespace, m.config.Pod, m.config.ConfigMaps, m.config.PVCs)
	r := &release.Release{
		Name:      devkName,
		Namespace: namespace,
		Manifests: manifests,
	}

	if err := m.store.Create(ctx, devkName, namespace, r); err != nil {
		logger.Error(err, "failed to create devk release")
		return err
	}

	failureHandler := func() {
		if err := m.deleteObjects(ctx, manifests.Pod, manifests.ConfigMaps, manifests.PVCs); err != nil {
			logger.Error(err, "failed to clean up devk objects")
			return
		}
		logger.Info("clean up devk release")
		if err := m.store.Delete(ctx, devkName, namespace); err != nil {
			logger.Error(err, "failed to clean up devk release")
		}
	}

	mutated := manifests.MustMutate(mutators...)
	if err := m.applyObjects(ctx, mutated.Pod, mutated.ConfigMaps, mutated.PVCs); err != nil {
		failureHandler()
		logger.Error(err, "failed to apply devk object")
		return err
	}
	return nil
}

func (m *manager) applyObjects(ctx context.Context, pod *applyconfigurationscorev1.PodApplyConfiguration, cms []applyconfigurationscorev1.ConfigMapApplyConfiguration, pvcs []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration) error {
	opts := metav1.ApplyOptions{
		Force:        true,
		FieldManager: common.FieldManager,
	}

	if pod != nil {
		l := logr.FromContextOrDiscard(ctx).WithValues("objKind", "Pod", "objName", *pod.Name)
		l.V(2).Info("apply object", "obj", pod)
		_, err := m.clientset.CoreV1().Pods(*pod.Namespace).Apply(ctx, pod, opts)
		if err != nil && !apierrors.IsNotFound(err) {
			return err
		}
		l.Info("object was applied")
	}

	if len(cms) > 0 {
		for _, cm := range cms {
			l := logr.FromContextOrDiscard(ctx).WithValues("objKind", "ConfigMap", "objName", *cm.Name)
			l.V(2).Info("apply object", "obj", cm)
			_, err := m.clientset.CoreV1().ConfigMaps(*cm.Namespace).Apply(ctx, &cm, opts)
			if err != nil && !apierrors.IsNotFound(err) {
				return err
			}
			l.Info("object was applied")
		}
	}

	if len(pvcs) > 0 {
		for _, pvc := range pvcs {
			l := logr.FromContextOrDiscard(ctx).WithValues("objKind", "PersistentVolumeClaim", "objName", *pvc.Name)
			l.V(2).Info("apply object", "obj", pvc)
			_, err := m.clientset.CoreV1().PersistentVolumeClaims(*pvc.Namespace).Apply(ctx, &pvc, opts)
			if err != nil && !apierrors.IsNotFound(err) {
				return err
			}
			l.Info("object was applied")
		}
	}

	return nil
}

var protectedError = errors.New("protected")

func (m *manager) Delete(ctx context.Context, devkName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if apierrors.IsNotFound(err) {
		logger.Info("devk already has been deleted")
		return nil
	}
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	if r.Protect {
		logger.Error(protectedError, "failed to delete devk")
		return protectedError
	}

	if err := m.deleteObjects(ctx, r.Manifests.Pod, r.Manifests.ConfigMaps, r.Manifests.PVCs); err != nil {
		logger.Error(err, "failed to delete devk")
		return err
	}
	if err := m.store.Delete(ctx, devkName, namespace); err != nil {
		logger.Error(err, "failed to clean up devk release")
		return err
	}
	logger.Info("devk was deleted")
	return nil
}

func (m *manager) deleteObjects(ctx context.Context, pod *applyconfigurationscorev1.PodApplyConfiguration, cms []applyconfigurationscorev1.ConfigMapApplyConfiguration, pvcs []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration) error {
	if pod != nil {
		l := logr.FromContextOrDiscard(ctx).WithValues("objKind", "Pod", "objName", *pod.Name)
		l.V(2).Info("delete object", "obj", pod)
		err := m.clientset.CoreV1().Pods(*pod.Namespace).Delete(ctx, *pod.Name, metav1.DeleteOptions{})
		if err != nil && !apierrors.IsNotFound(err) {
			return err
		}
		l.Info("object was deleted")
	}

	if len(cms) > 0 {
		for _, cm := range cms {
			l := logr.FromContextOrDiscard(ctx).WithValues("objKind", "ConfigMap", "objName", *cm.Name)
			l.V(2).Info("delete object", "obj", cm)
			err := m.clientset.CoreV1().ConfigMaps(*cm.Namespace).Delete(ctx, *cm.Name, metav1.DeleteOptions{})
			if err != nil && !apierrors.IsNotFound(err) {
				return err
			}
			l.Info("object was deleted")
		}
	}

	if len(pvcs) > 0 {
		for _, pvc := range pvcs {
			l := logr.FromContextOrDiscard(ctx).WithValues("objKind", "PersistentVolumeClaim", "objName", *pvc.Name)
			l.V(2).Info("delete object", "obj", pvc)
			err := m.clientset.CoreV1().PersistentVolumeClaims(*pvc.Namespace).Delete(ctx, *pvc.Name, metav1.DeleteOptions{})
			if err != nil && !apierrors.IsNotFound(err) {
				return err
			}
			l.Info("object was deleted")
		}
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

func (m *manager) Exec(ctx context.Context, devkName, namespace string, opts ...ExecOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	pod, err := m.getPod(ctx, *r.Manifests.Pod.Name, *r.Manifests.Pod.Namespace)
	if err != nil {
		logger.Error(err, "failed to get devk pod")
		return err
	}

	stdin, stdout, stderr := term.StdStreams()
	execOpts := &client.ExecOptions{
		Stdin:     stdin,
		Stdout:    stdout,
		Stderr:    stderr,
		Container: pod.Spec.Containers[0].Name, // TODO: Implement the method to select worker container.
	}

	for _, o := range opts {
		execOpts = o.apply(execOpts)
	}

	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, pod, kubeutil.ConditionReady); err != nil {
		logger.Error(err, "failed to wait for devk to be deleted")
		return err
	}

	if err := m.exec.Exec(ctx, pod, *execOpts); err != nil {
		logger.Error(err, "failed to exec")
		return err
	}
	return nil
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

func (m *manager) PortForward(ctx context.Context, devkName, namespace string, opts ...PortForwardOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	pod, err := m.getPod(ctx, *r.Manifests.Pod.Name, *r.Manifests.Pod.Namespace)
	if err != nil {
		logger.Error(err, "failed to get devk pod")
		return err
	}

	pfOpts := &client.PortForwardOptions{}
	for _, o := range opts {
		pfOpts = o.apply(pfOpts)
	}

	if err := kubeutil.WaitForCondition(ctx, 3*time.Minute, m.unstructured, pod, kubeutil.ConditionReady); err != nil {
		logger.Error(err, "failed to wait for devk to become ready")
		return err
	}

	logger.Info("enable port forward", "ports", pfOpts.Ports, "addresses", pfOpts.Addresses)
	if err := m.portforward.PortForward(ctx, pod, *pfOpts); err != nil {
		logger.Error(err, "failed to forward ports")
		return err
	}
	return nil
}

func (m *manager) getPod(ctx context.Context, name, namespace string) (*corev1.Pod, error) {
	return m.clientset.CoreV1().Pods(namespace).Get(ctx, name, metav1.GetOptions{})
}

type SSHOption interface {
	apply(opts *ssh.Options) *ssh.Options
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

type withSSHLocalForwardedPorts struct {
	ports []string
}

func WithSSHLocalForwardedPorts(ports []string) SSHOption {
	return &withSSHLocalForwardedPorts{ports: ports}
}

func (o *withSSHLocalForwardedPorts) apply(opts *ssh.Options) *ssh.Options {
	opts.LocalForwardedPorts = o.ports
	return opts
}

type withSSHRemoteForwardedPorts struct {
	ports []string
}

func WithSSHRemoteForwardedPorts(ports []string) SSHOption {
	return &withSSHRemoteForwardedPorts{ports: ports}
}

func (o *withSSHRemoteForwardedPorts) apply(opts *ssh.Options) *ssh.Options {
	opts.RemoteForwardedPorts = o.ports
	return opts
}

func (m *manager) SSH(ctx context.Context, devkName, namespace string, opts ...SSHOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	sshPod, err := m.getPod(ctx, *r.Manifests.Pod.Name, *r.Manifests.Pod.Namespace)
	if err != nil {
		logger.Error(err, "failed to get devk pod")
		return err
	}

	sshPort, err := m.getFreePort()
	if err != nil {
		logger.Error(err, "failed to get Free Port for SSH")
		return err
	}
	sshContainerPort := m.config.SSH.Port
	go func() {
		opts := client.PortForwardOptions{
			Addresses: []string{localhost},
			Ports:     []string{fmt.Sprintf("%d:%d", sshPort, sshContainerPort)},
		}

		if err := m.portforward.PortForward(ctx, sshPod, opts); err != nil {
			logger.Error(err, "failed to forward ports")
			return
		}
	}()

	sshOpts := &ssh.Options{}
	for _, o := range opts {
		sshOpts = o.apply(sshOpts)
	}

	if err := sshOpts.Complete(); err != nil {
		logger.Error(err, "failed to complete ssh options")
		return err
	}

	if err := wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, 30*time.Second, true, func(context.Context) (bool, error) {
		if m.isListening(localhost, sshPort) {
			return true, nil
		}
		return false, nil
	}); err != nil {
		logger.Error(err, "failed to wait for the ssh server to be listened")
		return err
	}

	if err := sshOpts.Connect(ctx, m.config.SSH.User, localhost, sshPort); err != nil {
		logger.Error(err, "failed to run ssh")
		return err
	}
	return nil
}

func (_ *manager) isListening(addr string, port int) bool {
	address := net.JoinHostPort(addr, strconv.Itoa(port))
	conn, err := net.DialTimeout("tcp", address, 3*time.Second)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}

func (_ *manager) getFreePort() (int, error) {
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

func (m *manager) Start(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	mutated := r.Manifests.MustMutate(mutators...)
	if err := m.applyObjects(ctx, mutated.Pod, mutated.ConfigMaps, mutated.PVCs); err != nil {
		logger.Error(err, "failed to start devk")
		return err
	}
	return nil
}

func (m *manager) Stop(ctx context.Context, devkName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	pod := r.Manifests.Pod
	// Delete only Pod object
	if err := m.deleteObjects(ctx, pod, nil, nil); err != nil {
		logger.Error(err, "failed to stop pod")
		return err
	}
	if err := m.waitForPodTerminated(ctx, *pod.Name, *pod.Namespace, 1*time.Minute); err != nil {
		logger.Error(err, "failed to wait devk pod terminated")
		return err
	}
	return nil
}

func (m *manager) waitForPodTerminated(ctx context.Context, podName, namespace string, timeout time.Duration) error {
	return wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, timeout, true, func(context.Context) (bool, error) {
		fresh, err := m.clientset.CoreV1().Pods(namespace).Get(ctx, podName, metav1.GetOptions{})
		if err != nil {
			if !apierrors.IsNotFound(err) {
				return false, err
			}
			return true, nil
		}
		if fresh.GetDeletionTimestamp().IsZero() {
			return false, errors.New("not terminating")
		}
		return false, nil
	})
}

func (m *manager) Update(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	oldManifests := r.Manifests
	if err := m.deleteObjects(ctx, oldManifests.Pod, nil, nil); err != nil {
		logger.Error(err, "failed to delete old devk pod")
		return err
	}

	if err := m.waitForPodTerminated(ctx, *oldManifests.Pod.Name, *oldManifests.Pod.Namespace, 60*time.Second); err != nil {
		logger.Error(err, "failed to wait for old devk pod terminated")
		return err
	}

	newManifests := manifest.Generate(devkName, namespace, m.config.Pod, m.config.ConfigMaps, m.config.PVCs)
	mutated := newManifests.MustMutate(mutators...)
	if err := m.applyObjects(ctx, mutated.Pod, mutated.ConfigMaps, mutated.PVCs); err != nil {
		logger.Error(err, "failed to apply devk object")
		return err
	}

	r.Manifests = newManifests
	if err := m.store.Update(ctx, devkName, namespace, r); err != nil {
		logger.Error(err, "failed to update release")
		return err
	}
	return nil
}

func (m *manager) Protect(ctx context.Context, devkName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	r.Protect = true
	if err := m.store.Update(ctx, devkName, namespace, r); err != nil {
		logger.Error(err, "failed to update release")
		return err
	}
	return nil
}

func (m *manager) Unprotect(ctx context.Context, devkName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}
	r.Protect = false
	if err := m.store.Update(ctx, devkName, namespace, r); err != nil {
		logger.Error(err, "failed to update release")
		return err
	}
	return nil
}

func (m *manager) List(ctx context.Context, namespace string) ([]info.DevkInfoAccessor, error) {
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

	var infos []info.DevkInfoAccessor
	for _, r := range releases {
		info := info.NewDevkInfoAccessor(informer.Lister(), r)
		infos = append(infos, info)
	}
	return infos, nil
}

func (m *manager) Events(ctx context.Context, devkName, namespace string, watch bool, handler func(obj runtime.Object) error) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	var eventList corev1.EventList
	eventCh := make(chan *corev1.Event, 1)
	errCh := make(chan error, 1)
	fieldSelector := fields.AndSelectors(
		fields.OneTermEqualSelector("involvedObject.kind", "Pod"),
		fields.OneTermEqualSelector("involvedObject.name", *r.Manifests.Pod.Name),
		fields.OneTermEqualSelector("metadata.namespace", *r.Manifests.Pod.Namespace),
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

	sort.Sort(sortableEvents(eventList))
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

type sortableEvents corev1.EventList

func (list sortableEvents) Len() int { return len(list.Items) }

func (list sortableEvents) Swap(i, j int) {
	list.Items[i], list.Items[j] = list.Items[j], list.Items[i]
}

func (list sortableEvents) Less(i, j int) bool {
	return eventTime(list.Items[i]).Before(eventTime(list.Items[j]))
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
