package info

import (
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	listerscorev1 "k8s.io/client-go/listers/core/v1"
)

var _ DevboxInfoAccessor = (*devboxInfoAccessor)(nil)

type devboxInfoAccessor struct {
	podLister    listerscorev1.PodLister
	devboxName   string
	podName      string
	namespace    string
	templateName string
	protected    bool
}

func NewDevboxInfoAccessor(podLister listerscorev1.PodLister, devboxName, podName, namespace, templateName string, protected bool) DevboxInfoAccessor {
	return &devboxInfoAccessor{
		podLister:    podLister,
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

func (a *devboxInfoAccessor) GetPhase() DevboxPhase {
	pod, err := a.podLister.Pods(a.namespace).Get(a.podName)
	if apierrors.IsNotFound(err) {
		return DevboxStopped
	}
	if err != nil {
		return DevboxUnknown
	}
	if !pod.GetDeletionTimestamp().IsZero() {
		return DevboxTerminating
	}
	return podPhaseToDevboxPhase(pod.Status.Phase)
}

func (a *devboxInfoAccessor) GetNode() string {
	pod, err := a.podLister.Pods(a.namespace).Get(a.podName)
	if err != nil {
		return ""
	}
	return pod.Spec.NodeName
}

func (a *devboxInfoAccessor) GetIPs() []string {
	pod, err := a.podLister.Pods(a.namespace).Get(a.podName)
	if err != nil {
		return nil
	}
	var ips []string
	for _, ip := range pod.Status.PodIPs {
		ips = append(ips, ip.IP)
	}
	return ips
}

func (a *devboxInfoAccessor) IsReady() bool {
	pod, err := a.podLister.Pods(a.namespace).Get(a.podName)
	if err != nil {
		return false
	}
	for _, cond := range pod.Status.Conditions {
		if cond.Type != corev1.ContainersReady {
			continue
		}
		if cond.Status == corev1.ConditionTrue {
			return true
		}
	}
	return false
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
