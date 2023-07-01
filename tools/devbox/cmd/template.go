package cmd

import (
	"bytes"
	"fmt"

	"github.com/fatih/color"
	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"sigs.k8s.io/kustomize/kyaml/yaml"
)

func newTemplateCommand() *cli.Command {
	return &cli.Command{
		Name:    "template",
		Usage:   "Utility for devbox templates",
		Aliases: []string{"t"},
		Subcommands: []*cli.Command{
			newTemplateListCommand(),
			newTemplateShowCommand(),
		},
	}
}

func newTemplateListCommand() *cli.Command {
	return &cli.Command{
		Name:    "list",
		Usage:   "List devbox templates",
		Aliases: []string{"ls"},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}
			logger = logger.WithValues("devboxName", params.Name)

			templates, err := params.TemplateLoader.ListTemplates()
			if err != nil {
				logger.Error(err, "failed to list templates")
				return err
			}
			for _, t := range templates {
				fmt.Println(t)
			}
			return nil
		},
	}
}

func newTemplateShowCommand() *cli.Command {
	return &cli.Command{
		Name:  "show",
		Usage: "Show devbox templates",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "template",
				Aliases: []string{"t"},
				Value:   "default",
				Usage:   "template name",
			},
		},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}
			logger = logger.WithValues("devboxName", params.Name)

			tmpl, err := params.TemplateLoader.Load(params.TemplateName, "NAME", "NAMESPACE")
			if err != nil {
				logger.Error(err, "failed to load template")
				return err
			}

			var objs []*unstructured.Unstructured
			objs = append(objs, tmpl.GetDevbox())
			objs = append(objs, tmpl.GetDependencies()...)

			var output [][]byte
			for _, manifest := range objs {
				contents, err := yaml.MarshalWithOptions(manifest.Object, &yaml.EncoderOptions{
					SeqIndent: yaml.CompactSequenceStyle,
				})
				if err != nil {
					logger.Error(err, "failed to marshal template to yaml")
					return err
				}
				output = append(output, contents)
			}
			c := color.New(color.FgRed)
			c.Add(color.Bold)
			c.Add(color.Italic)
			fmt.Printf("[%s]\n", c.Sprint(params.TemplateName))
			fmt.Println(string(bytes.Join(output, []byte("---\n"))))
			return nil
		},
	}
}
