package common

const (
	FieldManager           = "devk"
	DevkNameLabelKey       = "devk.uesyn.dev/name"
	DevkStopPolicyLabelKey = "devk.uesyn.dev/stop-policy"
	DevkStopPolicyRetain   = "retain"
	DevkSSHUserLabelKey    = "devk.uesyn.dev/ssh-user"
	DevkKubeConfigPath     = "${HOME}/.local/share/devk/kubeconfig"
	SSHServicePortName     = "ssh"
)
