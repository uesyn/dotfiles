package client

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/moby/term"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/client-go/kubernetes"
	_ "k8s.io/client-go/plugin/pkg/client/auth"
	restclient "k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/portforward"
	"k8s.io/client-go/tools/remotecommand"
	"k8s.io/client-go/transport/spdy"
	utilsexec "k8s.io/utils/exec"
	ctrlclient "sigs.k8s.io/controller-runtime/pkg/client"
)

func newConfig(configPath string, contextName string) clientcmd.ClientConfig {
	rules := clientcmd.NewDefaultClientConfigLoadingRules()
	if configPath != "" {
		configPathList := filepath.SplitList(configPath)
		if len(configPathList) <= 1 {
			rules.ExplicitPath = configPath
		} else {
			rules.Precedence = configPathList
		}
	}
	return clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		rules,
		&clientcmd.ConfigOverrides{
			CurrentContext: contextName,
		},
	)
}

type Client interface {
	ctrlclient.Client
	Exec(ctx context.Context, podName, namespace, containerName string, opts ...ExecOption) error
	PortForward(ctx context.Context, podName, namespace string, opts ...PortForwardOption) error
}

func New(configPath string, context string) (Client, error) {
	c := newConfig(configPath, context)
	restConfig, err := c.ClientConfig()
	if err != nil {
		return nil, err
	}

	client, err := ctrlclient.New(restConfig, ctrlclient.Options{})
	if err != nil {
		return nil, err
	}

	return &defaultClient{
		Client:     client,
		restConfig: restConfig,
	}, nil
}

type defaultClient struct {
	ctrlclient.Client
	restConfig *restclient.Config
}

func (c *defaultClient) Exec(ctx context.Context, podName, namespace, containerName string, opts ...ExecOption) error {
	execOpts := &ExecOptions{}
	execOpts.ApplyOptions(opts)

	if !term.IsTerminal(execOpts.Stdin.Fd()) {
		return fmt.Errorf("must run in terminal")
	}

	command := []string{"env"}
	for k, v := range execOpts.Envs {
		command = append(command, k+"="+v)
	}
	command = append(command, execOpts.Command...)

	var oldState *term.State
	oldState, err := term.SetRawTerminal(execOpts.Stdin.Fd())
	if err != nil {
		return err
	}
	defer func() {
		_ = term.RestoreTerminal(execOpts.Stdin.Fd(), oldState)
	}()

	queue := newTermSizeQueue(execOpts.Stdin.Fd())
	queue.startMonitor()

	clientset := kubernetes.NewForConfigOrDie(c.restConfig)
	req := clientset.CoreV1().RESTClient().Post().Resource("pods").Name(podName).Namespace(namespace).SubResource("exec")
	req.VersionedParams(&corev1.PodExecOptions{
		Container: containerName,
		Command:   command,
		Stdin:     execOpts.Stdin != nil,
		Stdout:    execOpts.Stdout != nil,
		Stderr:    execOpts.Stderr != nil,
		TTY:       true,
	}, runtime.NewParameterCodec(c.Scheme()))
	executor, err := remotecommand.NewSPDYExecutor(c.restConfig, "POST", req.URL())
	if err != nil {
		return err
	}

	streamOpts := remotecommand.StreamOptions{
		Stdin:             execOpts.Stdin,
		Stdout:            execOpts.Stderr,
		Stderr:            execOpts.Stderr,
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

type ExecOption interface {
	ApplyToExec(*ExecOptions)
}

type ExecOptions struct {
	Stdin   *os.File
	Stdout  io.Writer
	Stderr  io.Writer
	Command []string
	Envs    map[string]string
}

func (o ExecOptions) ApplyToExec(to *ExecOptions) {
	if o.Stdin != nil {
		to.Stdin = o.Stdin
	}

	if o.Stdout != nil {
		to.Stdout = o.Stdout
	}

	if o.Stderr != nil {
		to.Stderr = o.Stderr
	}

	if len(o.Command) > 0 {
		to.Command = o.Command
	}

	if len(o.Envs) > 0 {
		to.Envs = o.Envs
	}
}

func (o *ExecOptions) ApplyOptions(opts []ExecOption) *ExecOptions {
	for _, opt := range opts {
		opt.ApplyToExec(o)
	}
	return o
}

func (c *defaultClient) PortForward(ctx context.Context, name, namespace string, opts ...PortForwardOption) error {
	portForwardOpts := PortForwardOptions{}
	portForwardOpts.ApplyOptions(opts)

	roundTripper, upgrader, err := spdy.RoundTripperFor(c.restConfig)
	if err != nil {
		return err
	}

	clientset := kubernetes.NewForConfigOrDie(c.restConfig)
	url := clientset.CoreV1().RESTClient().Post().Resource("pods").Name(name).Namespace(namespace).SubResource("portforward").URL()

	dialer := spdy.NewDialer(upgrader, &http.Client{Transport: roundTripper}, http.MethodPost, url)

	forwarder, err := portforward.NewOnAddresses(
		dialer,
		portForwardOpts.Addresses,
		portForwardOpts.Ports,
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

type PortForwardOption interface {
	ApplyToPortForward(*PortForwardOptions)
}

type PortForwardOptions struct {
	Addresses []string
	Ports     []string
}

func (o PortForwardOptions) ApplyToPortForward(to *PortForwardOptions) {
	if len(o.Addresses) > 0 {
		to.Addresses = o.Addresses
	}

	if len(o.Ports) > 0 {
		to.Ports = o.Ports
	}
}

func (o *PortForwardOptions) ApplyOptions(opts []PortForwardOption) *PortForwardOptions {
	for _, opt := range opts {
		opt.ApplyToPortForward(o)
	}
	return o
}
