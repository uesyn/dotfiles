package util

import (
	"context"
	"errors"

	"github.com/ktr0731/go-fuzzyfinder"
	"github.com/uesyn/devbox/kubernetes/client"
	corev1 "k8s.io/api/core/v1"
)

var ErrorNodeSelectCancel = errors.New("cancel node select")

func SelectNodesWithFuzzyFinder(ctx context.Context, c client.Client) ([]corev1.Node, error) {
	nodeList := corev1.NodeList{}
	if err := c.List(ctx, &nodeList); err != nil {
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
