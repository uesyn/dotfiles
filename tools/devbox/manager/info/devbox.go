package info

import (
	"context"

	"github.com/uesyn/devbox/kubernetes/client"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	ctrlclient "sigs.k8s.io/controller-runtime/pkg/client"
)

var _ DevboxInfoAccessor = (*devboxInfoAccessor)(nil)

type devboxInfoAccessor struct {
	client       client.Client
	devboxName   string
	podName      string
	namespace    string
	templateName string
	protected    bool
}

func NewDevboxInfoAccessor(c client.Client, devboxName, podName, namespace, templateName string, protected bool) DevboxInfoAccessor {
	return &devboxInfoAccessor{
		client:       c,
		devboxName:   devboxName,
		podName:      podName,
		namespace:    namespace,
		templateName: templateName,
		protected:    protected,
	}
}

func (a *devboxInfoAccessor) GetDevboxName() string {
	return a.devboxName
}

func (a *devboxInfoAccessor) GetNamespace() string {
	return a.namespace
}

func (a *devboxInfoAccessor) GetTemplateName() string {
	return a.templateName
}

func (a *devboxInfoAccessor) Protected() bool {
	return a.protected
}

func (a *devboxInfoAccessor) GetPhase(ctx context.Context) (DevboxPhase, error) {
	objKey := ctrlclient.ObjectKey{
		Namespace: a.namespace,
		Name:      a.podName,
	}
	pod := corev1.Pod{}
	err := a.client.Get(ctx, objKey, &pod)
	if apierrors.IsNotFound(err) {
		return DevboxStopped, nil
	} else if err != nil {
		return "", err
	}
	if !pod.GetDeletionTimestamp().IsZero() {
		return DevboxTerminating, nil
	}
	return podPhaseToDevboxPhase(pod.Status.Phase), nil
}

func podPhaseToDevboxPhase(phase corev1.PodPhase) DevboxPhase {
	switch phase {
	case corev1.PodRunning:
		return DevboxRunning
	case corev1.PodPending:
		return DevboxPending
	case corev1.PodFailed:
		return DevboxFailed
	default:
		return DevboxUnknown
	}
}
