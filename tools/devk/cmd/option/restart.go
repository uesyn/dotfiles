package option

import (
	"context"
	"errors"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/manager"
	"github.com/uesyn/dotfiles/tools/devk/mutator"
	"k8s.io/client-go/kubernetes"
)

type RestartOptions struct {
	name        string
	namespace   string
	force       bool
	selectNodes bool
	gpuNum      int

	clientset kubernetes.Interface
	manager   manager.Manager
}

func (o *RestartOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devk name")
	fs.BoolVarP(&o.selectNodes, "select-nodes", "s", false, "Select node to run on with fuzzy finder")
	fs.BoolVar(&o.force, "force", false, "If true, immediately remove resources from API and bypass graceful deletion")
	fs.IntVar(&o.gpuNum, "gpu", 0, "Amount of GPU")
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
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", o.name, "namespace", o.namespace)

	if err := o.manager.Stop(ctx, o.name, o.namespace, o.force); err != nil {
		return err
	}

	var ms []mutator.Mutator
	if o.selectNodes {
		nodes, err := cmdutil.SelectNodesWithFuzzyFinder(ctx, o.clientset)
		if err != nil {
			logger.Error(err, "failed to get nodes")
			return err
		}
		ms = append(ms, mutator.NewDefaultNodeAffinityMutator(nodes))
	}
	if o.gpuNum > 0 {
		ms = append(ms, mutator.NewGPULimitRequest(o.gpuNum))
	}
	if err := o.manager.Start(ctx, o.name, o.namespace, ms...); err != nil {
		logger.Error(err, "failed to restart")
		return err
	}
	return nil
}
