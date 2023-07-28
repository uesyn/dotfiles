package config

import (
	"encoding/json"
	"errors"
	"os"

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
	Template Template `json:"template,omitempty"`
	SSH      *SSH     `json:"ssh,omitempty"`
	Exec     *Exec    `json:"exec,omitempty"`
	Envs     []Env    `json:"envs,omitempty"`
}

func (c *Config) complete() error {
	if c.SSH == nil {
		c.SSH = &SSH{
			Command: []string{"sh"},
		}
	}
	if c.Exec == nil {
		c.Exec = &Exec{
			Command: []string{"sh"},
		}
	}
	return nil
}

var noNameFieldError = errors.New("no name field")
var noValueFieldError = errors.New("no value field")

func (c *Config) validate() error {
	for _, env := range c.Envs {
		if len(env.Name) == 0 {
			return noNameFieldError
		}
		if len(env.Value) == 0 {
			return noValueFieldError
		}
	}
	return nil
}

type Template struct {
	LoadRestrictionsNone bool `json:"loadRestrictionsNone,omitempty"`
}

type SSH struct {
	Command []string `json:"command,omitempty"`
}

type Exec struct {
	Command []string `json:"command,omitempty"`
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
