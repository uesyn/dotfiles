package manifest

import (
	"github.com/uesyn/dotfiles/tools/devk/mutator"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/labels"
)

type ManifestsBuilder interface {
	Filter(selector labels.Selector) ManifestsBuilder
	Mutate(mutators ...mutator.Mutator) (ManifestsBuilder, error)
	MustMutate(mutators ...mutator.Mutator) ManifestsBuilder
	ToObjects() []*unstructured.Unstructured
}

type manifests struct {
	objs []*unstructured.Unstructured
}

var _ ManifestsBuilder = &manifests{}

func NewManifests(objs []*unstructured.Unstructured) ManifestsBuilder {
	return &manifests{objs: objs}
}

func (ms *manifests) Filter(selector labels.Selector) ManifestsBuilder {
	var objs []*unstructured.Unstructured
	for i := range ms.objs {
		obj := ms.objs[i]
		if selector.Matches(labels.Set(obj.GetLabels())) {
			objs = append(objs, obj.DeepCopy())
		}
	}
	return NewManifests(objs)
}

func (ms *manifests) Mutate(mutators ...mutator.Mutator) (ManifestsBuilder, error) {
	var objs []*unstructured.Unstructured
	for i := range ms.objs {
		obj := ms.objs[i].DeepCopy()
		for _, mutator := range mutators {
			var err error
			obj, err = mutator.Mutate(obj)
			if err != nil {
				return nil, err
			}
		}
		objs = append(objs, obj)
	}
	return NewManifests(objs), nil
}

func (ms *manifests) MustMutate(mutators ...mutator.Mutator) ManifestsBuilder {
	objs, err := ms.Mutate(mutators...)
	if err != nil {
		panic(err)
	}
	return objs
}

func (ms *manifests) ToObjects() []*unstructured.Unstructured {
	return (ms.Filter(labels.Everything())).(*manifests).objs
}
