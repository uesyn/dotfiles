package cmd

import (
	"fmt"
	"os"

	"github.com/go-logr/logr"
	"github.com/manifoldco/promptui"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
)

func newDeleteCommand() *cli.Command {
	return &cli.Command{
		Name:  "delete",
		Usage: "Delete devbox",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "name",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "devbox name",
			},
			&cli.BoolFlag{
				Name:  "yes",
				Value: false,
				Usage: "if present, delete devbox resources without any confirmation",
			},
		},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}
			if !params.DeleteYes {
				if ok := deleteConfirmationPrompt(params.Name); !ok {
					os.Exit(1)
				}
			}
			return params.Manager.Delete(cCtx.Context, params.Name, params.Namespace)
		},
	}
}

func deleteConfirmationPrompt(devboxName string) bool {
	prompt := promptui.Prompt{
		Label: fmt.Sprintf("Please type '%s' to confirm.", devboxName),
		Validate: func(input string) error {
			if input != devboxName {
				return fmt.Errorf("invalid input")
			}
			return nil
		},
	}

	if _, err := prompt.Run(); err != nil {
		return false
	}
	return true
}
