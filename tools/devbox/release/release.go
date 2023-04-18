package release

import (
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

type Release struct {
	Name         string                       `json:"name"`
	Namespace    string                       `json:"namespace"`
	TemplateName string                       `json:"templateName"`
	Objects      []*unstructured.Unstructured `json:"objects"`
	Protect      bool                         `json:"protect"`
}
