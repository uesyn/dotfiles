package main

import (
	"os"

	"github.com/uesyn/devbox/cmd"
)

func main() {
	if err := cmd.NewRootCmd().Execute(); err != nil {
		os.Exit(1)
	}
}
