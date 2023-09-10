package manifest

import (
	"fmt"

	"github.com/uesyn/dotfiles/tools/devk/common"
	"github.com/uesyn/dotfiles/tools/devk/mutator"
	"github.com/uesyn/dotfiles/tools/devk/util"
	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
)

const (
	namePrefix = "devbox-"
)

type Manifests struct {
	Pod        *applyconfigurationscorev1.PodApplyConfiguration
	ConfigMaps []applyconfigurationscorev1.ConfigMapApplyConfiguration
	PVCs       []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration
}

func NewManifests(pod *applyconfigurationscorev1.PodApplyConfiguration,
	cms []applyconfigurationscorev1.ConfigMapApplyConfiguration,
	pvcs []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration) *Manifests {
	manifests := &Manifests{}
	manifests.Pod = util.DeepCopy(pod)
	for _, cm := range cms {
		manifests.ConfigMaps = append(manifests.ConfigMaps, util.DeepCopy(cm))
	}
	for _, pvc := range pvcs {
		manifests.PVCs = append(manifests.PVCs, util.DeepCopy(pvc))
	}
	return manifests
}

func (ms *Manifests) Mutate(mutators ...mutator.Mutator) (*Manifests, error) {
	ret := &Manifests{}
	ret.Pod = util.DeepCopy(ms.Pod)
	for _, mutator := range mutators {
		if err := mutator.Mutate(ret.Pod); err != nil {
			return nil, err
		}
	}
	for _, cm := range ms.ConfigMaps {
		ret.ConfigMaps = append(ret.ConfigMaps, util.DeepCopy(cm))
	}
	for _, pvc := range ms.PVCs {
		ret.PVCs = append(ret.PVCs, util.DeepCopy(pvc))
	}
	return ret, nil
}

func (ms *Manifests) MustMutate(mutators ...mutator.Mutator) *Manifests {
	ret := &Manifests{}
	ret.Pod = util.DeepCopy(ms.Pod)
	for _, mutator := range mutators {
		if err := mutator.Mutate(ret.Pod); err != nil {
			panic(err)
		}
	}
	for _, cm := range ms.ConfigMaps {
		ret.ConfigMaps = append(ret.ConfigMaps, util.DeepCopy(cm))
	}
	for _, pvc := range ms.PVCs {
		ret.PVCs = append(ret.PVCs, util.DeepCopy(pvc))
	}
	return ret
}

func Generate(devkName, namespace string, podSpec *applyconfigurationscorev1.PodSpecApplyConfiguration, cmTemplates []applyconfigurationscorev1.ConfigMapApplyConfiguration, pvcTemplates []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration) *Manifests {
	podName := podName(devkName)
	commonLabels := map[string]string{common.DevkNameLabelKey: devkName}
	pod := applyconfigurationscorev1.Pod(podName, namespace)
	pod.WithSpec(util.DeepCopy(podSpec))
	pod.WithLabels(commonLabels)
	for i := range pod.Spec.Volumes {
		volume := pod.Spec.Volumes[i]
		if volume.PersistentVolumeClaim != nil {
			vName := volumeName(podName, *volume.PersistentVolumeClaim.ClaimName)
			volume.PersistentVolumeClaim.WithClaimName(vName)
		}
		if volume.ConfigMap != nil {
			vName := volumeName(podName, *volume.ConfigMap.Name)
			volume.ConfigMap.WithName(vName)
		}
		pod.Spec.Volumes[i] = volume
	}

	var cms []applyconfigurationscorev1.ConfigMapApplyConfiguration
	for _, cmTemplate := range cmTemplates {
		cm := util.DeepCopy(cmTemplate)
		cm.WithName(cmName(podName, *cm.Name))
		cm.WithNamespace(namespace)
		cm.WithLabels(commonLabels)
		cms = append(cms, cm)
	}

	var pvcs []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration
	for _, pvcTemplate := range pvcTemplates {
		pvc := util.DeepCopy(pvcTemplate)
		pvc.WithName(volumeName(podName, *pvc.Name))
		pvc.WithNamespace(namespace)
		pvc.WithLabels(commonLabels)
		pvcs = append(pvcs, pvc)
	}

	return &Manifests{
		Pod:        pod,
		ConfigMaps: cms,
		PVCs:       pvcs,
	}
}

func podName(devkName string) string {
	return fmt.Sprintf("%s%s", namePrefix, devkName)
}

func volumeName(podName, pvcName string) string {
	return fmt.Sprintf("%s-%s", podName, pvcName)
}

func cmName(podName, pvcName string) string {
	return fmt.Sprintf("%s-%s", podName, pvcName)
}
