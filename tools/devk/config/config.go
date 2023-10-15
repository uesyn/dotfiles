package config

import (
	"encoding/json"
	"errors"
	"github.com/sirupsen/logrus"
	"io"
	"net/http"
	"os"

	applyconfigurationscorev1 "k8s.io/client-go/applyconfigurations/core/v1"
	"sigs.k8s.io/yaml"
)

func Load(file string) (*Config, error) {
	contents, err := os.ReadFile(file)
	if err != nil {
		if !os.IsNotExist(err) {
			return nil, err
		}
		// Download from my dotfiles config
		logrus.Info("config file not found, download from https://raw.githubusercontent.com/uesyn/dotfiles/main/devk/config.yaml")
		resp, err := http.Get("https://raw.githubusercontent.com/uesyn/dotfiles/main/devk/config.yaml")
		if err != nil {
			return nil, err
		}
		contents, err = io.ReadAll(resp.Body)
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
	SSH        *SSH                                                                `json:"ssh,omitempty"`
	Exec       *Exec                                                               `json:"exec,omitempty"`
	Envs       []Env                                                               `json:"envs,omitempty"`
	Pod        *applyconfigurationscorev1.PodSpecApplyConfiguration                `json:"podSpec,omitempty"`
	PVCs       []applyconfigurationscorev1.PersistentVolumeClaimApplyConfiguration `json:"pvcs,omitempty"`
	ConfigMaps []applyconfigurationscorev1.ConfigMapApplyConfiguration             `json:"cms,omitempty"`
}

func (c *Config) complete() error {
	if c.SSH == nil {
		c.SSH = &SSH{}
	}
	if len(c.SSH.Command) == 0 {
		c.SSH.Command = []string{"sh"}
	}
	if len(c.SSH.User) == 0 {
		c.SSH.User = "devbox"
	}
	if c.SSH.Port <= 0 {
		c.SSH.Port = 22
	}

	if c.Exec == nil {
		c.Exec = &Exec{
			Command: []string{"sh"},
		}
	}
	return nil
}

var noNameFieldError = errors.New("no name field")
var noPodFieldError = errors.New("no pod field")

func (c *Config) validate() error {
	if c.Pod == nil {
		return noPodFieldError
	}

	for _, env := range c.Envs {
		if len(env.Name) == 0 {
			return noNameFieldError
		}
	}
	return nil
}

type SSH struct {
	User    string   `json:"user,omitempty"`
	Port    int      `json:"port,omitempty"`
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
