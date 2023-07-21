package client

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/moby/term"
	"github.com/uesyn/dotfiles/tools/devcon/kubernetes/scheme"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/types"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/discovery"
	"k8s.io/client-go/discovery/cached/memory"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/restmapper"
	"k8s.io/client-go/tools/portforward"
	"k8s.io/client-go/tools/remotecommand"
	"k8s.io/client-go/transport/spdy"
	utilsexec "k8s.io/utils/exec"
)

type UnstructuredClient struct {
	scheme     *runtime.Scheme
	restConfig *rest.Config
	mapper     *restmapper.DeferredDiscoveryRESTMapper
	client     dynamic.Interface
}

func NewUnstructuredClient(restConfig *rest.Config) *UnstructuredClient {
	dc := discovery.NewDiscoveryClientForConfigOrDie(restConfig)
	cached := memory.NewMemCacheClient(dc)
	return &UnstructuredClient{
		scheme:     scheme.Scheme,
		restConfig: restConfig,
		mapper:     restmapper.NewDeferredDiscoveryRESTMapper(cached),
		client:     dynamic.NewForConfigOrDie(restConfig),
	}
}

func (u *UnstructuredClient) getNamespaceableResourceInterface(gvk schema.GroupVersionKind) (dynamic.NamespaceableResourceInterface, *meta.RESTMapping, error) {
	mapping, err := u.mapper.RESTMapping(gvk.GroupKind(), gvk.Version)
	if err != nil {
		return nil, nil, err
	}
	return u.client.Resource(mapping.Resource), mapping, nil
}

func (u *UnstructuredClient) getResourceInterface(obj *unstructured.Unstructured) (dynamic.ResourceInterface, error) {
	nr, mapping, err := u.getNamespaceableResourceInterface(obj.GroupVersionKind())
	if err != nil {
		return nil, err
	}
	if mapping.Scope.Name() == meta.RESTScopeNameNamespace {
		return nr.Namespace(obj.GetNamespace()), nil
	}
	return nr, nil
}

type GetOptions = metav1.GetOptions

func (u *UnstructuredClient) Get(ctx context.Context, obj *unstructured.Unstructured, opts metav1.GetOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	return dr.Get(ctx, obj.GetName(), opts)
}

type CreateOptions = metav1.CreateOptions

func (u *UnstructuredClient) Create(ctx context.Context, obj *unstructured.Unstructured, opts metav1.CreateOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	return dr.Create(ctx, obj, opts)
}

type DeleteOptions = metav1.DeleteOptions

func (u *UnstructuredClient) Delete(ctx context.Context, obj *unstructured.Unstructured, opts metav1.DeleteOptions) error {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return err
	}
	return dr.Delete(ctx, obj.GetName(), opts)
}

type UpdateOptions = metav1.UpdateOptions

func (u *UnstructuredClient) Update(ctx context.Context, obj *unstructured.Unstructured, opts metav1.UpdateOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	return dr.Update(ctx, obj, opts)
}

type PatchOptions = metav1.PatchOptions

func (u *UnstructuredClient) Apply(ctx context.Context, obj *unstructured.Unstructured, opts PatchOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	data, err := json.Marshal(obj)
	if err != nil {
		return nil, err
	}
	return dr.Patch(ctx, obj.GetName(), types.ApplyPatchType, data, opts)
}

type ListOptions = metav1.ListOptions

func (u *UnstructuredClient) List(ctx context.Context, gvk schema.GroupVersionKind, opts metav1.ListOptions) (*unstructured.UnstructuredList, error) {
	dr, _, err := u.getNamespaceableResourceInterface(gvk)
	if err != nil {
		return nil, err
	}
	return dr.List(ctx, opts)
}

func (u *UnstructuredClient) Watch(ctx context.Context, gvk schema.GroupVersionKind, opts ListOptions) (watch.Interface, error) {
	dr, _, err := u.getNamespaceableResourceInterface(gvk)
	if err != nil {
		return nil, err
	}
	return dr.Watch(ctx, opts)
}

type ExecOptions struct {
	Stdin     io.ReadCloser
	Stdout    io.Writer
	Stderr    io.Writer
	Container string
	Command   []string
	Envs      map[string]string
}

var notSupportedKindError = errors.New("not supported kind")
var notInTerminalError = errors.New("not in terminal")

func (u *UnstructuredClient) Exec(ctx context.Context, obj *unstructured.Unstructured, opts ExecOptions) error {
	if obj.GroupVersionKind().Kind != "Pod" {
		return notSupportedKindError
	}

	inFd, isTerminal := term.GetFdInfo(opts.Stdin)
	if !isTerminal {
		return notInTerminalError
	}
	outFd, isTerminal := term.GetFdInfo(opts.Stdout)
	if !isTerminal {
		return notInTerminalError
	}

	command := []string{"env"}
	for k, v := range opts.Envs {
		command = append(command, k+"="+v)
	}
	command = append(command, opts.Command...)

	var oldState *term.State
	oldState, err := term.SetRawTerminal(inFd)
	if err != nil {
		return err
	}
	defer func() {
		_ = term.RestoreTerminal(inFd, oldState)
	}()

	queue := newTermSizeQueue(outFd)
	queue.startMonitor()

	clientset := kubernetes.NewForConfigOrDie(u.restConfig)
	req := clientset.CoreV1().RESTClient().Post().Resource("pods").Name(obj.GetName()).Namespace(obj.GetNamespace()).SubResource("exec")
	req.VersionedParams(&corev1.PodExecOptions{
		Container: opts.Container,
		Command:   command,
		Stdin:     opts.Stdin != nil,
		Stdout:    opts.Stdout != nil,
		Stderr:    opts.Stderr != nil,
		TTY:       true,
	}, runtime.NewParameterCodec(u.scheme))
	executor, err := remotecommand.NewSPDYExecutor(u.restConfig, "POST", req.URL())
	if err != nil {
		return err
	}

	streamOpts := remotecommand.StreamOptions{
		Stdin:             opts.Stdin,
		Stdout:            opts.Stderr,
		Stderr:            opts.Stderr,
		Tty:               true,
		TerminalSizeQueue: queue,
	}
	err = executor.StreamWithContext(ctx, streamOpts)
	var e utilsexec.ExitError
	if err != nil && errors.As(err, &e) {
		return nil
	}
	return err
}

type PortForwardOptions struct {
	Addresses []string
	Ports     []string
}

func (u *UnstructuredClient) PortForward(ctx context.Context, obj *unstructured.Unstructured, opts PortForwardOptions) error {
	if obj.GroupVersionKind().Kind != "Pod" {
		return notSupportedKindError
	}

	roundTripper, upgrader, err := spdy.RoundTripperFor(u.restConfig)
	if err != nil {
		return err
	}

	clientset := kubernetes.NewForConfigOrDie(u.restConfig)
	url := clientset.CoreV1().RESTClient().Post().Resource("pods").Name(obj.GetName()).Namespace(obj.GetNamespace()).SubResource("portforward").URL()

	dialer := spdy.NewDialer(upgrader, &http.Client{Transport: roundTripper}, http.MethodPost, url)

	forwarder, err := portforward.NewOnAddresses(
		dialer,
		opts.Addresses,
		opts.Ports,
		make(chan struct{}, 1),
		make(chan struct{}, 1),
		nil,
		nil,
	)
	if err != nil {
		return err
	}
	utilruntime.ErrorHandlers = []func(error){} // suppress error log
	defer forwarder.Close()
	return forwarder.ForwardPorts()
}
