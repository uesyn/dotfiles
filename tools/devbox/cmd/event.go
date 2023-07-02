package cmd

import (
	"context"
	"errors"
	"os"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/manager"
	kuberuntime "k8s.io/apimachinery/pkg/runtime"
	"k8s.io/cli-runtime/pkg/printers"
	cmdevents "k8s.io/kubectl/pkg/cmd/events"
)

type EventOptions struct {
	name  string
	watch bool

	namespace string
	manager   manager.Manager
}

func (o *EventOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "default", "devbox name")
	fs.BoolVarP(&o.watch, "watch", "w", false, "watch events")
}

func (o *EventOptions) Complete(f cmdutil.Factory) error {
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

func (o *EventOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if o.manager == nil {
		return errors.New("must set manager")
	}
	return nil
}

func (o *EventOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("devboxName", o.name, "namespace", o.namespace)

	w := printers.GetNewTabWriter(os.Stdout)
	printer := cmdevents.NewEventPrinter(false, false)
	handler := func(obj kuberuntime.Object) error {
		defer w.Flush()
		if err := printer.PrintObj(obj, w); err != nil {
			logger.Error(err, "failed to print events")
			return err
		}
		return nil
	}

	err := o.manager.Events(ctx, o.name, o.namespace, o.watch, handler)
	if err != nil {
		return err
	}
	return nil
}

func NewEventCmd(f cmdutil.Factory) *cobra.Command {
	o := &EventOptions{}
	cmd := &cobra.Command{
		Use:   "event",
		Short: "Event devbox",
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
