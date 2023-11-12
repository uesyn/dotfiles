package option

import (
	"context"
	"errors"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/manager"
	"k8s.io/client-go/kubernetes"
)

type StopOptions struct {
	name      string
	namespace string
	force     bool

	clientset kubernetes.Interface
	manager   manager.Manager
}

func (o *StopOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devk name")
	fs.BoolVar(&o.force, "force", false, "If true, immediately remove resources from API and bypass graceful deletion")
}

func (o *StopOptions) Complete(f cmdutil.Factory) error {
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

	clientset, err := f.KubeClientSet()
	if err != nil {
		return err
	}
	o.clientset = clientset
	return nil
}

func (o *StopOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}

	if o.clientset == nil {
		return errors.New("must set clientset")
	}
	return nil
}

func (o *StopOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", o.name, "namespace", o.namespace)
	if err := o.manager.Stop(ctx, o.name, o.namespace, o.force); err != nil {
		logger.Error(err, "failed to stop")
		return err
	}
	return nil
}
