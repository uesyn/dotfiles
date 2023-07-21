package main

import (
	"os"

	"github.com/uesyn/dotfiles/tools/devk/cmd"
)

func main() {
	if err := cmd.NewRootCmd().Execute(); err != nil {
		os.Exit(1)
	}
}
