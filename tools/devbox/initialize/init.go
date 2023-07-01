package initialize

import (
	"errors"

	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/uesyn/devbox/util"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

func GenerateDevboxKubeconfig(kubeConfigPath, useContextName, namespace string) (*clientcmdapi.Config, error) {
	clientConfig := client.NewClientConfig(util.ExpandPath(kubeConfigPath), useContextName)
	kubeRawConfig, err := clientConfig.RawConfig()
	if err != nil {
		return nil, err
	}
	if len(useContextName) == 0 {
		useContextName = kubeRawConfig.CurrentContext
	}
	devboxRawConfig := kubeRawConfig.DeepCopy()

	kubeContext, found := devboxRawConfig.Contexts[useContextName]
	if !found {
		return nil, errors.New("context not found")
	}
	kubeContext.Namespace = namespace
	devboxRawConfig.CurrentContext = useContextName
	devboxRawConfig.Contexts = map[string]*clientcmdapi.Context{useContextName: kubeContext}

	cluster, found := devboxRawConfig.Clusters[kubeContext.Cluster]
	if !found {
		return nil, errors.New("cluster not found")
	}
	devboxRawConfig.Clusters = map[string]*clientcmdapi.Cluster{kubeContext.Cluster: cluster}

	authInfo, found := devboxRawConfig.AuthInfos[kubeContext.AuthInfo]
	if !found {
		return nil, errors.New("authinfo not found")
	}
	devboxRawConfig.AuthInfos = map[string]*clientcmdapi.AuthInfo{kubeContext.AuthInfo: authInfo}
	return devboxRawConfig, nil
}
