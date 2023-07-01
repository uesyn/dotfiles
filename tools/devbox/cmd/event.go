package cmd

import (
	"os"

	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
	kuberuntime "k8s.io/apimachinery/pkg/runtime"
	"k8s.io/cli-runtime/pkg/printers"
	cmdevents "k8s.io/kubectl/pkg/cmd/events"
)

func newEventCommand() *cli.Command {
	return &cli.Command{
		Name:    "event",
		Usage:   "Show devbox events",
		Aliases: []string{"events"},
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "name",
				Value: "default",
				Usage: "devbox name",
			},
			&cli.BoolFlag{
				Name:    "watch",
				Aliases: []string{"w"},
				Value:   false,
				Usage:   "watch events",
			},
		},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}
			logger = logger.WithValues("devboxName", params.Name, "namespace", params.Namespace)

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

			err := params.Manager.Events(cCtx.Context, params.Name, params.Namespace, params.Watch, handler)
			if err != nil {
				return err
			}
			return nil
		},
	}
}
