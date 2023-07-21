package option

import (
	"context"
	"errors"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devcon/cmd/util"
	"github.com/uesyn/dotfiles/tools/devcon/manager"
	"github.com/uesyn/dotfiles/tools/devcon/mutator"
	"k8s.io/client-go/kubernetes"
)

type RestartOptions struct {
	name        string
	selectNodes bool

	namespace string
	clientset kubernetes.Interface
	manager   manager.Manager
}

func (o *RestartOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devbox name")
	fs.BoolVarP(&o.selectNodes, "select-nodes", "s", false, "Select node to run on with fuzzy finder")
}

func (o *RestartOptions) Complete(f cmdutil.Factory) error {
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

func (o *RestartOptions) Validate() error {
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

func (o *RestartOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", o.name, "namespace", o.namespace)

	if err := o.manager.Stop(ctx, o.name, o.namespace); err != nil {
		return err
	}

	var ms []mutator.PodMutator
	if o.selectNodes {
		nodes, err := cmdutil.SelectNodesWithFuzzyFinder(ctx, o.clientset)
		if err != nil {
			logger.Error(err, "failed to get nodes")
			return err
		}
		ms = append(ms, mutator.NewNodeAffinityMutator(nodes))
	}
	return o.manager.Start(ctx, o.name, o.namespace, ms...)
}
