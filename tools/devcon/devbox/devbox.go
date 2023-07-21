package devbox

import (
	"errors"
	"fmt"
	"strings"

	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

const (
	devboxAnnotationKey = "devbox.uesyn.net/devbox"
	sshAnnotationKey    = "devbox.uesyn.net/ssh"
	sshPortName         = "ssh"
)

type Devbox interface {
	GetDevbox() *unstructured.Unstructured
	GetSSHService() *unstructured.Unstructured
	GetDependencies() []*unstructured.Unstructured
}

type devbox struct {
	devboxPod    *unstructured.Unstructured
	sshService   *unstructured.Unstructured
	dependencies []*unstructured.Unstructured
}

var _ Devbox = &devbox{}

func NewDevbox(objs []*unstructured.Unstructured) (Devbox, error) {
	devboxPod, sshService, dependencies, err := separateObjectsForPodAndDependencies(objs)
	if err != nil {
		return nil, err
	}
	if devboxPod == nil {
		return nil, errors.New("devbox object was not found")
	}
	if sshService == nil {
		return nil, errors.New("ssh service was not found")
	}
	return &devbox{
		devboxPod:    devboxPod,
		sshService:   sshService,
		dependencies: dependencies,
	}, nil
}

func separateObjectsForPodAndDependencies(objs []*unstructured.Unstructured) (*unstructured.Unstructured, *unstructured.Unstructured, []*unstructured.Unstructured, error) {
	var devbox *unstructured.Unstructured
	var sshService *unstructured.Unstructured
	var dependencies []*unstructured.Unstructured
	for _, obj := range objs {
		obj := obj
		if isDevbox(obj) {
			if devbox != nil {
				return nil, nil, nil, fmt.Errorf("too many devbox pod objects")
			}
			devbox = obj
			continue
		}

		if isSSHService(obj) {
			if sshService != nil {
				return nil, nil, nil, fmt.Errorf("too many ssh service objects")
			}
			sshService = obj
		}
		dependencies = append(dependencies, obj)
	}
	return devbox, sshService, dependencies, nil
}

func isDevbox(obj *unstructured.Unstructured) bool {
	if obj.GetKind() != "Pod" {
		return false
	}
	annotations := obj.GetAnnotations()
	value, ok := annotations[devboxAnnotationKey]
	if !ok {
		return false
	}
	if !strings.EqualFold(value, "true") {
		return false
	}
	return true
}

func isSSHService(obj *unstructured.Unstructured) bool {
	if obj.GetKind() != "Service" {
		return false
	}
	annotations := obj.GetAnnotations()
	value, ok := annotations[sshAnnotationKey]
	if !ok {
		return false
	}
	if !strings.EqualFold(value, "true") {
		return false
	}
	return true
}

func (d *devbox) GetDevbox() *unstructured.Unstructured {
	return d.devboxPod.DeepCopy()
}

func (d *devbox) GetSSHService() *unstructured.Unstructured {
	return d.sshService.DeepCopy()
}

func (d *devbox) GetDependencies() []*unstructured.Unstructured {
	var dependencies []*unstructured.Unstructured
	for _, d := range d.dependencies {
		obj := d.DeepCopy()
		dependencies = append(dependencies, obj)
	}
	return dependencies
}
