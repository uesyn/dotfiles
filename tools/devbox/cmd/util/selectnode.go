package util

import (
	"context"
	"errors"

	"github.com/ktr0731/go-fuzzyfinder"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

var ErrorNodeSelectCancel = errors.New("cancel node select")

func SelectNodesWithFuzzyFinder(ctx context.Context, c kubernetes.Interface) ([]corev1.Node, error) {
	nodeList, err := c.CoreV1().Nodes().List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}

	ids, err := fuzzyfinder.FindMulti(nodeList.Items, func(i int) string {
		return nodeList.Items[i].GetName()
	})
	if err != nil {
		if err == fuzzyfinder.ErrAbort {
			return nil, ErrorNodeSelectCancel
		}
		return nil, err
	}
	var nodes []corev1.Node
	for _, id := range ids {
		nodes = append(nodes, nodeList.Items[id])
	}
	return nodes, nil
}
