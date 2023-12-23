package client

import (
	"context"
	"errors"
	"io"

	"github.com/moby/term"
	"github.com/uesyn/dotfiles/tools/devk/kubernetes/scheme"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/remotecommand"
	utilsexec "k8s.io/utils/exec"
)

type ExecClient struct {
	scheme     *runtime.Scheme
	restConfig *rest.Config
}

func NewExecClient(restConfig *rest.Config) *ExecClient {
	return &ExecClient{
		scheme:     scheme.Scheme,
		restConfig: restConfig,
	}
}

type ExecOptions struct {
	Stdin     io.ReadCloser
	Stdout    io.Writer
	Stderr    io.Writer
	Container string
	Command   []string
	Envs      map[string]string
	User      string
}

var notInTerminalError = errors.New("not in terminal")

func (c *ExecClient) Exec(ctx context.Context, pod *corev1.Pod, opts ExecOptions) error {
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
	if len(opts.User) > 0 {
		command = append(command, "gosu", opts.User)
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

	clientset := kubernetes.NewForConfigOrDie(c.restConfig)
	req := clientset.CoreV1().RESTClient().Post().Resource("pods").Name(pod.GetName()).Namespace(pod.GetNamespace()).SubResource("exec")
	req.VersionedParams(&corev1.PodExecOptions{
		Container: opts.Container,
		Command:   command,
		Stdin:     opts.Stdin != nil,
		Stdout:    opts.Stdout != nil,
		Stderr:    opts.Stderr != nil,
		TTY:       true,
	}, runtime.NewParameterCodec(c.scheme))
	executor, err := remotecommand.NewSPDYExecutor(c.restConfig, "POST", req.URL())
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
