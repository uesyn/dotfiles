package mutator

import (
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

type Mutator interface {
	Mutate(*unstructured.Unstructured) (*unstructured.Unstructured, error)
}
