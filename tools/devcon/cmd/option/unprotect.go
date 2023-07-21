package option

import (
	"context"
	"errors"

	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devcon/cmd/util"
	"github.com/uesyn/dotfiles/tools/devcon/manager"
)

type UnprotectOptions struct {
	name string

	namespace string
	manager   manager.Manager
}

func (o *UnprotectOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devbox name")
}

func (o *UnprotectOptions) Complete(f cmdutil.Factory) error {
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
	return nil
}

func (o *UnprotectOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}
	return nil
}

func (o *UnprotectOptions) Run(ctx context.Context) error {
	return o.manager.Unprotect(ctx, o.name, o.namespace)
}
