package option

import (
	"bytes"
	"context"
	"errors"
	"fmt"

	"github.com/fatih/color"
	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/dotfiles/tools/devk/cmd/util"
	"github.com/uesyn/dotfiles/tools/devk/template"
	"sigs.k8s.io/kustomize/kyaml/yaml"
)

type TemplateShowOptions struct {
	name string

	loader template.Loader
}

func (o *TemplateShowOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.name, "name", "n", "", "Template name")
}

func (o *TemplateShowOptions) Complete(f cmdutil.Factory) error {
	loader, err := f.TemplateLoader()
	if err != nil {
		return err
	}
	o.loader = loader
	return nil
}

func (o *TemplateShowOptions) Validate() error {
	if len(o.name) == 0 {
		return errors.New("must set --name flag")
	}

	if o.loader == nil {
		return errors.New("must set template loader")
	}
	return nil
}

func (o *TemplateShowOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("templateName", o.name)

	manifests, err := o.loader.Load(o.name, "NAME", "NAMESPACE")
	if err != nil {
		logger.Error(err, "failed to load template")
		return err
	}

	var output [][]byte
	for _, manifest := range manifests.ToObjects() {
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
	fmt.Println(string(bytes.Join(output, []byte("---\n"))))
	return nil
}

type TemplateListOptions struct {
	loader template.Loader
}

func (o *TemplateListOptions) Complete(f cmdutil.Factory) error {
	loader, err := f.TemplateLoader()
	if err != nil {
		return err
	}
	o.loader = loader
	return nil
}

func (o *TemplateListOptions) Validate() error {
	if o.loader == nil {
		return errors.New("must set template loader")
	}
	return nil
}

func (o *TemplateListOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx)

	templates, err := o.loader.ListTemplates()
	if err != nil {
		logger.Error(err, "failed to list templates")
		return err
	}
	for _, t := range templates {
		fmt.Println(t)
	}
	return nil
}
