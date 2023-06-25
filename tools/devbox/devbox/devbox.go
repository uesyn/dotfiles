package devbox

import (
	"fmt"

	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

type Devbox interface {
	GetDevbox() *unstructured.Unstructured
	GetDependencies() []*unstructured.Unstructured
	ToUnstructureds() []*unstructured.Unstructured
}

type devbox struct {
	pod          *unstructured.Unstructured
	dependencies []*unstructured.Unstructured
}

var _ Devbox = &devbox{}

func NewDevbox(objs []*unstructured.Unstructured) (Devbox, error) {
	devboxPod, dependencies, err := separateObjectsForPodAndDependencies(objs)
	if err != nil {
		return nil, err
	}
	return &devbox{
		pod:          devboxPod,
		dependencies: dependencies,
	}, nil
}

func separateObjectsForPodAndDependencies(objs []*unstructured.Unstructured) (*unstructured.Unstructured, []*unstructured.Unstructured, error) {
	var devbox *unstructured.Unstructured
	var dependencies []*unstructured.Unstructured
	for _, obj := range objs {
		obj := obj
		if isDevbox(obj) {
			if devbox == nil {
				devbox = obj
				continue
			}
			return nil, nil, fmt.Errorf("too many devbox pod objects")
		}
		dependencies = append(dependencies, obj)
	}
	return devbox, dependencies, nil
}

func isDevbox(obj *unstructured.Unstructured) bool {
	return obj.GetKind() == "Pod"
}

func (d *devbox) GetDevbox() *unstructured.Unstructured {
	return d.pod.DeepCopy()
}

func (d *devbox) GetDependencies() []*unstructured.Unstructured {
	var dependencies []*unstructured.Unstructured
	for _, d := range d.dependencies {
		obj := d.DeepCopy()
		dependencies = append(dependencies, obj)
	}
	return dependencies
}

func (d *devbox) ToUnstructureds() []*unstructured.Unstructured {
	var dependencies []*unstructured.Unstructured
	for _, d := range d.dependencies {
		obj := d.DeepCopy()
		dependencies = append(dependencies, obj)
	}
	dependencies = append(dependencies, d.pod.DeepCopy())
	return dependencies
}
