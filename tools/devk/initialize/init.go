package initialize

import (
	"errors"

	"github.com/uesyn/dotfiles/tools/devk/kubernetes/client"
	"github.com/uesyn/dotfiles/tools/devk/util"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

func GenerateDevkKubeconfig(kubeConfigPath, useContextName, namespace string) (*clientcmdapi.Config, error) {
	clientConfig := client.NewClientConfig(util.ExpandPath(kubeConfigPath), useContextName)
	kubeRawConfig, err := clientConfig.RawConfig()
	if err != nil {
		return nil, err
	}
	if len(useContextName) == 0 {
		useContextName = kubeRawConfig.CurrentContext
	}
	devkRawConfig := kubeRawConfig.DeepCopy()

	kubeContext, found := devkRawConfig.Contexts[useContextName]
	if !found {
		return nil, errors.New("context not found")
	}
	kubeContext.Namespace = namespace
	devkRawConfig.CurrentContext = useContextName
	devkRawConfig.Contexts = map[string]*clientcmdapi.Context{useContextName: kubeContext}

	cluster, found := devkRawConfig.Clusters[kubeContext.Cluster]
	if !found {
		return nil, errors.New("cluster not found")
	}
	devkRawConfig.Clusters = map[string]*clientcmdapi.Cluster{kubeContext.Cluster: cluster}

	authInfo, found := devkRawConfig.AuthInfos[kubeContext.AuthInfo]
	if !found {
		return nil, errors.New("authinfo not found")
	}
	devkRawConfig.AuthInfos = map[string]*clientcmdapi.AuthInfo{kubeContext.AuthInfo: authInfo}
	return devkRawConfig, nil
}
