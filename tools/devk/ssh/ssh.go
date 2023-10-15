package ssh

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
)

type Options struct {
	IdentityFile string
	Envs         map[string]string
	Command      []string
	LForwards    []string
	RForwards    []string
}

func (o *Options) Complete() error {
	if len(o.IdentityFile) > 0 {
		_, err := os.Stat(o.IdentityFile)
		if err != nil {
			return fmt.Errorf("failed to load identity file: %w", err)
		}
	}
	return nil
}

func (o *Options) Connect(ctx context.Context, user, ip string, port int) error {
	args, err := o.args(user, ip, port)
	if err != nil {
		return err
	}
	cmd := exec.CommandContext(ctx, "ssh", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	return cmd.Run()
}

func (o *Options) args(user, host string, port int) ([]string, error) {
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
	for _, pf := range o.LForwards {
		args = append(args, "-L", pf)
	}
	for _, pf := range o.RForwards {
		args = append(args, "-R", pf)
	}
	args = append(args, fmt.Sprintf("%s@%s", user, host))
	args = append(args, "--")
	args = append(args, "env")
	for k, v := range o.Envs {
		args = append(args, k+"="+v)
	}
	args = append(args, o.Command...)
	return args, nil
}
