package client

import (
	"context"
	"net/http"

	corev1 "k8s.io/api/core/v1"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/portforward"
	"k8s.io/client-go/transport/spdy"
)

type PortForwardClient struct {
	restConfig *rest.Config
}

func NewPortForwardClient(restConfig *rest.Config) *PortForwardClient {
	return &PortForwardClient{restConfig: restConfig}
}

type PortForwardOptions struct {
	Addresses []string
	Ports     []string
}

func (c *PortForwardClient) PortForward(ctx context.Context, pod *corev1.Pod, opts PortForwardOptions) error {
	roundTripper, upgrader, err := spdy.RoundTripperFor(c.restConfig)
	if err != nil {
		return err
	}

	clientset := kubernetes.NewForConfigOrDie(c.restConfig)
	url := clientset.CoreV1().RESTClient().Post().Resource("pods").Name(pod.GetName()).Namespace(pod.GetNamespace()).SubResource("portforward").URL()

	dialer := spdy.NewDialer(upgrader, &http.Client{Transport: roundTripper}, http.MethodPost, url)

	forwarder, err := portforward.NewOnAddresses(
		dialer,
		opts.Addresses,
		opts.Ports,
		make(chan struct{}, 1),
		make(chan struct{}, 1),
		nil,
		nil,
	)
	if err != nil {
		return err
	}
	utilruntime.ErrorHandlers = []func(error){} // suppress error log
	defer forwarder.Close()
	return forwarder.ForwardPorts()
}
