package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
)

func newStopCommand() *cli.Command {
	return &cli.Command{
		Name:  "stop",
		Usage: "Stop devbox",
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

			if err := params.Manager.Stop(ctx, params.Name, params.Namespace); err != nil {
				logger.Error(err, "failed to stop devbox")
				return err
			}
			return nil
		},
	}
}
