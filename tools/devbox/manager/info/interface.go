package info

type DevboxPhase string
type DevboxCondition string

const (
	DevboxPending     DevboxPhase = "Pending"
	DevboxRunning     DevboxPhase = "Running"
	DevboxStopped     DevboxPhase = "Stopped"
	DevboxFailed      DevboxPhase = "Failed"
	DevboxTerminating DevboxPhase = "Terminating"
	DevboxUnknown     DevboxPhase = "Unknown"
)

type DevboxInfoAccessor interface {
	GetDevboxName() string
	GetNamespace() string
	GetTemplateName() string
	GetPhase() DevboxPhase
	GetNode() string
	GetIPs() []string
	IsReady() bool
	Protected() bool
}
