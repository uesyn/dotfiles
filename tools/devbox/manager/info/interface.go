package info

import (
	"context"
)

type DevboxPhase string

const (
	DevboxPending     DevboxPhase = "Pending"
	DevboxRunning     DevboxPhase = "Running"
	DevboxStopped     DevboxPhase = "Stopped"
	DevboxFailed      DevboxPhase = "Failed"
	DevboxUnknown     DevboxPhase = "Unknown"
	DevboxTerminating DevboxPhase = "Terminating"
)

type DevboxInfoAccessor interface {
	GetDevboxName() string
	GetNamespace() string
	GetTemplateName() string
	GetPhase(context.Context) (DevboxPhase, error)
	Protected() bool
}
