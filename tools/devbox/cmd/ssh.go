package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/uesyn/devbox/manager"
	"github.com/urfave/cli/v2"
)

func newSSHCommand() *cli.Command {
	return &cli.Command{
		Name:    "ssh",
		Usage:   "SSH to devbox",
		Aliases: []string{"s"},
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
			&cli.StringSliceFlag{
				Name:    "port",
				Aliases: []string{"p"},
				Usage:   "Forwarded ports. e.g., 8080:80, 8080",
			},
			&cli.StringFlag{
				Name:    "ssh-identity-file",
				Aliases: []string{"i"},
				Usage:   "Identity file for SSH authentication",
			},
		},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}

			opts := []manager.SSHOption{}
			if len(params.SSHUser) > 0 {
				opts = append(opts, manager.WithSSHUser(params.SSHUser))
			}
			if len(params.SSHIdentityFile) > 0 {
				opts = append(opts, manager.WithSSHIdentityFile(params.SSHIdentityFile))
			}
			if len(params.Envs) > 0 {
				opts = append(opts, manager.WithSSHEnvs(params.Envs))
			}
			if len(params.SSHCommand) > 0 {
				opts = append(opts, manager.WithSSHCommand(params.SSHCommand))
			}
			if len(params.Ports) > 0 {
				opts = append(opts, manager.WithSSHForwardedPorts(params.Ports))
			}

			err := params.Manager.SSH(cCtx.Context, params.Name, params.Namespace, params.SSHPort, opts...)
			if err != nil {
				logger.Error(err, "failed to ssh devbox")
				return err
			}
			return nil
		},
	}
}
