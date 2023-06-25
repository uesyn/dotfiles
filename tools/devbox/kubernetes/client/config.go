package client

import (
	"path/filepath"

	_ "k8s.io/client-go/plugin/pkg/client/auth"
	restclient "k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func NewRESTConfig(configPath string, contextName string) (*restclient.Config, error) {
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
	).ClientConfig()
}
