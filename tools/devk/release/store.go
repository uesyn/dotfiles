package release

import (
	"context"
	"errors"
	"fmt"

	"github.com/go-logr/logr"
	"k8s.io/client-go/kubernetes"
)

type Store interface {
	Create(ctx context.Context, devkName, namespace string, r *Release) error
	Get(ctx context.Context, devkName, namespace string) (*Release, error)
	Delete(ctx context.Context, devkName, namespace string) error
	Update(ctx context.Context, devkName, namespace string, r *Release) error
	List(ctx context.Context, namespace string) ([]*Release, error)
}

type store struct {
	driver Driver
}

var _ Store = &store{}

func NewDefaultStore(c kubernetes.Interface) *store {
	return NewStore(newSecretDriver(c))
}

func NewStore(d Driver) *store {
	return &store{driver: d}
}

const (
	releaseNameKey = "releaseName"
	namespaceKey   = "namespace"
)

func IsAlreadyExists(err error) bool {
	return errors.Is(err, ErrAlreadyExists)
}

func (s *store) Create(ctx context.Context, devkName, namespace string, r *Release) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues(releaseNameKey, devkName, namespaceKey, namespace)
	ctx = logr.NewContext(ctx, logger)
	logger.V(1).Info("save release")
	if err := s.driver.Create(ctx, devkName, namespace, r); err != nil {
		return fmt.Errorf("failed to create release: %w", err)
	}
	return nil
}

func (s *store) Get(ctx context.Context, devkName, namespace string) (*Release, error) {
	logger := logr.FromContextOrDiscard(ctx).WithValues(releaseNameKey, devkName, namespaceKey, namespace)
	ctx = logr.NewContext(ctx, logger)
	logger.V(1).Info("get release")
	r, err := s.driver.Get(ctx, devkName, namespace)
	if err != nil {
		return nil, fmt.Errorf("failed to get release: %w", err)
	}
	return r, nil
}

func (s *store) Delete(ctx context.Context, devkName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues(releaseNameKey, devkName, namespaceKey, namespace)
	ctx = logr.NewContext(ctx, logger)
	logger.V(1).Info("delete release")
	if err := s.driver.Delete(ctx, devkName, namespace); err != nil {
		return fmt.Errorf("failed to delete release: %w", err)
	}
	return nil
}

func (s *store) Update(ctx context.Context, devkName, namespace string, r *Release) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues(releaseNameKey, devkName, namespaceKey, namespace)
	ctx = logr.NewContext(ctx, logger)
	logger.V(1).Info("update release")
	if err := s.driver.Update(ctx, devkName, namespace, r); err != nil {
		return fmt.Errorf("failed to update release: %w", err)
	}
	return nil
}

func (s *store) List(ctx context.Context, namespace string) ([]*Release, error) {
	logger := logr.FromContextOrDiscard(ctx).WithValues(namespaceKey, namespace)
	ctx = logr.NewContext(ctx, logger)
	logger.V(1).Info("list release")
	rs, err := s.driver.List(ctx, namespace)
	if err != nil {
		return nil, fmt.Errorf("failed to list releases: %w", err)
	}
	return rs, nil
}
