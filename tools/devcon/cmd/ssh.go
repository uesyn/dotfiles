package cmd

import (
	"github.com/spf13/cobra"
	"github.com/uesyn/dotfiles/tools/devcon/cmd/option"
	cmdutil "github.com/uesyn/dotfiles/tools/devcon/cmd/util"
)

func NewSSHCmd(f cmdutil.Factory) *cobra.Command {
	o := &option.SSHOptions{}
	cmd := &cobra.Command{
		Use:   "ssh",
		Short: "SSH devbox",
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
