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
	"github.com/uesyn/dotfiles/tools/devk/kubernetes/client"
	"github.com/uesyn/dotfiles/tools/devk/kubernetes/scheme"
	kubeutil "github.com/uesyn/dotfiles/tools/devk/kubernetes/util"
	"github.com/uesyn/dotfiles/tools/devk/manager/info"
	"github.com/uesyn/dotfiles/tools/devk/manifest"
	"github.com/uesyn/dotfiles/tools/devk/mutator"
	"github.com/uesyn/dotfiles/tools/devk/release"
	"github.com/uesyn/dotfiles/tools/devk/ssh"
	"github.com/uesyn/dotfiles/tools/devk/template"
	"github.com/uesyn/dotfiles/tools/devk/util"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/selection"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/apimachinery/pkg/util/wait"
	pkgwatch "k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/cache"
)

var (
	notStopPolicyRetainSelector = func() labels.Selector {
		req, err := labels.NewRequirement(
			common.DevkStopPolicyLabelKey,
			selection.NotEquals,
			[]string{common.DevkStopPolicyRetain},
		)
		if err != nil {
			panic(err)
		}
		return labels.NewSelector().Add(*req)
	}()
)

const (
	sshPortName = "ssh"
	localhost   = "127.0.0.1"
)

type Manager interface {
	Run(ctx context.Context, templateName, devkName, namespace string, mutators ...mutator.Mutator) error
	Delete(ctx context.Context, devkName, namespace string) error
	Update(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error
	Exec(ctx context.Context, devkName, namespace string, opts ...ExecOption) error
	PortForward(ctx context.Context, devkName, namespace string, opts ...PortForwardOption) error
	SSH(ctx context.Context, devkName, namespace string, useServiceIP bool, opts ...SSHOption) error
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
	loader       template.Loader
	store        release.Store
}

var _ Manager = (*manager)(nil)

func New(restConfig *rest.Config, s release.Store, loader template.Loader) *manager {
	return &manager{
		scheme:       scheme.Scheme,
		unstructured: client.NewUnstructuredClient(restConfig),
		exec:         client.NewExecClient(restConfig),
		portforward:  client.NewPortForwardClient(restConfig),
		clientset:    kubernetes.NewForConfigOrDie(restConfig),
		store:        s,
		loader:       loader,
	}
}

func (m *manager) Run(ctx context.Context, templateName, devkName, namespace string, mutators ...mutator.Mutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	logger.Info("create devk release")
	manifests, err := m.loader.Load(templateName, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to load template")
		return err
	}
	r := &release.Release{
		Name:         devkName,
		Namespace:    namespace,
		TemplateName: templateName,
		Objects:      manifests.ToObjects(),
	}

	if err := m.store.Create(ctx, devkName, namespace, r); err != nil {
		logger.Error(err, "failed to create devk release")
		return err
	}

	failureHandler := func() {
		if err := m.delete(ctx, r.Objects...); err != nil {
			logger.Error(err, "failed to clean up devk objects")
			return
		}
		logger.Info("clean up devk release")
		if err := m.store.Delete(ctx, devkName, namespace); err != nil {
			logger.Error(err, "failed to clean up devk release")
		}
	}

	mutateds := manifests.MustMutate(mutators...).ToObjects()
	if err := m.apply(ctx, mutateds...); err != nil {
		failureHandler()
		logger.Error(err, "failed to apply devk object")
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
			FieldManager: common.FieldManager,
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

	if err := m.delete(ctx, r.Objects...); err != nil {
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

func (m *manager) Exec(ctx context.Context, devkName, namespace string, opts ...ExecOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	pod, _, err := m.getDevkPodAndService(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to load devk pod")
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

func (m *manager) getDevkPodAndService(ctx context.Context, devkName string, namespace string) (*corev1.Pod, *corev1.Service, error) {
	svc, err := m.getSelectorService(ctx, devkName, namespace)
	if err != nil {
		return nil, nil, err
	}
	pods, err := m.getPodsForService(ctx, svc)
	if err != nil {
		return nil, nil, err
	}
	sort.Slice(pods, func(i, j int) bool {
		return pods[i].CreationTimestamp.Before(&pods[j].CreationTimestamp)
	})
	return &pods[0], svc, nil
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

	pod, _, err := m.getDevkPodAndService(ctx, devkName, namespace)
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

func (m *manager) SSH(ctx context.Context, devkName, namespace string, useServiceIP bool, opts ...SSHOption) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	sshPod, sshService, err := m.getDevkPodAndService(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get Service or Pod")
		return err
	}

	var sshIP string
	var sshPort int

	if !useServiceIP {
		sshIP = localhost
		var err error
		sshPort, err = m.getFreePort()
		if err != nil {
			logger.Error(err, "failed to get Free Port for SSH")
			return err
		}
		sshContainerPort, err := m.sshContainerPort(sshPod, sshService)
		if err != nil {
			logger.Info("container SSH Port was not found")
		}

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
	} else {
		var err error
		sshIP, sshPort, err = m.sshServiceIPPort(sshPod, sshService)
		if err != nil {
			logger.Error(err, "failed to get suitable ssh ip and port from service")
			return err
		}
	}

	sshOpts := &ssh.Options{}
	for _, o := range opts {
		sshOpts = o.apply(sshOpts)
	}

	if err := sshOpts.Complete(); err != nil {
		logger.Error(err, "failed to complete ssh options")
		return err
	}

	if err := wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, 30*time.Second, true, func(context.Context) (bool, error) {
		if m.isListening(sshIP, sshPort) {
			return true, nil
		}
		return false, nil
	}); err != nil {
		logger.Error(err, "failed to wait for the ssh server to be listened")
		return err
	}

	if err := sshOpts.Connect(ctx, m.sshUser(sshService), sshIP, sshPort); err != nil {
		logger.Error(err, "failed to run ssh")
		return err
	}
	return nil
}

const defaultSSHUser = "root"

func (m *manager) sshUser(pod *corev1.Service) string {
	annotations := pod.GetAnnotations()
	if len(annotations) == 0 {
		return defaultSSHUser
	}
	user, ok := annotations[common.DevkSSHUserLabelKey]
	if !ok {
		return defaultSSHUser
	}
	return user
}

func (m *manager) sshContainerPort(pod *corev1.Pod, svc *corev1.Service) (int, error) {
	svcPort, err := m.sshServicePort(svc)
	if err != nil {
		return -1, err
	}

	targetPort := svcPort.TargetPort

	if targetPort.Type == intstr.Int {
		return int(targetPort.IntValue()), nil
	}

	containerPortNum := 22
	portName := targetPort.String()
	for _, pp := range pod.Spec.Containers[0].Ports {
		if pp.Name == portName {
			containerPortNum = int(pp.ContainerPort)
		}
	}
	return containerPortNum, nil
}

func (m *manager) sshServiceIPPort(sshPod *corev1.Pod, sshService *corev1.Service) (string, int, error) {
	selector := labels.Set(sshService.Spec.Selector).AsSelector()
	if !selector.Matches(labels.Set(sshPod.GetLabels())) {
		return "", -1, errors.New("pod doesn't match service selector")
	}

	svcPort, err := m.sshServicePort(sshService)
	if err != nil {
		return "", -1, err
	}

	switch sshService.Spec.Type {
	case corev1.ServiceTypeNodePort:
		return sshPod.Status.HostIP, int(svcPort.NodePort), nil
	case corev1.ServiceTypeClusterIP:
		return sshService.Spec.ClusterIP, int(svcPort.Port), nil
	case corev1.ServiceTypeLoadBalancer:
		// TODO: support
		return "", -1, errors.New("not supported")
	case corev1.ServiceTypeExternalName:
		// TODO: support
		return "", -1, errors.New("not supported")
	}
	return "", -1, errors.New("unknown service type")
}

func (m *manager) sshServicePort(svc *corev1.Service) (*corev1.ServicePort, error) {
	if len(svc.Spec.Ports) == 1 {
		return &svc.Spec.Ports[0], nil
	}
	for i := range svc.Spec.Ports {
		port := svc.Spec.Ports[i]
		if port.Name != common.SSHServicePortName {
			continue
		}
		return &port, nil
	}
	return nil, errors.New("ssh service port was not found")
}

func (m *manager) getSelectorService(ctx context.Context, devkName, namespace string) (*corev1.Service, error) {
	selector := labels.Set{
		common.DevkNameLabelKey: devkName,
	}.AsSelector().String()
	svcList, err := m.clientset.CoreV1().Services(namespace).List(ctx, metav1.ListOptions{
		LabelSelector: selector,
	})
	if err != nil {
		return nil, err
	}
	if len(svcList.Items) == 0 {
		return nil, errors.New("selector service was not found")
	}
	if len(svcList.Items) == 1 {
		return &svcList.Items[0], nil
	}

	selector = labels.Set{
		common.DevkNameLabelKey: devkName,
	}.AsSelector().String()
	svcList, err = m.clientset.CoreV1().Services(namespace).List(ctx, metav1.ListOptions{
		LabelSelector: selector,
	})
	if len(svcList.Items) == 0 {
		return nil, errors.New("selector service was not found")
	}
	if len(svcList.Items) > 1 {
		return nil, errors.New("too many services")
	}
	return &svcList.Items[0], nil
}

func (m *manager) getPodsForService(ctx context.Context, svc *corev1.Service) ([]corev1.Pod, error) {
	labelSelector := labels.Set(svc.Spec.Selector).AsSelector()
	podList, err := m.clientset.CoreV1().Pods(svc.GetNamespace()).List(ctx, metav1.ListOptions{
		LabelSelector: labelSelector.String(),
	})
	if err != nil {
		return nil, err
	}

	if len(podList.Items) == 0 {
		return nil, errors.New("pod selectord by service was not found")
	}

	return podList.Items, nil
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
	manifests, err := manifest.NewManifests(r.Objects)
	if err != nil {
		logger.Error(err, "failed to get manifests")
		return err
	}

	mutateds := manifests.MustMutate(mutators...).ToObjects()
	if err := m.apply(ctx, mutateds...); err != nil {
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
	manifests, err := manifest.NewManifests(r.Objects)
	if err != nil {
		logger.Error(err, "failed to get manifests")
		return err
	}
	toDelete := manifests.Filter(notStopPolicyRetainSelector).ToObjects()
	if err := m.delete(ctx, toDelete...); err != nil {
		logger.Error(err, "failed to delete devk object")
		return err
	}
	for _, obj := range toDelete {
		if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, obj); err != nil {
			logger.Error(err, "failed to wait devk object terminated")
			return err
		}
	}
	return nil
}

func (m *manager) Update(ctx context.Context, devkName, namespace string, mutators ...mutator.Mutator) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", devkName, "namespace", namespace)
	ctx = logr.NewContext(ctx, logger)

	r, err := m.store.Get(ctx, devkName, namespace)
	if err != nil {
		logger.Error(err, "failed to get release")
		return err
	}

	oldManifests, err := manifest.NewManifests(r.Objects)
	if err != nil {
		logger.Error(err, "failed to get manifests")
		return err
	}
	toRecreate := oldManifests.Filter(notStopPolicyRetainSelector).ToObjects()
	if err := m.delete(ctx, toRecreate...); err != nil {
		logger.Error(err, "failed to delete devk object")
		return err
	}
	for _, obj := range toRecreate {
		if err := kubeutil.WaitForTerminated(ctx, 3*time.Minute, m.unstructured, obj); err != nil {
			logger.Error(err, "failed to wait devk object terminated")
			return err
		}
	}

	newManifests, err := m.loader.Load(r.TemplateName, r.Name, r.Namespace)
	if err != nil {
		logger.Error(err, "failed to load template")
		return err
	}
	r.Objects = newManifests.ToObjects()
	if err := m.store.Update(ctx, devkName, namespace, r); err != nil {
		logger.Error(err, "failed to update release")
		return err
	}
	if err := m.apply(ctx, newManifests.MustMutate(mutators...).ToObjects()...); err != nil {
		logger.Error(err, "failed to apply devk object")
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
