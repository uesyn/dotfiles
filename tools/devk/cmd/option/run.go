package option

import (
	"context"
	"errors"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	"github.com/uesyn/dotfiles/tools/devk/cmd/util"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/manager"
	"github.com/uesyn/dotfiles/tools/devk/mutator"
	"k8s.io/client-go/kubernetes"
)

type RunOptions struct {
	Name         string
	TemplateName string
	SelectNodes  bool

	Namespace string
	ClientSet kubernetes.Interface
	Manager   manager.Manager
}

func (o *RunOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.Name, "name", "n", "default", "Devk name")
	fs.StringVarP(&o.TemplateName, "template", "t", "default", "Template name")
	fs.BoolVarP(&o.SelectNodes, "select-nodes", "s", false, "Select node to run on with fuzzy finder")
}

func (o *RunOptions) Complete(f util.Factory) error {
	namespace, _, err := f.Namespace()
	if err != nil {
		return err
	}
	o.Namespace = namespace

	clientset, err := f.KubeClientSet()
	if err != nil {
		return err
	}
	o.ClientSet = clientset

	manager, err := f.Manager()
	if err != nil {
		return err
	}
	o.Manager = manager
	return nil
}

func (o *RunOptions) Validate() error {
	if len(o.Name) == 0 {
		return errors.New("must set --name flag")
	}
	if len(o.TemplateName) == 0 {
		return errors.New("must set --template flag")
	}
	if len(o.Namespace) == 0 {
		return errors.New("must set Namespace")
	}
	return nil
}

func (o *RunOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", o.Name, "namespace", o.Namespace)
	var ms []mutator.Mutator
	if o.SelectNodes {
		nodes, err := cmdutil.SelectNodesWithFuzzyFinder(ctx, o.ClientSet)
		if err != nil {
			logger.Error(err, "failed to get nodes")
			return err
		}
		ms = append(ms, mutator.NewDefaultNodeAffinityMutator(nodes))
	}
	return o.Manager.Run(ctx, o.TemplateName, o.Name, o.Namespace, ms...)
}
