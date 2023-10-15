package ssh

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"

	"github.com/go-logr/logr"
	"github.com/lima-vm/sshocker/pkg/mount"
	"github.com/lima-vm/sshocker/pkg/reversesshfs"
	"github.com/lima-vm/sshocker/pkg/ssh"
)

type Config struct {
	sshConfig    *ssh.SSHConfig
	IdentityFile string
	Envs         map[string]string
	Command      []string
	LForwards    []string
	RForwards    []string
	Mounts       []mount.Mount
}

func (c *Config) Complete() error {
	additionalArgs := []string{
		"-t",
		"-q",
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
	}
	if len(c.IdentityFile) > 0 {
		additionalArgs = append(additionalArgs, "-i", c.IdentityFile)
	}
	if c.sshConfig == nil {
		c.sshConfig = &ssh.SSHConfig{
			Persist:        true,
			AdditionalArgs: additionalArgs,
		}
	}

	if len(c.IdentityFile) > 0 {
		_, err := os.Stat(c.IdentityFile)
		if err != nil {
			return fmt.Errorf("failed to load identity file: %w", err)
		}
	}

	if len(c.Command) == 0 {
		c.Command = []string{"sh"}
	}
	return nil
}

func (c *Config) Connect(ctx context.Context, user, host string, port int) error {
	args, err := c.args(user, host, port)
	if err != nil {
		return err
	}
	cmd := exec.CommandContext(ctx, c.sshConfig.Binary(), args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()

	for _, m := range c.Mounts {
		switch m.Type {
		case mount.MountTypeReverseSSHFS:
			rsf := &reversesshfs.ReverseSSHFS{
				Driver:                  reversesshfs.DriverAuto,
				OpensshSftpServerBinary: reversesshfs.DetectOpensshSftpServerBinary(),
				SSHConfig:               c.sshConfig,
				LocalPath:               m.Source,
				Host:                    sshCommandHost(user, host),
				Port:                    port,
				RemotePath:              m.Destination,
				Readonly:                m.Readonly,
			}
			if err := rsf.Prepare(); err != nil {
				return fmt.Errorf("failed to prepare mounting %q (local) onto %q (remote): %w", rsf.LocalPath, rsf.RemotePath, err)
			}
			if err := rsf.Start(); err != nil {
				return fmt.Errorf("failed to mount %q (local) onto %q (remote): %w", rsf.LocalPath, rsf.RemotePath, err)
			}
			defer func() {
				if cErr := rsf.Close(); cErr != nil {
					logr.FromContextOrDiscard(ctx).Error(cErr, "failed to unmount %q (remote)", rsf.RemotePath)
				}
			}()
		case mount.MountTypeInvalid:
			return fmt.Errorf("invalid mount type %v", m.Type)
		default:
			return fmt.Errorf("unknown mount type %v", m.Type)
		}
	}
	defer func() {
		if c.sshConfig.Persist {
			err := ssh.ExitMaster(sshCommandHost(user, host), port, c.sshConfig)
			if err != nil {
				logr.FromContextOrDiscard(ctx).Error(err, "failed to close SSH connection")
			}
		}
	}()
	return cmd.Run()
}

func (c *Config) args(user, host string, port int) ([]string, error) {
	args := c.sshConfig.Args()
	if port != 0 {
		args = append(args, "-p", strconv.Itoa(port))
	}
	for _, pf := range c.LForwards {
		args = append(args, "-L", pf)
	}
	for _, pf := range c.RForwards {
		args = append(args, "-R", pf)
	}
	args = append(args, sshCommandHost(user, host))
	args = append(args, "--")
	args = append(args, "env")
	for k, v := range c.Envs {
		args = append(args, k+"="+v)
	}
	args = append(args, c.Command...)
	return args, nil
}

func sshCommandHost(user, host string) string {
	return fmt.Sprintf("%s@%s", user, host)
}
