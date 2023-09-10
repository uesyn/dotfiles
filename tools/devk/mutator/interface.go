package mutator

import (
	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
)

type Mutator interface {
	Mutate(pod *applyconfigurationscorev1.PodApplyConfiguration) error
}
