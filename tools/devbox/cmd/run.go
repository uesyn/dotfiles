package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/mutator"
	"github.com/urfave/cli/v2"
)

func newRunCommand() *cli.Command {
	return &cli.Command{
		Name:  "run",
		Usage: "Run devbox",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "name",
				Value: "default",
				Usage: "devbox name",
			},
			&cli.StringFlag{
				Name:    "template",
				Aliases: []string{"t"},
				Value:   "default",
				Usage:   "template name",
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

			var ms []mutator.PodMutator
			if params.SelectNodes {
				nodes, err := cmdutil.SelectNodesWithFuzzyFinder(cCtx.Context, params.ClientSet)
				if err != nil {
					logger.Error(err, "failed to get nodes")
					return err
				}
				ms = append(ms, mutator.NewNodeAffinityMutator(nodes))
			}
			return params.Manager.Run(cCtx.Context, params.TemplateName, params.Name, params.Namespace, ms...)
		},
	}
}
