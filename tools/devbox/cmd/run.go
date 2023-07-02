package cmd

import (
	"context"
	"errors"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"github.com/uesyn/devbox/cmd/util"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/manager"
	"github.com/uesyn/devbox/mutator"
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
	fs.StringVarP(&o.Name, "name", "n", "default", "devbox name")
	fs.StringVarP(&o.TemplateName, "template", "t", "default", "template name")
	fs.BoolVarP(&o.SelectNodes, "select-nodes", "s", false, "select node to run on with fuzzy finder")
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
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", o.Name, "namespace", o.Namespace)
	var ms []mutator.PodMutator
	if o.SelectNodes {
		nodes, err := cmdutil.SelectNodesWithFuzzyFinder(ctx, o.ClientSet)
		if err != nil {
			logger.Error(err, "failed to get nodes")
			return err
		}
		ms = append(ms, mutator.NewNodeAffinityMutator(nodes))
	}
	return o.Manager.Run(ctx, o.TemplateName, o.Name, o.Namespace, ms...)
}

func NewRunCmd(f cmdutil.Factory) *cobra.Command {
	o := &RunOptions{}
	cmd := &cobra.Command{
		Use:   "run",
		Short: "Run devbox",
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
