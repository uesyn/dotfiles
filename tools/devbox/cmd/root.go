package cmd

import (
	"github.com/bombsimon/logrusr/v4"
	"github.com/go-logr/logr"
	"github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
)

func NewRootApp() *cli.App {
	return &cli.App{
		Name:  "devbox",
		Usage: "CLI to manage devboxes",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "config",
				Usage:   "path of devbox config",
				Value:   "${HOME}/.config/devbox/config.yaml",
				Aliases: []string{"c"},
				EnvVars: []string{"DEVBOX_CONFIG"},
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
			&cli.StringFlag{
				Name:    "loglevel",
				Usage:   "log level",
				Value:   "info",
				EnvVars: []string{"DEVBOX_LOGLEVEL"},
			},
		},
		Before: func(cCtx *cli.Context) error {
			level, err := logrus.ParseLevel(cCtx.String("loglevel"))
			if err != nil {
				logrus.Errorf("failed to parse log level: %v", err)
				return err
			}
			logrusLog := logrus.New()
			logrusLog.SetLevel(level)
			logger := logrusr.New(logrusLog).WithName("devbox")
			cCtx.Context = logr.NewContext(cCtx.Context, logger)
			return nil
		},
		Commands: []*cli.Command{
			newRunCommand(),
			newDeleteCommand(),
			newStartCommand(),
			newStopCommand(),
			newExecCommand(),
			newListCommand(),
			newProtectCommand(),
			newUnprotectCommand(),
			newUpdateCommand(),
			newTemplateCommand(),
			newEventCommand(),
		},
	}
}
