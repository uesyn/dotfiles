package util

import (
	"github.com/uesyn/dotfiles/tools/devcon/config"
	"github.com/uesyn/dotfiles/tools/devcon/manager"
	"github.com/uesyn/dotfiles/tools/devcon/template"
	"k8s.io/client-go/kubernetes"
	restclient "k8s.io/client-go/rest"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

type Factory interface {
	KubeRawConfig() (clientcmdapi.Config, error)
	KubeRESTClientConfig() (*restclient.Config, error)
	KubeClientSet() (kubernetes.Interface, error)
	Namespace() (string, bool, error)
	DevboxConfig() (config.Config, error)
	Manager() (manager.Manager, error)
	TemplateLoader() (template.Loader, error)
}
