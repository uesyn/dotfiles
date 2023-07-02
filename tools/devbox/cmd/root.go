package cmd

import (
	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/uesyn/devbox/cmd/option"
)

func NewRootCmd() *cobra.Command {
	devboxFlags := &option.DevboxFlags{}
	logFlags := &option.LogFlags{}

	cmd := &cobra.Command{
		Use:       "devbox",
		Short:     "CLI to manage devboxes",
		ValidArgs: []string{},
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			if err := devboxFlags.Complete(); err != nil {
				return err
			}
			if err := devboxFlags.Validate(); err != nil {
				return err
			}
			if err := logFlags.Validate(); err != nil {
				return err
			}
			logger, err := logFlags.ToLogger()
			if err != nil {
				return err
			}
			ctx := logr.NewContext(cmd.Context(), logger)
			cmd.SetContext(ctx)
			return nil
		},
		SilenceErrors: false,
		SilenceUsage:  false,
	}

	devboxFlags.AddFlags(cmd.PersistentFlags())
	logFlags.AddFlags(cmd.PersistentFlags())

	cmd.AddCommand(NewInitCmd())
	cmd.AddCommand(NewRunCmd(devboxFlags))
	cmd.AddCommand(NewDeleteCmd(devboxFlags))
	cmd.AddCommand(NewStartCmd(devboxFlags))
	cmd.AddCommand(NewStopCmd(devboxFlags))
	cmd.AddCommand(NewProtectCmd(devboxFlags))
	cmd.AddCommand(NewUnprotectCmd(devboxFlags))
	cmd.AddCommand(NewListCmd(devboxFlags))
	cmd.AddCommand(NewExecCmd(devboxFlags))
	cmd.AddCommand(NewEventCmd(devboxFlags))
	cmd.AddCommand(NewSSHCmd(devboxFlags))
	cmd.AddCommand(NewTemplateCmd(devboxFlags))
	cmd.AddCommand(NewUpdateCmd(devboxFlags))
	cmd.AddCommand(NewRestartCmd(devboxFlags))

	return cmd
}
