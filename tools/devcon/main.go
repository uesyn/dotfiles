package main

import (
	"os"

	"github.com/uesyn/dotfiles/tools/devcon/cmd"
)

func main() {
	if err := cmd.NewRootCmd().Execute(); err != nil {
		os.Exit(1)
	}
}
