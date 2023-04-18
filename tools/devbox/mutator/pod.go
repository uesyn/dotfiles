package mutator

import (
	corev1 "k8s.io/api/core/v1"
)

type PodMutator interface {
	Mutate(*corev1.Pod)
}

func NewNodeAffinityMutator(nodes []corev1.Node) PodMutator {
	return &nodeAffinity{nodes: nodes}
}

type nodeAffinity struct {
	nodes []corev1.Node
}

func (a *nodeAffinity) Mutate(pod *corev1.Pod) {
	a.mutateNodeAffinity(pod)
	a.mutateNodeToleration(pod)
}

func (a *nodeAffinity) mutateNodeAffinity(pod *corev1.Pod) {
	if len(a.nodes) == 0 {
		return
	}

	var nodeSelectorTerms []corev1.NodeSelectorTerm
	for _, node := range a.nodes {
		nodeSelectorTerm := corev1.NodeSelectorTerm{
			MatchFields: []corev1.NodeSelectorRequirement{
				{
					Key:      "metadata.name",
					Operator: corev1.NodeSelectorOpIn,
					Values:   []string{node.GetName()},
				},
			},
		}
		nodeSelectorTerms = append(nodeSelectorTerms, nodeSelectorTerm)
	}

	nodeAffinity := &corev1.NodeAffinity{
		RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
			NodeSelectorTerms: nodeSelectorTerms,
		},
	}

	if pod.Spec.Affinity == nil {
		pod.Spec.Affinity = &corev1.Affinity{}
	}
	pod.Spec.Affinity.NodeAffinity = nodeAffinity
}

func (a *nodeAffinity) mutateNodeToleration(pod *corev1.Pod) {
	if len(a.nodes) == 0 {
		return
	}
	tolerationKeyValue := make(map[string]string)
	for _, toleration := range pod.Spec.Tolerations {
		tolerationKeyValue[toleration.Key] = toleration.Value
	}

	var tolerations []corev1.Toleration
	for _, node := range a.nodes {
		for _, taint := range node.Spec.Taints {
			toleration := corev1.Toleration{
				Key:      taint.Key,
				Operator: corev1.TolerationOpExists,
			}

			value, found := tolerationKeyValue[toleration.Key]
			if found && value == toleration.Value {
				continue
			}
			tolerations = append(tolerations, toleration)
		}
	}
	pod.Spec.Tolerations = tolerations
}
