package cmd

import (
	"github.com/spf13/cobra"
	"github.com/uesyn/devbox/cmd/option"
)

func NewInitCmd() *cobra.Command {
	o := &option.InitOptions{}
	cmd := &cobra.Command{
		Use:   "init",
		Short: "Init devbox command",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			if err := o.Complete(); err != nil {
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
