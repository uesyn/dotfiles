package option

import (
	"errors"
	"os"

	"github.com/bombsimon/logrusr/v4"
	"github.com/go-logr/logr"
	"github.com/sirupsen/logrus"
	"github.com/spf13/pflag"
	"github.com/uesyn/dotfiles/tools/devk/config"
	"github.com/uesyn/dotfiles/tools/devk/kubernetes/client"
	"github.com/uesyn/dotfiles/tools/devk/manager"
	"github.com/uesyn/dotfiles/tools/devk/release"
	"github.com/uesyn/dotfiles/tools/devk/template"
	"github.com/uesyn/dotfiles/tools/devk/util"
	"k8s.io/client-go/kubernetes"
	restclient "k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

type DevkFlags struct {
	configPath         string
	templatesDirPath   string
	devkKubeContext    string
	devkKubeconfigPath string

	kubeConfig clientcmd.ClientConfig
	devkConfig *config.Config
}

const defaultDevkConfigPath = "${HOME}/.config/devk/config.yaml"
const defaultDevkTemplatesDirPath = "${HOME}/.config/devk/templates"

func (o *DevkFlags) AddFlags(fs *pflag.FlagSet) {
	devkConfigPath := defaultDevkConfigPath
	if v := os.Getenv("DEVK_CONFIG"); len(v) > 0 {
		devkConfigPath = v
	}
	devkTemplatesDirPath := defaultDevkTemplatesDirPath
	if v := os.Getenv("DEVK_TEMPLATES"); len(v) > 0 {
		devkTemplatesDirPath = v
	}
	fs.StringVar(&o.configPath, "config", devkConfigPath, "Path to devk config file, available to overwrite with DEVK_CONFIG env")
	fs.StringVar(&o.templatesDirPath, "templates-dir", devkTemplatesDirPath, "Path to devk templates dir, available to overwrite with DEVK_TEMPLATES env")
	fs.StringVar(&o.devkKubeContext, "devk-kubecontext", "", "Context name to use in a given devk-kubeconfig file")
	fs.StringVar(&o.devkKubeconfigPath, "devk-kubeconfig", "${HOME}/.local/share/devk/kubeconfig", "Path to devk kubeconfig file")
}

func (o *DevkFlags) Complete() error {
	o.templatesDirPath = util.ExpandPath(o.templatesDirPath)
	o.configPath = util.ExpandPath(o.configPath)
	o.devkKubeconfigPath = util.ExpandPath(o.devkKubeconfigPath)
	return nil
}

func (o *DevkFlags) Validate() error {
	if len(o.configPath) == 0 {
		return errors.New("must set --config flag")
	}
	if len(o.templatesDirPath) == 0 {
		return errors.New("must set --templates-dir flag")
	}
	if len(o.devkKubeconfigPath) == 0 {
		return errors.New("must set --devk-kubeconfig flag")
	}
	return nil
}

func (o *DevkFlags) setKubeConfig() error {
	if o.kubeConfig != nil {
		return nil
	}

	if _, err := os.Stat(o.devkKubeconfigPath); err != nil {
		return errors.New("must run `devk init` before")
	}
	o.kubeConfig = client.NewClientConfig(o.devkKubeconfigPath, o.devkKubeContext)
	return nil
}

func (o *DevkFlags) setDevkConfig() error {
	if o.devkConfig != nil {
		return nil
	}

	devkConfig, err := config.Load(o.configPath)
	if err != nil {
		return err
	}
	o.devkConfig = devkConfig
	return nil
}

func (o *DevkFlags) KubeRawConfig() (clientcmdapi.Config, error) {
	if err := o.setKubeConfig(); err != nil {
		return clientcmdapi.Config{}, err
	}
	return o.kubeConfig.RawConfig()
}

func (o *DevkFlags) KubeRESTClientConfig() (*restclient.Config, error) {
	if err := o.setKubeConfig(); err != nil {
		return nil, err
	}
	return o.kubeConfig.ClientConfig()
}

func (o *DevkFlags) KubeClientSet() (kubernetes.Interface, error) {
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

func (o *DevkFlags) Namespace() (string, bool, error) {
	if err := o.setKubeConfig(); err != nil {
		return "", false, err
	}
	return o.kubeConfig.Namespace()
}

func (o *DevkFlags) DevkConfig() (*config.Config, error) {
	if err := o.setDevkConfig(); err != nil {
		return nil, err
	}
	return o.devkConfig, nil
}

func (o *DevkFlags) Manager() (manager.Manager, error) {
	if err := o.setKubeConfig(); err != nil {
		return nil, err
	}

	if err := o.setDevkConfig(); err != nil {
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

	loader, err := o.TemplateLoader()
	if err != nil {
		return nil, err
	}
	return manager.New(restConfig, releaseStore, loader), nil
}

func (o *DevkFlags) TemplateLoader() (template.Loader, error) {
	if err := o.setDevkConfig(); err != nil {
		return nil, err
	}

	return template.NewLoader(
		o.templatesDirPath,
		o.devkConfig.Template.LoadRestrictionsNone,
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
