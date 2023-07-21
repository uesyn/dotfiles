package util

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/uesyn/dotfiles/tools/devk/kubernetes/client"
	"github.com/uesyn/dotfiles/tools/devk/kubernetes/scheme"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/wait"
)

const (
	ConditionReady = "Ready"
)

var (
	terminatingError             = errors.New("terminating")
	conditionFieldNotFound       = errors.New("condition field not found")
	conditionTypeNotFoundError   = errors.New("condition type not found")
	conditionStatusNotFoundError = errors.New("condition status not found")
)

func RuntimeObjectToUnstructured(obj runtime.Object) (*unstructured.Unstructured, error) {
	var unstructuredObj *unstructured.Unstructured
	switch o := obj.(type) {
	case *unstructured.Unstructured:
		unstructuredObj = o
	default:
		gvks, _, err := scheme.Scheme.ObjectKinds(o)
		if err != nil {
			return nil, err
		}
		objMap, err := runtime.DefaultUnstructuredConverter.ToUnstructured(o)
		if err != nil {
			return nil, err
		}
		unstructuredObj = &unstructured.Unstructured{Object: objMap}
		unstructuredObj.SetGroupVersionKind(gvks[0])
	}
	return unstructuredObj, nil
}

func WaitForCondition(ctx context.Context, timeout time.Duration, uClient *client.UnstructuredClient, obj runtime.Object, condType string) error {
	unstructuredObj, err := RuntimeObjectToUnstructured(obj)
	if err != nil {
		return err
	}
	return wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, timeout, true, func(context.Context) (bool, error) {
		fresh, err := uClient.Get(ctx, unstructuredObj, client.GetOptions{})
		if err != nil {
			return false, err
		}
		if !fresh.GetDeletionTimestamp().IsZero() {
			return false, terminatingError
		}
		conditions, found, err := unstructured.NestedSlice(fresh.Object, "status", "conditions")
		if !found || err != nil {
			return false, conditionFieldNotFound
		}
		for _, cond := range conditions {
			c := cond.(map[string]interface{})
			ct, ok := c["type"].(string)
			if !ok {
				return false, conditionTypeNotFoundError
			}
			if strings.EqualFold(ct, condType) {
				continue
			}

			cs, ok := c["status"].(string)
			if !ok {
				return false, conditionStatusNotFoundError
			}

			if cs != "True" {
				return false, nil
			}
			return true, nil
		}
		return false, nil
	})
}

var notTerminatingError = errors.New("not terminating")

func WaitForTerminated(ctx context.Context, timeout time.Duration, uClient *client.UnstructuredClient, obj runtime.Object) error {
	unstructuredObj, err := RuntimeObjectToUnstructured(obj)
	if err != nil {
		return err
	}
	return wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, timeout, true, func(context.Context) (bool, error) {
		fresh, err := uClient.Get(ctx, unstructuredObj, client.GetOptions{})
		if err != nil {
			if !apierrors.IsNotFound(err) {
				return false, err
			}
			return true, nil
		}
		if fresh.GetDeletionTimestamp().IsZero() {
			return false, notTerminatingError
		}
		return false, nil
	})
}
