package common

const (
	FieldManager             = "devk"
	DevkNameLabelKey         = "devk.uesyn.dev/name"
	DevkPartOfLabelKey       = "devk.uesyn.dev/part-of"
	DevkPartOfSSH            = "ssh"
	DevkPartOfCore           = "core"
	DevkUpdatePolicyLabelKey = "devk.uesyn.dev/update-policy"
	DevkUpdatePolicyRecreate = "recreate"
	DevkStopPolicyLabelKey   = "devk.uesyn.dev/stop-policy"
	DevkStopPolicyRetain     = "retain"
	DevkSSHUserLabelKey      = "devk.uesyn.dev/ssh-user"
	DevkKubeConfigPath       = "${HOME}/.local/share/devk/kubeconfig"
	SSHServicePortName       = "ssh"
)
