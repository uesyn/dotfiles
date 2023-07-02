package cmd

import (
	"github.com/spf13/cobra"
	"github.com/uesyn/devbox/cmd/option"
	cmdutil "github.com/uesyn/devbox/cmd/util"
)

func NewRestartCmd(f cmdutil.Factory) *cobra.Command {
	o := &option.RestartOptions{}
	cmd := &cobra.Command{
		Use:   "restart",
		Short: "Restart devbox",
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
