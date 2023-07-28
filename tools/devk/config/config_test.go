package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
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
			Template: Template{
				LoadRestrictionsNone: true,
			},
			Exec: &Exec{Command: []string{"foo"}},
			SSH:  &SSH{Command: []string{"baz"}},
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
		}
		gotConfig, err := Load(testConfigFile)
		assert.NoError(t, err)
		assert.Equal(t, wantConfig, gotConfig)
	}

	{
		testConfigFile := "testdata/empty.yaml"
		wantConfig := &Config{
			Exec: &Exec{Command: []string{"sh"}},
			SSH:  &SSH{Command: []string{"sh"}},
		}
		gotConfig, err := Load(testConfigFile)
		assert.NoError(t, err)
		assert.Equal(t, wantConfig, gotConfig)
	}
}
