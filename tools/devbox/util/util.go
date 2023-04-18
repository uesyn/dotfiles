package util

import (
	"os"
	"strings"
)

func Pointer[T any](value T) *T {
	return &value
}

func ExpandPath(path string) string {
	if len(path) == 0 {
		return path
	}
	home, err := os.UserHomeDir()
	if err != nil {
		panic(err)
	}

	path = strings.TrimSpace(path)
	if path[0] == '~' {
		path = home + path[1:]
	}

	return os.Expand(path, func(env string) string {
		if env == "HOME" {
			return home
		}
		return ""
	})
}
