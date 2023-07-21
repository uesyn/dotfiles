package mutator

import (
	"errors"

	"github.com/uesyn/dotfiles/tools/devk/common"
	kubeutil "github.com/uesyn/dotfiles/tools/devk/kubernetes/util"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/runtime"
)

type Mutator interface {
	Mutate(*unstructured.Unstructured) (*unstructured.Unstructured, error)
}

func NewNodeAffinityMutator(nodes []corev1.Node, selector labels.Selector) Mutator {
	return &nodeAffinity{selector: selector, nodes: nodes}
}

var defaultSelector = labels.SelectorFromSet(labels.Set{
	common.DevkPartOfLabelKey: common.DevkPartOfCore,
})

func NewDefaultNodeAffinityMutator(nodes []corev1.Node) Mutator {
	return &nodeAffinity{selector: defaultSelector, nodes: nodes}
}

type nodeAffinity struct {
	selector labels.Selector
	nodes    []corev1.Node
}

func (a *nodeAffinity) Mutate(obj *unstructured.Unstructured) (*unstructured.Unstructured, error) {
	if !a.selector.Matches(labels.Set(obj.GetLabels())) {
		return obj, nil
	}

	switch obj.GetKind() {
	case "Pod":
		pod := corev1.Pod{}
		err := runtime.DefaultUnstructuredConverter.FromUnstructured(obj.Object, &pod)
		if err != nil {
			return nil, err
		}
		a.mutateNodeAffinity(&pod)
		a.mutateNodeToleration(&pod)
		return kubeutil.RuntimeObjectToUnstructured(&pod)
	default:
		return nil, errors.New("unsupported kind")
	}
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
