package cmd

import (
	"context"
	"errors"

	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/manager"
)

type ProtectOptions struct {
	name string

	namespace string
	manager   manager.Manager
}

func (o *ProtectOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "devbox name")
}

func (o *ProtectOptions) Complete(f cmdutil.Factory) error {
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

func (o *ProtectOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}
	return nil
}

func (o *ProtectOptions) Run(ctx context.Context) error {
	return o.manager.Protect(ctx, o.name, o.namespace)
}

func NewProtectCmd(f cmdutil.Factory) *cobra.Command {
	o := &ProtectOptions{}
	cmd := &cobra.Command{
		Use:   "protect",
		Short: "Protect devbox",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			if err := o.Complete(f); err != nil {
				return err
			}
			if err := o.Validate(); err != nil {
				return err
			}
			if err := o.Run(ctx); err != nil {
				return err
			}
			return nil
		},
	}
	o.AddFlags(cmd.Flags())
	return cmd
}
