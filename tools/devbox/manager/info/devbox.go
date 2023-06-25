package info

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

var _ DevboxInfoAccessor = (*devboxInfoAccessor)(nil)

type devboxInfoAccessor struct {
	clientset    kubernetes.Interface
	devboxName   string
	podName      string
	namespace    string
	templateName string
	protected    bool
}

func NewDevboxInfoAccessor(clientset kubernetes.Interface, devboxName, podName, namespace, templateName string, protected bool) DevboxInfoAccessor {
	return &devboxInfoAccessor{
		clientset:    clientset,
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
	pod, err := a.clientset.CoreV1().Pods(a.namespace).Get(ctx, a.podName, metav1.GetOptions{})
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
