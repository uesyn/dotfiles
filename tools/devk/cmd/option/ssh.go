package option

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/manager"
)

type SSHOptions struct {
	name         string
	lPorts       []string
	rPorts       []string
	identityFile string
	useServiceIP bool

	sshCommand []string
	sshEnvs    map[string]string
	namespace  string
	manager    manager.Manager
}

func (o *SSHOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devk name")
	fs.StringArrayVarP(&o.lPorts, "local", "L", nil, "Local port forwarding ports. e.g., 8080:80, 8080")
	fs.StringArrayVarP(&o.rPorts, "remote", "R", nil, "Remote port forwarding ports. e.g., 8080:80, 8080")
	fs.StringVarP(&o.identityFile, "identity-file", "i", "", "Identity file for SSH authentication")
	fs.BoolVarP(&o.useServiceIP, "use-service-ip", "s", false, "Connect SSH through Service IP")
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
	o.sshCommand = conf.SSH.Command
	if len(o.sshCommand) == 0 {
		o.sshCommand = []string{"sh"}
	}

	envs := make(map[string]string)
	for _, env := range conf.Envs {
		envs[env.Name] = env.Value
	}
	o.sshEnvs = envs
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

	if len(o.sshCommand) == 0 {
		return errors.New("must set ssh command")
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}
	return nil
}

func (o *SSHOptions) Run(ctx context.Context) error {
	opts := []manager.SSHOption{}
	if len(o.identityFile) > 0 {
		opts = append(opts, manager.WithSSHIdentityFile(o.identityFile))
	}
	if len(o.sshEnvs) > 0 {
		opts = append(opts, manager.WithSSHEnvs(o.sshEnvs))
	}
	if len(o.sshCommand) > 0 {
		opts = append(opts, manager.WithSSHCommand(o.sshCommand))
	}
	if len(o.lPorts) > 0 {
		opts = append(opts, manager.WithSSHLocalForwardedPorts(o.lPorts))
	}
	if len(o.rPorts) > 0 {
		opts = append(opts, manager.WithSSHRemoteForwardedPorts(o.rPorts))
	}
	return o.manager.SSH(ctx, o.name, o.namespace, o.useServiceIP, opts...)
}
