package option

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/lima-vm/sshocker/pkg/mount"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/manager"
	"github.com/uesyn/dotfiles/tools/devk/util"
)

type SSHOptions struct {
	name         string
	lForwards    []string
	rForwards    []string
	identityFile string
	command      []string
	envs         map[string]string
	namespace    string
	mounts       []string
	manager      manager.Manager
}

func (o *SSHOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devk name")
	fs.StringArrayVarP(&o.lForwards, "local", "L", nil, "Local port forwarding ports. e.g., 8080:80, 8080")
	fs.StringArrayVarP(&o.rForwards, "remote", "R", nil, "Remote port forwarding ports. e.g., 8080:80, 8080")
	fs.StringArrayVarP(&o.mounts, "volume", "v", nil, "Bind mount a volume")
	fs.StringVarP(&o.identityFile, "identity-file", "i", "", "Identity file for SSH authentication")
}

func (o *SSHOptions) Complete(f cmdutil.Factory) error {
	m, err := f.Manager()
	if err != nil {
		return err
	}
	o.manager = m

	namespace, _, err := f.Namespace()
	if err != nil {
		return err
	}
	o.namespace = namespace

	conf, err := f.DevkConfig()
	if err != nil {
		return err
	}
	o.command = conf.SSH.Command

	envs := make(map[string]string)
	for _, env := range conf.Envs {
		envs[env.Name] = env.Value
	}
	o.envs = envs
	return nil
}

func (o *SSHOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if len(o.identityFile) != 0 {
		if _, err := os.Stat(o.identityFile); err != nil {
			return fmt.Errorf("failed to read ssh identity file:%w", err)
		}
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}

	for _, m := range o.mounts {
		if _, err := o.parseVFlag(m); err != nil {
			return fmt.Errorf("failed to parse --volume flag: %v", err)
		}
	}
	return nil
}

func (o *SSHOptions) Run(ctx context.Context) error {
	opts := []manager.SSHOption{}
	if len(o.identityFile) > 0 {
		opts = append(opts, manager.WithSSHIdentityFile(o.identityFile))
	}
	if len(o.envs) > 0 {
		opts = append(opts, manager.WithSSHEnvs(o.envs))
	}
	if len(o.command) > 0 {
		opts = append(opts, manager.WithSSHCommand(o.command))
	}
	if len(o.lForwards) > 0 {
		for _, arg := range o.lForwards {
			v, err := o.parseForwardFlag(arg)
			if err != nil {
				return err
			}
			opts = append(opts, manager.WithSSHLForward(v))
		}
	}
	if len(o.rForwards) > 0 {
		for _, arg := range o.rForwards {
			v, err := o.parseForwardFlag(arg)
			if err != nil {
				return err
			}
			opts = append(opts, manager.WithSSHRForward(v))
		}
	}
	if len(o.mounts) > 0 {
		for _, arg := range o.mounts {
			v, err := o.parseVFlag(arg)
			if err != nil {
				return err
			}
			opts = append(opts, manager.WithSSHVolumeMount(v))
		}
	}
	return o.manager.SSH(ctx, o.name, o.namespace, opts...)
}

func (o *SSHOptions) parseForwardFlag(arg string) (string, error) {
	pp := strings.SplitN(arg, ":", 2)
	switch len(pp) {
	case 1:
		port, err := strconv.Atoi(pp[0])
		if err != nil {
			return "", fmt.Errorf("invalid port %q", pp[0])
		}
		return fmt.Sprintf("%d:localhost:%d", port, port), nil
	case 2:
		local, err := strconv.Atoi(pp[0])
		if err != nil {
			return "", fmt.Errorf("invalid port %q", pp[0])
		}
		remote, err := strconv.Atoi(pp[1])
		if err != nil {
			return "", fmt.Errorf("invalid port %q", pp[1])
		}
		return fmt.Sprintf("%d:localhost:%d", local, remote), nil
	default:
		return "", fmt.Errorf("invalid arg %q", arg)
	}
}

func (o *SSHOptions) parseVFlag(s string) (mount.Mount, error) {
	m := mount.Mount{
		Type: mount.MountTypeReverseSSHFS,
	}
	pp := strings.Split(s, ":")
	switch len(pp) {
	case 2:
		m.Source = pp[0]
		m.Destination = pp[1]
	case 3:
		m.Source = pp[0]
		m.Destination = pp[1]
		if pp[2] == "ro" {
			m.Readonly = true
		} else {
			return m, fmt.Errorf("invalid mount option %q", pp[2])
		}
	default:
		return m, fmt.Errorf("failed to parse %q", s)
	}
	m.Source = util.ExpandPath(m.Source)
	return m, nil
}
