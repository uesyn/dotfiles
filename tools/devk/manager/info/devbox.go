package info

import (
	"github.com/uesyn/dotfiles/tools/devk/common"
	"github.com/uesyn/dotfiles/tools/devk/release"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime/schema"
	listerscorev1 "k8s.io/client-go/listers/core/v1"
)

var _ DevkInfoAccessor = (*devkInfoAccessor)(nil)

type devkInfoAccessor struct {
	podLister listerscorev1.PodLister
	release   *release.Release
}

func NewDevkInfoAccessor(podLister listerscorev1.PodLister, r *release.Release) DevkInfoAccessor {
	return &devkInfoAccessor{
		podLister: podLister,
		release:   r,
	}
}

func (a *devkInfoAccessor) getWorkerPod() (*corev1.Pod, error) {
	selector := labels.SelectorFromSet(labels.Set(map[string]string{
		common.DevkNameLabelKey: a.release.Name,
	}))
	pods, err := a.podLister.List(selector)
	if err != nil {
		return nil, err
	}
	if len(pods) == 0 {
		return nil, apierrors.NewNotFound(schema.GroupResource{Resource: "pods"}, "")
	}
	// TODO: sort with creationTimeStamp
	return pods[0], nil
}

func (a *devkInfoAccessor) GetDevkName() string {
	return a.release.Name
}

func (a *devkInfoAccessor) GetNamespace() string {
	return a.release.Namespace
}

func (a *devkInfoAccessor) Protected() bool {
	return a.release.Protect
}

func (a *devkInfoAccessor) GetPhase() DevkPhase {
	pod, err := a.getWorkerPod()
	if apierrors.IsNotFound(err) {
		return DevkStopped
	}
	if err != nil {
		return DevkUnknown
	}
	if !pod.GetDeletionTimestamp().IsZero() {
		return DevkTerminating
	}
	return podPhaseToDevkPhase(pod.Status.Phase)
}

func (a *devkInfoAccessor) GetNode() string {
	pod, err := a.getWorkerPod()
	if err != nil {
		return ""
	}
	return pod.Spec.NodeName
}

func (a *devkInfoAccessor) GetIPs() []string {
	pod, err := a.getWorkerPod()
	if err != nil {
		return nil
	}
	var ips []string
	for _, ip := range pod.Status.PodIPs {
		ips = append(ips, ip.IP)
	}
	return ips
}

func (a *devkInfoAccessor) IsReady() bool {
	pod, err := a.getWorkerPod()
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

func podPhaseToDevkPhase(phase corev1.PodPhase) DevkPhase {
	switch phase {
	case corev1.PodRunning:
		return DevkRunning
	case corev1.PodPending:
		return DevkPending
	case corev1.PodFailed:
		return DevkFailed
	default:
		return DevkUnknown
	}
}
