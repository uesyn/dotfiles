package ssh

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

type Options struct {
	IdentityFile         string
	Envs                 map[string]string
	Command              []string
	LocalForwardedPorts  []string
	RemoteForwardedPorts []string
}

type ForwardedPort struct {
	From int
	To   int
}

func (o *Options) Complete() error {
	if len(o.IdentityFile) > 0 {
		_, err := os.Stat(o.IdentityFile)
		if err != nil {
			return fmt.Errorf("failed to load identity file: %w", err)
		}
	}

	for _, p := range o.LocalForwardedPorts {
		_, err := o.parseForwardedPort(p)
		if err != nil {
			return err
		}
	}
	return nil
}

func (o *Options) Connect(ctx context.Context, user, ip string, port int) error {
	args, err := o.buildSSHCommandArgs(user, ip, port)
	if err != nil {
		return err
	}
	cmd := exec.CommandContext(ctx, "ssh", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (o *Options) buildSSHCommandArgs(user, ip string, port int) ([]string, error) {
	var args []string
	args = append(
		args,
		"-t",
		"-q",
		"-p", strconv.Itoa(port),
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
	)
	if len(o.IdentityFile) > 0 {
		args = append(args, "-i", o.IdentityFile)
	}
	const localhost = "127.0.0.1"
	for _, port := range o.LocalForwardedPorts {
		fp, err := o.parseForwardedPort(port)
		if err != nil {
			return nil, err
		}
		opt := fmt.Sprintf("%d:%s:%d", fp.From, localhost, fp.To)
		args = append(args, "-L", opt)
	}
	for _, port := range o.RemoteForwardedPorts {
		fp, err := o.parseForwardedPort(port)
		if err != nil {
			return nil, err
		}
		opt := fmt.Sprintf("%d:%s:%d", fp.From, localhost, fp.To)
		args = append(args, "-R", opt)
	}
	args = append(args, fmt.Sprintf("%s@%s", user, ip))
	args = append(args, "--")
	args = append(args, "env")
	for k, v := range o.Envs {
		args = append(args, k+"="+v)
	}
	args = append(args, o.Command...)
	return args, nil
}

func (o *Options) parseForwardedPort(port string) (*ForwardedPort, error) {
	pp := strings.SplitN(port, ":", 2)
	lpStr, rpStr := pp[0], pp[0]
	if len(pp) > 1 {
		rpStr = pp[1]
	}
	l, err := strconv.Atoi(lpStr)
	if err != nil {
		return nil, fmt.Errorf("failed to parse port: %w", err)
	}
	r, err := strconv.Atoi(rpStr)
	if err != nil {
		return nil, fmt.Errorf("failed to parse port: %w", err)
	}
	return &ForwardedPort{
		To:   r,
		From: l,
	}, nil
}
