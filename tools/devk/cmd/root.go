package cmd

import (
	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"github.com/uesyn/dotfiles/tools/devk/cmd/option"
)

func NewRootCmd() *cobra.Command {
	devkFlags := &option.DevkFlags{}
	logFlags := &option.LogFlags{}

	cmd := &cobra.Command{
		Use:       "devk",
		Short:     "CLI to manage devkes",
		ValidArgs: []string{},
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			if err := devkFlags.Complete(); err != nil {
				return err
			}
			if err := devkFlags.Validate(); err != nil {
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

	devkFlags.AddFlags(cmd.PersistentFlags())
	logFlags.AddFlags(cmd.PersistentFlags())

	cmd.AddCommand(NewInitCmd())
	cmd.AddCommand(NewRunCmd(devkFlags))
	cmd.AddCommand(NewDeleteCmd(devkFlags))
	cmd.AddCommand(NewStartCmd(devkFlags))
	cmd.AddCommand(NewStopCmd(devkFlags))
	cmd.AddCommand(NewProtectCmd(devkFlags))
	cmd.AddCommand(NewUnprotectCmd(devkFlags))
	cmd.AddCommand(NewListCmd(devkFlags))
	cmd.AddCommand(NewExecCmd(devkFlags))
	cmd.AddCommand(NewEventCmd(devkFlags))
	cmd.AddCommand(NewUpdateCmd(devkFlags))
	cmd.AddCommand(NewRestartCmd(devkFlags))

	return cmd
}
