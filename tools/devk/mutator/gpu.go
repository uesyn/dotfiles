package mutator

import (
	"errors"
	"fmt"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
)

func NewGPULimitRequest(num int) Mutator {
	return &gpuLimitRequest{num: num}
}

type gpuLimitRequest struct {
	num int
}

func (m *gpuLimitRequest) Mutate(pod *applyconfigurationscorev1.PodApplyConfiguration) error {
	if m.num < 1 {
		return nil
	}

	if pod == nil || pod.Spec == nil || len(pod.Spec.Containers) == 0 {
		return errors.New("container field not found")
	}

	resources := pod.Spec.Containers[0].Resources
	if resources == nil {
		resources = applyconfigurationscorev1.ResourceRequirements()
	}
	limits := corev1.ResourceList{
		"nvidia.com/gpu": resource.MustParse(fmt.Sprint(m.num)),
	}
	if resources.Limits != nil {
		for key, value := range *resources.Limits {
			limits[key] = value
		}
	}
	resources.WithLimits(limits)
	pod.Spec.Containers[0].WithResources(resources)
	return nil
}
