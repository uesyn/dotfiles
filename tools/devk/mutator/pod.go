package mutator

import (
	"errors"

	"github.com/uesyn/dotfiles/tools/devk/common"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/labels"
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

var unSupportedKindError = errors.New("unsupported kind")

func (a *nodeAffinity) Mutate(obj *unstructured.Unstructured) (*unstructured.Unstructured, error) {
	if !a.selector.Matches(labels.Set(obj.GetLabels())) {
		return obj, nil
	}

	switch obj.GetKind() {
	case "Pod":
		if err := a.mutateNodeAffinity(obj); err != nil {
			return nil, err
		}
		if err := a.mutateNodeToleration(obj); err != nil {
			return nil, err
		}
		return obj, nil
	default:
		return nil, unSupportedKindError
	}
}

func (a *nodeAffinity) mutateNodeAffinity(obj *unstructured.Unstructured) error {
	if len(a.nodes) == 0 {
		return nil
	}

	var matchFields []interface{}
	for _, node := range a.nodes {
		matchField := map[string]interface{}{
			"key":      "metadata.name",
			"operator": "In",
			"values":   []interface{}{node.GetName()},
		}
		matchFields = append(matchFields, matchField)
	}

	nodeSelectorTerms := []interface{}{
		map[string]interface{}{
			"matchFields": matchFields,
		},
	}

	affinity := map[string]interface{}{
		"nodeAffinity": map[string]interface{}{
			"requiredDuringSchedulingIgnoredDuringExecution": map[string]interface{}{
				"nodeSelectorTerms": nodeSelectorTerms,
			},
		},
	}

	if err := unstructured.SetNestedMap(obj.Object, affinity, "spec", "affinity"); err != nil {
		return err
	}
	return nil
}

func (a *nodeAffinity) mutateNodeToleration(obj *unstructured.Unstructured) error {
	if len(a.nodes) == 0 {
		return nil
	}
	tolerations := []interface{}{
		map[string]interface{}{
			"operator": "Exists",
		},
	}
	if err := unstructured.SetNestedSlice(obj.Object, tolerations, "spec", "tolerations"); err != nil {
		return err
	}
	return nil
}
