package runtime

import (
	"errors"
	"os"
	"path/filepath"

	"github.com/bombsimon/logrusr/v4"
	"github.com/go-logr/logr"
	"github.com/sirupsen/logrus"
	"github.com/uesyn/devbox/common"
	"github.com/uesyn/devbox/config"
	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/uesyn/devbox/manager"
	"github.com/uesyn/devbox/release"
	"github.com/uesyn/devbox/template"
	"github.com/uesyn/devbox/util"
	"github.com/urfave/cli/v2"
	"k8s.io/client-go/kubernetes"
)

type Params struct {
	ConfigPath      string
	LogLevel        string
	Name            string
	Namespace       string
	AllNamespace    bool
	InitNamespace   string
	InitKubeConfig  string
	InitKubeContext string
	TemplateName    string
	SelectNodes     bool
	DeleteYes       bool
	Addresses       []string
	Ports           []string
	SSHCommand      []string
	SSHPort         int
	SSHUser         string
	SSHIdentityFile string
	Watch           bool
	Envs            map[string]string
	ExecCommand     []string

	Logger         logr.Logger
	ClientSet      kubernetes.Interface
	TemplateLoader template.Loader
	Manager        manager.Manager
}

func (p *Params) SetParams(cCtx *cli.Context) error {
	p.ConfigPath = util.ExpandPath(cCtx.String("config"))
	p.LogLevel = cCtx.String("loglevel")
	p.InitNamespace = cCtx.String("namespace")
	p.InitKubeConfig = cCtx.String("kubeconfig")
	p.InitKubeContext = cCtx.String("context")

	if cCtx.Command.Name == "init" {
		return nil
	}

	devboxKubeConfigPath := util.ExpandPath(common.DevboxKubeConfigPath)
	if _, err := os.Stat(devboxKubeConfigPath); err != nil {
		return errors.New("must run `devbox init`")
	}

	p.Name = cCtx.String("name")
	p.AllNamespace = cCtx.Bool("all")
	p.TemplateName = cCtx.String("template")
	p.SelectNodes = cCtx.Bool("select-nodes")
	p.DeleteYes = cCtx.Bool("yes")
	p.Addresses = cCtx.StringSlice("address")
	p.Ports = cCtx.StringSlice("port")
	p.SSHIdentityFile = util.ExpandPath(cCtx.String("ssh-identity-file"))
	p.Watch = cCtx.Bool("watch")

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

	templateDir := util.ExpandPath(filepath.Join(filepath.Dir(p.ConfigPath), "templates"))
	isLoadRestrictionsNone := conf.GetTemplateConfig().IsLoadRestrictionsNone()
	p.TemplateLoader = template.NewLoader(templateDir, isLoadRestrictionsNone)

	clientConfig := client.NewClientConfig(util.ExpandPath(devboxKubeConfigPath), "")
	namespace, _, err := clientConfig.Namespace()
	if err != nil {
		return err
	}
	p.Namespace = namespace
	restConfig, err := clientConfig.ClientConfig()
	if err != nil {
		return err
	}
	p.ClientSet = kubernetes.NewForConfigOrDie(restConfig)
	releaseStore := release.NewDefaultStore(p.ClientSet)
	p.Manager = manager.New(restConfig, releaseStore, p.TemplateLoader)

	envs, err := conf.GetEnvs()
	if err != nil {
		return err
	}
	p.Envs = envs
	p.ExecCommand = conf.GetExecConfig().GetCommand()
	p.SSHCommand = conf.GetSSHConfig().GetCommand()
	p.SSHPort = conf.GetSSHConfig().GetPort()
	p.SSHUser = conf.GetSSHConfig().GetUser()
	return nil
}
