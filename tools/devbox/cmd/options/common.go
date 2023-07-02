package options

import (
	"errors"

	"github.com/bombsimon/logrusr/v4"
	"github.com/go-logr/logr"
	"github.com/sirupsen/logrus"
	"github.com/spf13/pflag"
	"github.com/uesyn/devbox/config"
	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/uesyn/devbox/manager"
	"github.com/uesyn/devbox/release"
	"github.com/uesyn/devbox/template"
	"github.com/uesyn/devbox/util"
	"k8s.io/client-go/kubernetes"
	restclient "k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

type DevboxFlags struct {
	configPath           string
	templatesDirPath     string
	devboxKubeContext    string
	devboxKubeconfigPath string

	kubeConfig   clientcmd.ClientConfig
	devboxConfig config.Config
}

func (o *DevboxFlags) AddFlags(fs *pflag.FlagSet) {
	fs.StringVar(&o.configPath, "config", "${HOME}/.config/devbox/config.yaml", "path to devbox config file")
	fs.StringVar(&o.templatesDirPath, "templates-dir", "${HOME}/.config/devbox/templates", "path to devbox templates dir")
	fs.StringVar(&o.devboxKubeContext, "devbox-kubecontext", "", "context name to use in a given devbox-kubeconfig file")
	fs.StringVar(&o.devboxKubeconfigPath, "devbox-kubeconfig", "${HOME}/.local/share/devbox/kubeconfig", "path to devbox kubeconfig file")
}

func (o *DevboxFlags) Complete() error {
	o.templatesDirPath = util.ExpandPath(o.templatesDirPath)
	o.configPath = util.ExpandPath(o.configPath)
	o.devboxKubeconfigPath = util.ExpandPath(o.devboxKubeconfigPath)
	return nil
}

func (o *DevboxFlags) Validate() error {
	if len(o.configPath) == 0 {
		return errors.New("must set --config flag")
	}
	if len(o.templatesDirPath) == 0 {
		return errors.New("must set --templates-dir flag")
	}
	if len(o.devboxKubeconfigPath) == 0 {
		return errors.New("must set --devbox-kubeconfig flag")
	}
	return nil
}

func (o *DevboxFlags) KubeRawConfig() (clientcmdapi.Config, error) {
	if o.kubeConfig == nil {
		o.kubeConfig = client.NewClientConfig(o.devboxKubeconfigPath, o.devboxKubeContext)
	}
	return o.kubeConfig.RawConfig()
}

func (o *DevboxFlags) KubeRESTClientConfig() (*restclient.Config, error) {
	if o.kubeConfig == nil {
		o.kubeConfig = client.NewClientConfig(o.devboxKubeconfigPath, o.devboxKubeContext)
	}
	return o.kubeConfig.ClientConfig()
}

func (o *DevboxFlags) KubeClientSet() (kubernetes.Interface, error) {
	if o.kubeConfig == nil {
		o.kubeConfig = client.NewClientConfig(o.devboxKubeconfigPath, o.devboxKubeContext)
	}
	restConfig, err := o.kubeConfig.ClientConfig()
	if err != nil {
		return nil, err
	}

	clientset, err := kubernetes.NewForConfig(restConfig)
	if err != nil {
		return nil, err
	}
	return clientset, nil
}

func (o *DevboxFlags) Namespace() (string, bool, error) {
	if o.kubeConfig == nil {
		o.kubeConfig = client.NewClientConfig(o.devboxKubeconfigPath, o.devboxKubeContext)
	}
	return o.kubeConfig.Namespace()
}

func (o *DevboxFlags) DevboxConfig() (config.Config, error) {
	if o.devboxConfig == nil {
		devboxConfig, err := config.Load(o.configPath)
		if err != nil {
			return nil, err
		}
		o.devboxConfig = devboxConfig
	}
	return o.devboxConfig, nil
}

func (o *DevboxFlags) Manager() (manager.Manager, error) {
	if o.kubeConfig == nil {
		o.kubeConfig = client.NewClientConfig(o.devboxKubeconfigPath, o.devboxKubeContext)
	}

	if o.devboxConfig == nil {
		devboxConfig, err := config.Load(o.configPath)
		if err != nil {
			return nil, err
		}
		o.devboxConfig = devboxConfig
	}

	restConfig, err := o.kubeConfig.ClientConfig()
	if err != nil {
		return nil, err
	}

	clientset, err := kubernetes.NewForConfig(restConfig)
	if err != nil {
		return nil, err
	}
	releaseStore := release.NewDefaultStore(clientset)

	loader := template.NewLoader(
		o.templatesDirPath,
		o.devboxConfig.GetTemplateConfig().IsLoadRestrictionsNone(),
	)
	return manager.New(restConfig, releaseStore, loader), nil
}

func (o *DevboxFlags) TemplateLoader() (template.Loader, error) {
	if o.devboxConfig == nil {
		devboxConfig, err := config.Load(o.configPath)
		if err != nil {
			return nil, err
		}
		o.devboxConfig = devboxConfig
	}

	return template.NewLoader(
		o.templatesDirPath,
		o.devboxConfig.GetTemplateConfig().IsLoadRestrictionsNone(),
	), nil
}

type LogFlags struct {
	LogLevel string
}

func (o *LogFlags) Validate() error {
	_, err := logrus.ParseLevel(o.LogLevel)
	if err != nil {
		return err
	}
	return err
}

func (o *LogFlags) ToLogger() (logr.Logger, error) {
	level, err := logrus.ParseLevel(o.LogLevel)
	if err != nil {
		return logr.Discard(), err
	}
	logrusLog := logrus.New()
	logrusLog.SetLevel(level)
	return logrusr.New(logrusLog), nil
}

func (o *LogFlags) AddFlags(fs *pflag.FlagSet) {
	fs.StringVarP(&o.LogLevel, "loglevel", "l", "info", "log level")
}
