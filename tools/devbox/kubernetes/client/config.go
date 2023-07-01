package client

import (
	"path/filepath"

	"github.com/uesyn/devbox/util"
	_ "k8s.io/client-go/plugin/pkg/client/auth"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

func NewClientConfig(configPath string, contextName string) clientcmd.ClientConfig {
	rules := clientcmd.NewDefaultClientConfigLoadingRules()
	if configPath != "" {
		configPathList := filepath.SplitList(configPath)
		if len(configPathList) <= 1 {
			rules.ExplicitPath = configPath
		} else {
			rules.Precedence = configPathList
		}
	}
	return clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		rules,
		&clientcmd.ConfigOverrides{
			CurrentContext: contextName,
		},
	)
}

func WriteKubeconfig(config clientcmdapi.Config, filename string) error {
	return clientcmd.WriteToFile(config, util.ExpandPath(filename))
}
