package cmd

import (
	"github.com/spf13/cobra"
	"github.com/uesyn/dotfiles/tools/devk/cmd/option"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
)

func NewEventCmd(f cmdutil.Factory) *cobra.Command {
	o := &option.EventOptions{}
	cmd := &cobra.Command{
		Use:   "event",
		Short: "Event devk",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			if err := o.Complete(f); err != nil {
				return err
			}
			if err := o.Validate(); err != nil {
				return err
			}
			if err := o.Run(ctx); err != nil {
				return err
			}
			return nil
		},
	}
	o.AddFlags(cmd.Flags())
	return cmd
}
