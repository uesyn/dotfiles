package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/mutator"
	"github.com/urfave/cli/v2"
)

func newStartCommand() *cli.Command {
	return &cli.Command{
		Name:  "start",
		Usage: "Start devbox",
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
			&cli.BoolFlag{
				Name:    "select-nodes",
				Aliases: []string{"s"},
				Value:   false,
				Usage:   "select node to run on with fuzzy finder",
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

			var ms []mutator.PodMutator
			if params.SelectNodes {
				nodes, err := cmdutil.SelectNodesWithFuzzyFinder(ctx, params.KubeClient)
				if err != nil {
					logger.Error(err, "failed to get nodes")
					return err
				}
				ms = append(ms, mutator.NewNodeAffinityMutator(nodes))
			}
			if err := params.Manager.Start(ctx, params.Name, params.Namespace, ms...); err != nil {
				logger.Error(err, "failed to start devbox")
				return err
			}
			return nil
		},
	}
}
