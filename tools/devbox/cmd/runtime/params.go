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
	ConfigPath      string
	LogLevel        string
	Name            string
	Namespace       string
	AllNamespace    bool
	KubeConfig      string
	KubeContext     string
	TemplateName    string
	SelectNodes     bool
	DeleteYes       bool
	Addresses       []string
	Ports           []string
	SSHShell        string
	SSHPort         int
	SSHUser         string
	SSHIdentityFile string
	Envs            map[string]string
	ExecCommand     []string

	Logger         logr.Logger
	KubeClient     client.Client
	TemplateLoader template.Loader
	ReleaseStore   release.Store
	Manager        manager.Manager
}

func (p *Params) SetParams(cCtx *cli.Context) error {
	p.ConfigPath = util.ExpandPath(cCtx.String("config"))
	p.LogLevel = cCtx.String("loglevel")
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
	p.SSHIdentityFile = util.ExpandPath(cCtx.String("ssh-identity-file"))

	conf, err := config.Load(p.ConfigPath)
	if err != nil {
		return err
	}

	logLevel, err := logrus.ParseLevel(p.LogLevel)
	if err != nil {
		return err
	}
	logrusLog := logrus.New()
	logrusLog.SetLevel(logLevel)
	logger := logrusr.New(logrusLog).WithName("devbox")
	p.Logger = logger

	kubeClient, err := client.New(util.ExpandPath(p.KubeConfig), p.KubeContext)
	if err != nil {
		return err
	}
	p.KubeClient = kubeClient

	templateDir := util.ExpandPath(filepath.Join(filepath.Dir(p.ConfigPath), "templates"))
	isLoadRestrictionsNone := conf.GetTemplateConfig().IsLoadRestrictionsNone()
	p.TemplateLoader = template.NewLoader(templateDir, isLoadRestrictionsNone)

	p.ReleaseStore = release.NewDefaultStore(p.KubeClient)
	p.Manager = manager.New(p.KubeClient, p.ReleaseStore, p.TemplateLoader)
	envs, err := conf.GetEnvs()
	if err != nil {
		return err
	}
	p.Envs = envs
	p.ExecCommand = conf.GetExecConfig().GetCommand()

	p.SSHShell = conf.GetSSHConfig().GetShell()
	p.SSHPort = conf.GetSSHConfig().GetPort()
	p.SSHUser = conf.GetSSHConfig().GetUser()
	return nil
}
