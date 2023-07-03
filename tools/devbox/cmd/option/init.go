package option

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	"github.com/uesyn/devbox/common"
	"github.com/uesyn/devbox/initialize"
	"github.com/uesyn/devbox/kubernetes/client"
	"github.com/uesyn/devbox/util"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

type InitOptions struct {
	Namespace   string
	KubeContext string
	KubeConfig  string
	Recreate    bool
}

func (o *InitOptions) AddFlags(fs *pflag.FlagSet) {
	fs.StringVar(&o.Namespace, "namespace", metav1.NamespaceDefault, "Kubernetes namespace where devbox run")
	fs.StringVar(&o.KubeContext, "context", "", "Name of the kubeconfig context to use")
	fs.StringVar(&o.KubeConfig, "kubeconfig", "${HOME}/.kube/config", "Path to kubeconfig file")
	fs.BoolVarP(&o.Recreate, "recreate", "r", false, "Recreate devbox kubeconfig")
}

func (o *InitOptions) Complete() error {
	o.KubeConfig = util.ExpandPath(o.KubeConfig)
	return nil
}

func (o *InitOptions) Validate() error {
	if len(o.Namespace) == 0 {
		return errors.New("must set --namespace flag")
	}
	if len(o.KubeConfig) == 0 {
		return errors.New("must set --kubeconfig flag")
	}
	return nil
}

func (o *InitOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx)

	devboxKubeConfigPath := util.ExpandPath(common.DevboxKubeConfigPath)
	if _, err := os.Stat(devboxKubeConfigPath); err == nil && !o.Recreate {
		logger.Info("already initialized")
		return nil
	}

	config, err := initialize.GenerateDevboxKubeconfig(o.KubeConfig, o.KubeContext, o.Namespace)
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

	if err := client.WriteKubeconfig(*config, devboxKubeConfigPath); err != nil {
		logger.Error(err, "Failed to write kubeconfig for devbox")
		return err
	}

	logger.Info(fmt.Sprintf("Generated kubeconfig at %s for devbox", devboxKubeConfigPath),
		"context", config.CurrentContext, "cluster", cluster, "namespace", namespace)
	return nil
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
