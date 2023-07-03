package option

import (
	"errors"
	"os"

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

const defaultDevboxConfigPath = "${HOME}/.config/devbox/config.yaml"

func (o *DevboxFlags) AddFlags(fs *pflag.FlagSet) {
	devboxConfigPath := defaultDevboxConfigPath
	if v := os.Getenv("DEVBOX_CONFIG"); len(v) > 0 {
		devboxConfigPath = v
	}
	fs.StringVar(&o.configPath, "config", devboxConfigPath, "Path to devbox config file, available to overwrite with DEVBOX_CONFIG env")
	fs.StringVar(&o.templatesDirPath, "templates-dir", "${HOME}/.config/devbox/templates", "Path to devbox templates dir")
	fs.StringVar(&o.devboxKubeContext, "devbox-kubecontext", "", "Context name to use in a given devbox-kubeconfig file")
	fs.StringVar(&o.devboxKubeconfigPath, "devbox-kubeconfig", "${HOME}/.local/share/devbox/kubeconfig", "Path to devbox kubeconfig file")
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

func (o *DevboxFlags) setKubeConfig() error {
	if o.kubeConfig != nil {
		return nil
	}

	if _, err := os.Stat(o.devboxKubeconfigPath); err != nil {
		return errors.New("must run `devbox init` before")
	}
	o.kubeConfig = client.NewClientConfig(o.devboxKubeconfigPath, o.devboxKubeContext)
	return nil
}

func (o *DevboxFlags) setDevboxConfig() error {
	if o.devboxConfig != nil {
		return nil
	}

	devboxConfig, err := config.Load(o.configPath)
	if err != nil {
		return err
	}
	o.devboxConfig = devboxConfig
	return nil
}

func (o *DevboxFlags) KubeRawConfig() (clientcmdapi.Config, error) {
	if err := o.setKubeConfig(); err != nil {
		return clientcmdapi.Config{}, err
	}
	return o.kubeConfig.RawConfig()
}

func (o *DevboxFlags) KubeRESTClientConfig() (*restclient.Config, error) {
	if err := o.setKubeConfig(); err != nil {
		return nil, err
	}
	return o.kubeConfig.ClientConfig()
}

func (o *DevboxFlags) KubeClientSet() (kubernetes.Interface, error) {
	if err := o.setKubeConfig(); err != nil {
		return nil, err
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
	if err := o.setKubeConfig(); err != nil {
		return "", false, err
	}
	return o.kubeConfig.Namespace()
}

func (o *DevboxFlags) DevboxConfig() (config.Config, error) {
	if err := o.setDevboxConfig(); err != nil {
		return nil, err
	}
	return o.devboxConfig, nil
}

func (o *DevboxFlags) Manager() (manager.Manager, error) {
	if err := o.setKubeConfig(); err != nil {
		return nil, err
	}

	if err := o.setDevboxConfig(); err != nil {
		return nil, err
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
	if err := o.setDevboxConfig(); err != nil {
		return nil, err
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
