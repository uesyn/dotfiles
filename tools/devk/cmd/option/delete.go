package option

import (
	"context"
	"errors"
	"fmt"

	"github.com/go-logr/logr"
	"github.com/manifoldco/promptui"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/manager"
)

type DeleteOptions struct {
	name  string
	yes   bool
	force bool

	namespace string
	manager   manager.Manager
}

func (o *DeleteOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devk name")
	fs.BoolVar(&o.yes, "yes", false, "Delete devk without any confirmation")
	fs.BoolVar(&o.force, "force", false, "If true, immediately remove resources from API and bypass graceful deletion")
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
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", o.name, "namespace", o.namespace)

	if !o.yes && !deleteConfirmationPrompt(o.name) {
		return nil
	}
	if err := o.manager.Delete(ctx, o.name, o.namespace, o.force); err != nil {
		logger.Error(err, "failed to delete devk objects")
		return err
	}
	logger.Info("devk objects were deleted")
	return nil
}

func deleteConfirmationPrompt(devkName string) bool {
	prompt := promptui.Prompt{
		Label: fmt.Sprintf("Please type '%s' to confirm.", devkName),
		Validate: func(input string) error {
			if input != devkName {
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
