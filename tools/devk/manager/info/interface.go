package info

type DevkPhase string
type DevkCondition string

const (
	DevkPending     DevkPhase = "Pending"
	DevkRunning     DevkPhase = "Running"
	DevkStopped     DevkPhase = "Stopped"
	DevkFailed      DevkPhase = "Failed"
	DevkTerminating DevkPhase = "Terminating"
	DevkUnknown     DevkPhase = "Unknown"
)

type DevkInfoAccessor interface {
	GetDevkName() string
	GetNamespace() string
	GetPhase() DevkPhase
	GetNode() string
	GetIPs() []string
	IsReady() bool
	Protected() bool
}
