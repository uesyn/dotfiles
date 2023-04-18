package main

import (
	"context"
	"os"

	"github.com/uesyn/devbox/cmd"
)

func main() {
	ctx := context.Background()
	if err := cmd.NewRootApp().RunContext(ctx, os.Args); err != nil {
		os.Exit(1)
	}
}
