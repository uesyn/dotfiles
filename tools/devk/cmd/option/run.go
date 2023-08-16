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
	name         string
	templateName string
	selectNodes  bool
	gpuNum       int

	namespace string
	clientSet kubernetes.Interface
	manager   manager.Manager
}

func (o *RunOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "Devk name")
	fs.StringVarP(&o.templateName, "template", "t", "default", "Template name")
	fs.BoolVarP(&o.selectNodes, "select-nodes", "s", false, "Select node to run on with fuzzy finder")
	fs.IntVar(&o.gpuNum, "gpu", 0, "Amount of GPU")
}

func (o *RunOptions) Complete(f util.Factory) error {
	namespace, _, err := f.Namespace()
	if err != nil {
		return err
	}
	o.namespace = namespace

	clientset, err := f.KubeClientSet()
	if err != nil {
		return err
	}
	o.clientSet = clientset

	manager, err := f.Manager()
	if err != nil {
		return err
	}
	o.manager = manager
	return nil
}

func (o *RunOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}
	if len(o.templateName) == 0 {
		return errors.New("must set --template flag")
	}
	if len(o.namespace) == 0 {
		return errors.New("must set Namespace")
	}
	return nil
}

func (o *RunOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devkName", o.name, "namespace", o.namespace)
	var ms []mutator.Mutator
	if o.selectNodes {
		nodes, err := cmdutil.SelectNodesWithFuzzyFinder(ctx, o.clientSet)
		if err != nil {
			logger.Error(err, "failed to get nodes")
			return err
		}
		ms = append(ms, mutator.NewDefaultNodeAffinityMutator(nodes))
	}
	if o.gpuNum > 0 {
		ms = append(ms, mutator.NewGPULimitRequest(o.gpuNum))
	}
	return o.manager.Run(ctx, o.templateName, o.name, o.namespace, ms...)
}
