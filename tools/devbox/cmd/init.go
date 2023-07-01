package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/uesyn/devbox/common"
	"github.com/uesyn/devbox/initialize"
	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/urfave/cli/v2"
)

func newInitCommand() *cli.Command {
	return &cli.Command{
		Name:  "init",
		Usage: "initialize devbox configs",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "namespace",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "kubernetes namespace where devbox run",
				EnvVars: []string{"DEVBOX_NAMESPACE"},
			},
			&cli.StringFlag{
				Name:    "context",
				Usage:   "the name of the kubeconfig context to use",
				EnvVars: []string{"DEVBOX_CONTEXT"},
			},
			&cli.StringFlag{
				Name:    "kubeconfig",
				Usage:   "path to kubeconfig file",
				Value:   "${HOME}/.kube/config",
				EnvVars: []string{"DEVBOX_KUBECONFIG", "KUBECONFIG"},
			},
		},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}

			config, err := initialize.GenerateDevboxKubeconfig(params.InitKubeConfig, params.InitKubeContext, params.InitNamespace)
			if err != nil {
				logger.Error(err, "Failed to generate kubeconfig for devbox")
				return err
			}

			if err := client.WriteKubeconfig(*config, common.DevboxKubeConfigPath); err != nil {
				logger.Error(err, "Failed to write kubeconfig for devbox")
				return err
			}
			return nil
		},
	}
}
