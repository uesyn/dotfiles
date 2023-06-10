package cmd

import (
	"os"

	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
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
			&cli.StringFlag{
				Name:    "namespace",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "kubernetes namespace where devbox run",
				EnvVars: []string{"DEVBOX_NAMESPACE"},
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
			ctx := logr.NewContext(cCtx.Context, logger)

			el, err := params.Manager.Events(ctx, params.Name, params.Namespace)
			if err != nil {
				logger.Error(err, "failed to get events")
				return err
			}
			w := printers.GetNewTabWriter(os.Stdout)
			printer := cmdevents.NewEventPrinter(false, false)
			if err := printer.PrintObj(el, w); err != nil {
				logger.Error(err, "failed to print events")
			}
			w.Flush()
			return nil
		},
	}
}
