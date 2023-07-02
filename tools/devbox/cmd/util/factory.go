package util

import (
	"github.com/uesyn/devbox/config"
	"github.com/uesyn/devbox/manager"
	"github.com/uesyn/devbox/template"
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
