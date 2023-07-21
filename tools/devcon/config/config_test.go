package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/uesyn/dotfiles/tools/devcon/util"
)

func TestLoad(t *testing.T) {
	testConfigFile := "testdata/default.yaml"

	t.Run("should fail to load config", func(t *testing.T) {
		var err error
		_, err = Load("testdata/notfound.yaml")
		assert.Error(t, err)
	})

	var gotConfig Config
	t.Run("shold load config", func(t *testing.T) {
		var err error
		gotConfig, err = Load(testConfigFile)
		assert.NoError(t, err)
	})

	t.Run("should get template config", func(t *testing.T) {
		wantIsLoadRestrictionsNone := true
		assert.Equal(t, wantIsLoadRestrictionsNone, gotConfig.GetTemplateConfig().IsLoadRestrictionsNone())
	})

	t.Run("should get ssh config", func(t *testing.T) {
		wantUser, wantSSHShell := "foo", []string{"baz"}
		assert.Equal(t, wantUser, gotConfig.GetSSHConfig().GetUser())
		assert.Equal(t, wantSSHShell, gotConfig.GetSSHConfig().GetCommand())
	})

	t.Run("should get exec config", func(t *testing.T) {
		beforeBAR := os.Getenv("BAR")
		os.Setenv("BAR", "bar")
		defer os.Setenv("BAR", beforeBAR)

		wantCommand := []string{"zsh"}
		wantEnvs := map[string]string{
			"FOO": "foo",
			"BAR": "bar",
		}

		gotCommand := gotConfig.GetExecConfig().GetCommand()
		assert.Equal(t, wantCommand, gotCommand)

		gotEnvs, err := gotConfig.GetEnvs()
		assert.NoError(t, err)
		assert.Equal(t, wantEnvs, gotEnvs)
	})
}

func TestEnv(t *testing.T) {
	beforeBAR := os.Getenv("BAR")
	os.Setenv("BAR", "bar")
	defer os.Setenv("BAR", beforeBAR)

	tests := []struct {
		desc      string
		env       env
		wantName  string
		wantValue string
		wantErr   bool
	}{
		{
			desc: "raw",
			env: env{
				Name: "FOO",
				Raw:  util.Pointer("foo"),
			},
			wantName:  "FOO",
			wantValue: "foo",
			wantErr:   false,
		},
		{
			desc: "hostEnv",
			env: env{
				Name:    "BAR",
				HostEnv: util.Pointer("BAR"),
			},
			wantName:  "BAR",
			wantValue: "bar",
			wantErr:   false,
		},
		{
			desc: "empty hostEnv",
			env: env{
				Name: "BAZ",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.desc, func(t *testing.T) {
			got, err := tt.env.GetValue()
			if tt.wantErr {
				assert.Error(t, err)
				return
			}
			assert.NoError(t, err)
			assert.Equal(t, tt.wantValue, got)
			assert.Equal(t, tt.wantName, tt.env.GetName())
		})
	}
}
