package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/uesyn/devbox/manager"
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

			// Port forward
			if len(params.Ports) > 0 && len(params.Addresses) > 0 {
				go func() {
					opts := []manager.PortForwardOption{
						manager.WithPortForwardAddresses(params.Addresses),
						manager.WithPortForwardPorts(params.Ports),
					}
					params.Manager.PortForward(cCtx.Context, params.Name, params.Namespace, opts...)
				}()
			}

			// Exec
			opts := []manager.ExecOption{}
			if len(params.ExecCommand) > 0 {
				opts = append(opts, manager.WithExecCommand(params.ExecCommand))
			}
			if len(params.Envs) > 0 {
				opts = append(opts, manager.WithExecEnvs(params.Envs))
			}
			return params.Manager.Exec(cCtx.Context, params.Name, params.Namespace, opts...)
		},
	}
}
