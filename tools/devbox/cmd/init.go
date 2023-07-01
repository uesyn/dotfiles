package cmd

import (
	"errors"
	"fmt"

	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/uesyn/devbox/common"
	"github.com/uesyn/devbox/initialize"
	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/urfave/cli/v2"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

func newInitCommand() *cli.Command {
	return &cli.Command{
		Name:  "init",
		Usage: "initialize devbox configs",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "namespace",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "kubernetes namespace where devbox run",
				EnvVars: []string{"DEVBOX_NAMESPACE"},
			},
			&cli.StringFlag{
				Name:    "context",
				Usage:   "the name of the kubeconfig context to use",
				EnvVars: []string{"DEVBOX_CONTEXT"},
			},
			&cli.StringFlag{
				Name:    "kubeconfig",
				Usage:   "path to kubeconfig file",
				Value:   "${HOME}/.kube/config",
				EnvVars: []string{"DEVBOX_KUBECONFIG", "KUBECONFIG"},
			},
		},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}

			config, err := initialize.GenerateDevboxKubeconfig(params.InitKubeConfig, params.InitKubeContext, params.InitNamespace)
			if err != nil {
				logger.Error(err, "Failed to generate kubeconfig for devbox")
				return err
			}

			curContext, err := getCurrentContext(config)
			if err != nil {
				logger.Error(err, "Failed to get context for devbox")
				return err
			}
			cluster, namespace := getCluster(curContext), getNamespace(curContext)

			if err := client.WriteKubeconfig(*config, common.DevboxKubeConfigPath); err != nil {
				logger.Error(err, "Failed to write kubeconfig for devbox")
				return err
			}

			logger.Info(fmt.Sprintf("generated kubeconfig at %s for devbox", common.DevboxKubeConfigPath),
				"context", config.CurrentContext, "cluster", cluster, "namespace", namespace)
			return nil
		},
	}
}

func getCurrentContext(config *clientcmdapi.Config) (*clientcmdapi.Context, error) {
	context, found := config.Contexts[config.CurrentContext]
	if !found {
		return nil, errors.New("context not found")
	}
	return context, nil
}

func getCluster(context *clientcmdapi.Context) string {
	return context.Cluster
}

func getNamespace(context *clientcmdapi.Context) string {
	namespace := context.Namespace
	if len(namespace) == 0 {
		namespace = metav1.NamespaceDefault
	}
	return namespace
}
