package mutator

import (
	"errors"
	"fmt"

	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

func NewGPULimitRequest(num int) Mutator {
	return &gpuLimitRequest{num: num}
}

type gpuLimitRequest struct {
	num int
}

func (m *gpuLimitRequest) Mutate(obj *unstructured.Unstructured) (*unstructured.Unstructured, error) {
	if m.num < 1 {
		return obj, nil
	}

	var containerFields []string
	switch obj.GetKind() {
	case "Pod":
		containerFields = []string{"spec", "containers"}
	case "Deployment", "StatefulSet":
		containerFields = []string{"spec", "template", "spec", "containers"}
	default:
		return obj, nil
	}

	containers, _, err := unstructured.NestedSlice(obj.Object, containerFields...)
	if err != nil {
		return nil, err
	}
	if len(containers) == 0 {
		return nil, errors.New("no container")
	}
	container := containers[0].(map[string]interface{})
	if err := unstructured.SetNestedField(container, fmt.Sprintf("%d", m.num), "resources", "limits", "nvidia.com/gpu"); err != nil {
		return nil, err
	}
	containers[0] = container
	if err := unstructured.SetNestedSlice(obj.Object, containers, containerFields...); err != nil {
		return nil, err
	}
	return obj, nil
}
