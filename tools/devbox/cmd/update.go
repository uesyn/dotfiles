package cmd

import (
	"github.com/spf13/cobra"
	"github.com/uesyn/devbox/cmd/option"
	cmdutil "github.com/uesyn/devbox/cmd/util"
)

func NewUpdateCmd(f cmdutil.Factory) *cobra.Command {
	o := &option.UpdateOptions{}
	cmd := &cobra.Command{
		Use:   "update",
		Short: "Update devbox",
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
