package devbox

import (
	"fmt"

	"github.com/uesyn/devbox/mutator"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
)

type Devbox interface {
	GetDevboxPod(...mutator.PodMutator) (*corev1.Pod, error)
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
		if isDevboxPod(obj) {
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

func isDevboxPod(obj *unstructured.Unstructured) bool {
	return obj.GetKind() == "Pod"
}

func (d *devbox) GetDevboxPod(mutators ...mutator.PodMutator) (*corev1.Pod, error) {
	devboxUnstuctured := d.pod.DeepCopy()
	devboxPod := &corev1.Pod{}
	err := runtime.DefaultUnstructuredConverter.FromUnstructured(devboxUnstuctured.Object, &devboxPod)
	if err != nil {
		return nil, err
	}
	for _, m := range mutators {
		m.Mutate(devboxPod)
	}
	return devboxPod, nil
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
