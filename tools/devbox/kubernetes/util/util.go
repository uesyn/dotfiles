package util

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/uesyn/devbox/kubernetes/client"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/util/wait"
)

var terminatingError = errors.New("terminating")
var conditionFieldNotFound = errors.New("condition field not found")
var conditionTypeNotFoundError = errors.New("condition type not found")
var conditionStatusNotFoundError = errors.New("condition status not found")

func WaitForCondition(ctx context.Context, timeout time.Duration, uClient *client.UnstructuredClient, obj *unstructured.Unstructured, condType string) error {
	return wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, timeout, true, func(context.Context) (bool, error) {
		fresh, err := uClient.Get(ctx, obj, client.GetOptions{})
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
			if strings.ToUpper(ct) != strings.ToUpper(condType) {
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

func WaitForTerminated(ctx context.Context, timeout time.Duration, uClient *client.UnstructuredClient, obj *unstructured.Unstructured) error {
	return wait.PollUntilContextTimeout(ctx, 100*time.Millisecond, timeout, true, func(context.Context) (bool, error) {
		fresh, err := uClient.Get(ctx, obj, client.GetOptions{})
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
