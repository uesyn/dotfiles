package main

import (
	"os"

	"github.com/uesyn/devbox/cmd"
)

func main() {
	if err := cmd.NewRootCmd().Execute(); err != nil {
		os.Exit(1)
	}
	//	if err := cmd.NewRootApp().RunContext(context.Background(), os.Args); err != nil {
	//		os.Exit(1)
	//	}
}
