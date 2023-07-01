package cmd

import (
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
)

func newProtectCommand() *cli.Command {
	return &cli.Command{
		Name:  "protect",
		Usage: "Protect devbox",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "name",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "devbox name",
			},
		},
		Action: func(cCtx *cli.Context) error {
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logr.FromContextOrDiscard(cCtx.Context).Error(err, "failed to set params")
				return err
			}
			return params.Manager.Protect(cCtx.Context, params.Name, params.Namespace)
		},
	}
}
