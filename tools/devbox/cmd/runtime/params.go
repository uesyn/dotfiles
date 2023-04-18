package runtime

import (
	"path/filepath"

	"github.com/bombsimon/logrusr/v4"
	"github.com/go-logr/logr"
	"github.com/sirupsen/logrus"
	"github.com/uesyn/devbox/config"
	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/uesyn/devbox/manager"
	"github.com/uesyn/devbox/release"
	"github.com/uesyn/devbox/template"
	"github.com/uesyn/devbox/util"
	"github.com/urfave/cli/v2"
)

type Params struct {
	// Flag Values
	LogLevel     string
	ConfigPath   string
	Name         string
	Namespace    string
	AllNamespace bool
	KubeConfig   string
	KubeContext  string
	TemplateName string
	SelectNodes  bool
	DeleteYes    bool
	Addresses    []string
	Ports        []string

	Logger         logr.Logger
	KubeClient     client.Client
	Config         config.Config
	TemplateLoader template.Loader
	ReleaseStore   release.Store
	Manager        manager.Manager
}

func (p *Params) SetParams(cCtx *cli.Context) error {
	p.LogLevel = cCtx.String("loglevel")
	p.ConfigPath = cCtx.String("config")
	p.Name = cCtx.String("name")
	p.Namespace = cCtx.String("namespace")
	p.AllNamespace = cCtx.Bool("all")
	p.KubeConfig = cCtx.String("kubeconfig")
	p.KubeContext = cCtx.String("context")
	p.TemplateName = cCtx.String("template")
	p.SelectNodes = cCtx.Bool("select-nodes")
	p.DeleteYes = cCtx.Bool("yes")
	p.Addresses = cCtx.StringSlice("address")
	p.Ports = cCtx.StringSlice("port")
	{
		level, err := logrus.ParseLevel(cCtx.String("loglevel"))
		if err != nil {
			return err
		}
		logrusLog := logrus.New()
		logrusLog.SetLevel(level)
		logger := logrusr.New(logrusLog).WithName("devbox")
		p.Logger = logger
	}
	{
		c, err := config.Load(util.ExpandPath(p.ConfigPath))
		if err != nil {
			return err
		}
		p.Config = c
	}
	{
		c, err := client.New(util.ExpandPath(p.KubeConfig), p.KubeContext)
		if err != nil {
			return err
		}
		p.KubeClient = c
	}
	{
		templateDir := util.ExpandPath(filepath.Join(filepath.Dir(p.ConfigPath), "templates"))
		isLoadRestrictionsNone := p.Config.GetTemplateConfig().IsLoadRestrictionsNone()
		p.TemplateLoader = template.NewLoader(templateDir, isLoadRestrictionsNone)
	}
	p.ReleaseStore = release.NewDefaultStore(p.KubeClient)
	p.Manager = manager.New(p.KubeClient, p.ReleaseStore, p.TemplateLoader)
	return nil
}
