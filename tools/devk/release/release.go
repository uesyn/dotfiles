package release

import (
	"github.com/uesyn/dotfiles/tools/devk/manifest"
	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
)

type Objects struct {
	Pod        *applyconfigurationscorev1.PodApplyConfiguration                    `json:"pod"`
	PVCs       []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration `json:"pvcs"`
	ConfigMaps []applyconfigurationscorev1.ConfigMapApplyConfiguration             `json:"cms"`
}

type Release struct {
	Name      string              `json:"name"`
	Namespace string              `json:"namespace"`
	Manifests *manifest.Manifests `json:"manifests"`
	Protect   bool                `json:"protect"`
}
