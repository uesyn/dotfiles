package config

import (
	"encoding/json"
	"errors"
	"os"

	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
	"sigs.k8s.io/yaml"
)

func Load(file string) (*Config, error) {
	contents, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	c := Config{}
	if err := yaml.Unmarshal(contents, &c); err != nil {
		return nil, err
	}
	if err := c.complete(); err != nil {
		return nil, err
	}
	if err := c.validate(); err != nil {
		return nil, err
	}
	return &c, nil
}

type Config struct {
	Exec       *Exec                                                               `json:"exec,omitempty"`
	Pod        *applyconfigurationscorev1.PodSpecApplyConfiguration                `json:"podSpec,omitempty"`
	PVCs       []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration `json:"pvcs,omitempty"`
	ConfigMaps []applyconfigurationscorev1.ConfigMapApplyConfiguration             `json:"cms,omitempty"`
}

func (c *Config) complete() error {
	if c.Exec == nil {
		c.Exec = &Exec{
			Command: []string{"sh"},
		}
	}
	return nil
}

var noNameFieldError = errors.New("no name field")
var noPodFieldError = errors.New("no pod field")
var noExecFieldError = errors.New("no exec field")

func (c *Config) validate() error {
	if c.Pod == nil {
		return noPodFieldError
	}

	if c.Exec == nil {
		return noExecFieldError
	}
	if err := c.Exec.validate(); err != nil {
		return err
	}

	return nil
}

type Exec struct {
	Command []string `json:"command,omitempty"`
	Envs    []Env    `json:"envs,omitempty"`
}

func (e *Exec) validate() error {
	for _, env := range e.Envs {
		if len(env.Name) == 0 {
			return noNameFieldError
		}
	}
	return nil
}

type Env struct {
	Name  string
	Value string
}

func (e *Env) UnmarshalJSON(data []byte) error {
	type envRaw struct {
		Name    string  `json:"name"`
		Raw     *string `json:"raw"`
		HostEnv *string `json:"hostEnv"`
	}
	raw := envRaw{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	e.Name = raw.Name
	if raw.Raw != nil {
		e.Value = *raw.Raw
	}
	if raw.HostEnv != nil {
		e.Value = os.Getenv(*raw.HostEnv)
	}
	return nil
}
