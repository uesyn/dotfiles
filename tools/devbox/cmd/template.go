package cmd

import (
	"github.com/spf13/cobra"
	"github.com/uesyn/devbox/cmd/option"
	cmdutil "github.com/uesyn/devbox/cmd/util"
)

func newTemplateShowCmd(f cmdutil.Factory) *cobra.Command {
	o := &option.TemplateShowOptions{}
	cmd := &cobra.Command{
		Use:   "show",
		Short: "Show a template for devbox",
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

func newTemplateListCmd(f cmdutil.Factory) *cobra.Command {
	o := &option.TemplateListOptions{}
	cmd := &cobra.Command{
		Use:   "list",
		Short: "list templates for devbox",
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
	return cmd
}

func NewTemplateCmd(f cmdutil.Factory) *cobra.Command {
	cmd := &cobra.Command{
		Use: "template",
	}
	cmd.AddCommand(newTemplateShowCmd(f))
	cmd.AddCommand(newTemplateListCmd(f))
	return cmd
}
