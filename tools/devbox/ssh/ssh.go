package ssh

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/user"
)

type Options struct {
	User         string
	Port         string
	Address      string
	IdentityFile string
}

func (o *Options) Complete() error {
	if len(o.User) == 0 {
		u, err := user.Current()
		if err != nil {
			return err
		}
		o.User = u.Name
	}

	if len(o.Port) == 0 {
		o.Port = "22"
	}

	if len(o.Address) == 0 {
		o.Address = "localhost"
	}
	return nil
}

func (o *Options) Run(ctx context.Context, shell string, envs map[string]string) error {
	var args []string
	args = append(
		args,
		"-t",
		"-p", o.Port,
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
	)
	if len(o.IdentityFile) > 0 {
		args = append(args, "-i", o.IdentityFile)
	}
	args = append(args, fmt.Sprintf("%s@%s", o.User, o.Address))
	args = append(args, "--")
	args = append(args, "env")
	for k, v := range envs {
		args = append(args, k+"="+v)
	}
	args = append(args, shell)

	cmd := exec.CommandContext(ctx, "ssh", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
