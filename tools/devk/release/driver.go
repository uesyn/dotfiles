package release

import (
	"context"
	"errors"
)

var ErrAlreadyExists = errors.New("release already exists")

type Driver interface {
	Create(ctx context.Context, devkName, namespace string, r *Release) error
	Get(ctx context.Context, devkName, namespace string) (*Release, error)
	Delete(ctx context.Context, devkName, namespace string) error
	Update(ctx context.Context, devkName, namespace string, r *Release) error
	List(ctx context.Context, namespace string) ([]*Release, error)
}
