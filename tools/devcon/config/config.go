package config

import (
	"fmt"
	"os"

	"sigs.k8s.io/yaml"
)

type Config interface {
	GetExecConfig() ExecConfig
	GetSSHConfig() SSHConfig
	GetTemplateConfig() TemplateConfig
	GetEnvs() (map[string]string, error)
}

func Load(file string) (Config, error) {
	contents, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	c := config{}
	if err := yaml.Unmarshal(contents, &c); err != nil {
		return nil, err
	}
	return &c, nil
}

type ExecConfig interface {
	GetCommand() []string
}

type SSHConfig interface {
	GetUser() string
	GetCommand() []string
}

type TemplateConfig interface {
	IsLoadRestrictionsNone() bool
}

type config struct {
	Template template `json:"template,omitempty"`
	SSH      ssh      `json:"ssh,omitempty"`
	Exec     exec     `json:"exec,omitempty"`
	Envs     []env    `json:"envs,omitempty"`
}

func (c *config) GetTemplateConfig() TemplateConfig {
	return &c.Template
}

func (c *config) GetSSHConfig() SSHConfig {
	return &c.SSH
}

func (c *config) GetExecConfig() ExecConfig {
	return &c.Exec
}

func (e *config) GetEnvs() (map[string]string, error) {
	envMap := map[string]string{}
	for _, env := range e.Envs {
		name := env.Name
		v, err := env.GetValue()
		if err != nil {
			return nil, err
		}
		envMap[name] = v
	}
	return envMap, nil
}

type template struct {
	LoadRestrictionsNone bool `json:"loadRestrictionsNone,omitempty"`
}

func (t *template) IsLoadRestrictionsNone() bool {
	return t.LoadRestrictionsNone
}

type ssh struct {
	User    string   `json:"user,omitempty"`
	Command []string `json:"command,omitempty"`
}

const defaultUser = "devbox"

func (s *ssh) GetUser() string {
	if len(s.User) == 0 {
		return defaultUser
	}
	return s.User
}

var defaultCommand = []string{"sh"}

func (s *ssh) GetCommand() []string {
	if len(s.Command) == 0 {
		return defaultCommand
	}
	return s.Command
}

type exec struct {
	Command []string `json:"command,omitempty"`
}

func (e *exec) GetCommand() []string {
	if len(e.Command) == 0 {
		return defaultCommand
	}
	return e.Command
}

type env struct {
	Name    string  `json:"name"`
	Raw     *string `json:"raw"`
	HostEnv *string `json:"hostEnv"`
}

func (e *env) GetName() string {
	return e.Name
}

func (v *env) GetValue() (string, error) {
	if v.Raw != nil {
		return *v.Raw, nil
	}
	if v.HostEnv != nil {
		return os.Getenv(*v.HostEnv), nil
	}
	return "", fmt.Errorf("must set raw, hostEnv or command")
}
