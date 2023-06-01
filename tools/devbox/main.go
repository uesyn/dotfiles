package main

import (
	"context"
	"os"

	"github.com/uesyn/devbox/cmd"
)

func main() {
	if err := cmd.NewRootApp().RunContext(context.Background(), os.Args); err != nil {
		os.Exit(1)
	}
}
