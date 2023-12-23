package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
)

func TestLoad(t *testing.T) {
	{
		testConfigFile := "testdata/config1.yaml"
		{
			v := os.Getenv("BAR")
			defer os.Setenv("BAR", v)
		}
		os.Setenv("BAR", "bar")
		wantConfig := &Config{
			Exec: &Exec{
				Command: []string{"foo"},
				Envs: []Env{
					{
						Name:  "FOO",
						Value: "foo",
					},
					{
						Name:  "BAR",
						Value: "bar",
					},
				},
			},
			Pod: applyconfigurationscorev1.PodSpec().WithSubdomain("foo"),
			PVCs: []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration{
				func() applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration {
					pvc := applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration{}
					pvc.WithName("foo-pvc").WithKind("PersistentVolumeClaim").WithAPIVersion("v1")
					return pvc
				}(),
			},
			ConfigMaps: []applyconfigurationscorev1.ConfigMapApplyConfiguration{
				func() applyconfigurationscorev1.ConfigMapApplyConfiguration {
					cm := applyconfigurationscorev1.ConfigMapApplyConfiguration{}
					cm.WithName("foo-config").WithKind("ConfigMap").WithAPIVersion("v1")
					return cm
				}(),
			},
		}
		gotConfig, err := Load(testConfigFile)
		assert.NoError(t, err)
		assert.Equal(t, wantConfig, gotConfig)
	}
}
