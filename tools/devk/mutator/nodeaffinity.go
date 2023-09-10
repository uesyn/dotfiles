package mutator

import (
	"errors"

	corev1 "k8s.io/api/core/v1"
	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
)

func NewNodeAffinityMutator(nodes []corev1.Node) Mutator {
	return &nodeAffinity{nodes: nodes}
}

func NewDefaultNodeAffinityMutator(nodes []corev1.Node) Mutator {
	return &nodeAffinity{nodes: nodes}
}

type nodeAffinity struct {
	nodes []corev1.Node
}

func (a *nodeAffinity) Mutate(pod *applyconfigurationscorev1.PodApplyConfiguration) error {
	if len(a.nodes) == 0 {
		return nil
	}

	if pod == nil || pod.Spec == nil {
		return errors.New("spec field not found")
	}

	var nodeSelectorTerms []*applyconfigurationscorev1.NodeSelectorTermApplyConfiguration
	for _, node := range a.nodes {
		nodeSelectorTerm := applyconfigurationscorev1.NodeSelectorTerm().WithMatchFields(
			applyconfigurationscorev1.NodeSelectorRequirement().
				WithKey("metadata.name").
				WithOperator(corev1.NodeSelectorOpIn).
				WithValues(node.GetName()))
		nodeSelectorTerms = append(nodeSelectorTerms, nodeSelectorTerm)
	}
	affinity := applyconfigurationscorev1.Affinity().WithNodeAffinity(
		applyconfigurationscorev1.NodeAffinity().WithRequiredDuringSchedulingIgnoredDuringExecution(
			applyconfigurationscorev1.NodeSelector().WithNodeSelectorTerms(nodeSelectorTerms...)),
	)
	pod.Spec.WithAffinity(affinity)
	pod.Spec.WithTolerations(applyconfigurationscorev1.Toleration().WithOperator(corev1.TolerationOpExists))
	return nil
}
