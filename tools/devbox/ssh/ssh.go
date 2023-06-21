package ssh

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"strconv"
	"strings"
)

type Options struct {
	User           string
	Port           int
	Address        string
	IdentityFile   string
	Envs           map[string]string
	Shell          string
	ForwardedPorts []string
}

type ForwardedPort struct {
	Remote int
	Local  int
}

func (o *Options) Complete() error {
	if len(o.User) == 0 {
		u, err := user.Current()
		if err != nil {
			return err
		}
		o.User = u.Name
	}

	if o.Port == 0 {
		o.Port = 22
	}

	if len(o.Address) == 0 {
		o.Address = "localhost"
	}

	if len(o.IdentityFile) > 0 {
		_, err := os.Stat(o.IdentityFile)
		if err != nil {
			return fmt.Errorf("failed to load identity file: %w", err)
		}
	}

	for _, p := range o.ForwardedPorts {
		_, err := o.parseForwardedPort(p)
		if err != nil {
			return err
		}
	}
	return nil
}

func (o *Options) Run(ctx context.Context) error {
	args, err := o.buildSSHCommandArgs()
	if err != nil {
		return err
	}
	cmd := exec.CommandContext(ctx, "ssh", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (o *Options) buildSSHCommandArgs() ([]string, error) {
	var args []string
	args = append(
		args,
		"-t",
		"-p", strconv.Itoa(o.Port),
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
	)
	if len(o.IdentityFile) > 0 {
		args = append(args, "-i", o.IdentityFile)
	}
	const localhost = "localhost"
	for _, port := range o.ForwardedPorts {
		fp, err := o.parseForwardedPort(port)
		if err != nil {
			return nil, err
		}
		opt := fmt.Sprintf("%d:%s:%d", fp.Local, localhost, fp.Remote)
		args = append(args, "-L", opt)
	}
	args = append(args, fmt.Sprintf("%s@%s", o.User, o.Address))
	args = append(args, "--")
	args = append(args, "env")
	for k, v := range o.Envs {
		args = append(args, k+"="+v)
	}
	args = append(args, o.Shell)
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
		Remote: r,
		Local:  l,
	}, nil
}
