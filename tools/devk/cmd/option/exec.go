package option

import (
	"context"
	"errors"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/manager"
)

type ExecOptions struct {
	name      string
	addresses []string
	ports     []string

	execCommand []string
	execEnvs    map[string]string
	execUser    string
	namespace   string
	manager     manager.Manager
}

func (o *ExecOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devk name")
	fs.StringArrayVar(&o.addresses, "address", []string{"127.0.0.1"}, "Addresses are binded for port-forward")
	fs.StringArrayVarP(&o.ports, "port", "p", nil, "Forwarded ports. e.g., 8080:80, 8080")
}

func (o *ExecOptions) Complete(f cmdutil.Factory) error {
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

	manager, err := f.Manager()
	if err != nil {
		return err
	}
	o.manager = manager

	conf, err := f.DevkConfig()
	if err != nil {
		return err
	}
	envs := make(map[string]string)
	for _, env := range conf.Exec.Envs {
		envs[env.Name] = env.Value
	}
	o.execEnvs = envs
	o.execCommand = conf.Exec.Command
	o.execUser = conf.Exec.User
	return nil
}

func (o *ExecOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if len(o.addresses) == 0 {
		return errors.New("must set --address flag")
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}

	if len(o.execCommand) == 0 {
		return errors.New("must set exec command")
	}
	return nil
}

func (o *ExecOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", o.name, "namespace", o.namespace)

	// Port forward
	if len(o.ports) > 0 && len(o.addresses) > 0 {
		go func() {
			opts := []manager.PortForwardOption{
				manager.WithPortForwardAddresses(o.addresses),
				manager.WithPortForwardPorts(o.ports),
			}
			if err := o.manager.PortForward(ctx, o.name, o.namespace, opts...); err != nil {
				logger.Error(err, "failed to forward ports")
			}
		}()
	}

	// Exec
	opts := []manager.ExecOption{}
	if len(o.execCommand) > 0 {
		opts = append(opts, manager.WithExecCommand(o.execCommand))
	}
	if len(o.execEnvs) > 0 {
		opts = append(opts, manager.WithExecEnvs(o.execEnvs))
	}
	if len(o.execUser) > 0 {
		opts = append(opts, manager.WithExecUser(o.execUser))
	}
	if err := o.manager.Exec(ctx, o.name, o.namespace, opts...); err != nil {
		logger.Error(err, "failed to exec")
		return err
	}
	return nil
}
