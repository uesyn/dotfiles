//go:build !windows
// +build !windows

package client

import (
	"os"
	"os/signal"
	"syscall"
)

func (t *termSizeQueue) startMonitor() {
	t.resizeChan <- t.GetTermSize()

	go func() {
		winch := make(chan os.Signal, 1)
		signal.Notify(winch, syscall.SIGWINCH)
		defer signal.Stop(winch)

		for {
			select {
			case <-winch:
				size := t.GetTermSize()
				select {
				case t.resizeChan <- size:
					// success
				default:
					// not sent
				}
			}
		}
	}()
}
