package cmd

import (
	"context"
	"errors"
	"fmt"

	"github.com/manifoldco/promptui"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/manager"
)

type DeleteOptions struct {
	name string

	namespace string
	manager   manager.Manager
}

func (o *DeleteOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "devbox name")
}

func (o *DeleteOptions) Complete(f cmdutil.Factory) error {
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

func (o *DeleteOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}
	return nil
}

func (o *DeleteOptions) Run(ctx context.Context) error {
	return o.manager.Delete(ctx, o.name, o.namespace)
}

func NewDeleteCmd(f cmdutil.Factory) *cobra.Command {
	o := &DeleteOptions{}
	cmd := &cobra.Command{
		Use:   "delete",
		Short: "Delete devbox",
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

func deleteConfirmationPrompt(devboxName string) bool {
	prompt := promptui.Prompt{
		Label: fmt.Sprintf("Please type '%s' to confirm.", devboxName),
		Validate: func(input string) error {
			if input != devboxName {
				return fmt.Errorf("invalid input")
			}
			return nil
		},
	}

	if _, err := prompt.Run(); err != nil {
		return false
	}
	return true
}
