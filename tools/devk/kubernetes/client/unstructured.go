package client

import (
	"context"
	"encoding/json"

	"github.com/uesyn/dotfiles/tools/devk/kubernetes/scheme"
	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/discovery"
	"k8s.io/client-go/discovery/cached/memory"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/restmapper"
)

type UnstructuredClient struct {
	scheme     *runtime.Scheme
	restConfig *rest.Config
	mapper     *restmapper.DeferredDiscoveryRESTMapper
	client     dynamic.Interface
}

func NewUnstructuredClient(restConfig *rest.Config) *UnstructuredClient {
	dc := discovery.NewDiscoveryClientForConfigOrDie(restConfig)
	cached := memory.NewMemCacheClient(dc)
	return &UnstructuredClient{
		scheme:     scheme.Scheme,
		restConfig: restConfig,
		mapper:     restmapper.NewDeferredDiscoveryRESTMapper(cached),
		client:     dynamic.NewForConfigOrDie(restConfig),
	}
}

func (u *UnstructuredClient) getNamespaceableResourceInterface(gvk schema.GroupVersionKind) (dynamic.NamespaceableResourceInterface, *meta.RESTMapping, error) {
	mapping, err := u.mapper.RESTMapping(gvk.GroupKind(), gvk.Version)
	if err != nil {
		return nil, nil, err
	}
	return u.client.Resource(mapping.Resource), mapping, nil
}

func (u *UnstructuredClient) getResourceInterface(obj *unstructured.Unstructured) (dynamic.ResourceInterface, error) {
	nr, mapping, err := u.getNamespaceableResourceInterface(obj.GroupVersionKind())
	if err != nil {
		return nil, err
	}
	if mapping.Scope.Name() == meta.RESTScopeNameNamespace {
		return nr.Namespace(obj.GetNamespace()), nil
	}
	return nr, nil
}

type GetOptions = metav1.GetOptions

func (u *UnstructuredClient) Get(ctx context.Context, obj *unstructured.Unstructured, opts metav1.GetOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	return dr.Get(ctx, obj.GetName(), opts)
}

type CreateOptions = metav1.CreateOptions

func (u *UnstructuredClient) Create(ctx context.Context, obj *unstructured.Unstructured, opts metav1.CreateOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	return dr.Create(ctx, obj, opts)
}

type DeleteOptions = metav1.DeleteOptions

func (u *UnstructuredClient) Delete(ctx context.Context, obj *unstructured.Unstructured, opts metav1.DeleteOptions) error {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return err
	}
	return dr.Delete(ctx, obj.GetName(), opts)
}

type UpdateOptions = metav1.UpdateOptions

func (u *UnstructuredClient) Update(ctx context.Context, obj *unstructured.Unstructured, opts metav1.UpdateOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	return dr.Update(ctx, obj, opts)
}

type PatchOptions = metav1.PatchOptions

func (u *UnstructuredClient) Apply(ctx context.Context, obj *unstructured.Unstructured, opts PatchOptions) (*unstructured.Unstructured, error) {
	dr, err := u.getResourceInterface(obj)
	if err != nil {
		return nil, err
	}
	data, err := json.Marshal(obj)
	if err != nil {
		return nil, err
	}
	return dr.Patch(ctx, obj.GetName(), types.ApplyPatchType, data, opts)
}

type ListOptions = metav1.ListOptions

func (u *UnstructuredClient) List(ctx context.Context, gvk schema.GroupVersionKind, opts metav1.ListOptions) (*unstructured.UnstructuredList, error) {
	dr, _, err := u.getNamespaceableResourceInterface(gvk)
	if err != nil {
		return nil, err
	}
	return dr.List(ctx, opts)
}

func (u *UnstructuredClient) Watch(ctx context.Context, gvk schema.GroupVersionKind, opts ListOptions) (watch.Interface, error) {
	dr, _, err := u.getNamespaceableResourceInterface(gvk)
	if err != nil {
		return nil, err
	}
	return dr.Watch(ctx, opts)
}
