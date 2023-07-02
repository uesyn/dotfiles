package option

import (
	"context"
	"errors"
	"fmt"

	"github.com/manifoldco/promptui"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/manager"
)

type DeleteOptions struct {
	name  string
	force bool

	namespace string
	manager   manager.Manager
}

func (o *DeleteOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "devbox name")
	fs.BoolVar(&o.force, "force", false, "delete devbox forcibly")
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
	if !o.force && !deleteConfirmationPrompt(o.name) {
		return nil
	}
	return o.manager.Delete(ctx, o.name, o.namespace)
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
