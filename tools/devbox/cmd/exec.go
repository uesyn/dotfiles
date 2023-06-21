package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
)

func newExecCommand() *cli.Command {
	return &cli.Command{
		Name:    "exec",
		Usage:   "Exec devbox",
		Aliases: []string{"e"},
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
			&cli.StringFlag{
				Name:    "template",
				Aliases: []string{"t"},
				Value:   "default",
				Usage:   "template name",
			},
			&cli.StringSliceFlag{
				Name:  "address",
				Value: cli.NewStringSlice("127.0.0.1"),
				Usage: "Addresses are binded for port-forward",
			},
			&cli.StringSliceFlag{
				Name:    "port",
				Aliases: []string{"p"},
				Usage:   "Forwarded ports. e.g., 8080:80, 8080",
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

			// Port forward
			if len(params.Ports) > 0 && len(params.Addresses) > 0 {
				go func() {
					err := params.Manager.PortForward(ctx, params.Name, params.Namespace, params.Ports, params.Addresses)
					if err != nil {
						logger.Error(err, "failed to forward ports")
					}
				}()
			}

			// Exec
			envs, err := params.Config.GetEnvs()
			if err != nil {
				logger.Error(err, "failed to load envs config")
				return err
			}
			err = params.Manager.Exec(ctx, params.Name, params.Namespace, params.Config.GetExecConfig().GetCommand(), envs)
			if err != nil {
				logger.Error(err, "failed to exec devbox")
				return err
			}
			return nil
		},
	}
}
