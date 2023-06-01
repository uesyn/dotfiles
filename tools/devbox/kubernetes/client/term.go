package client

import (
	"os"
	"os/signal"
	"syscall"

	"github.com/moby/term"
	"k8s.io/client-go/tools/remotecommand"
)

type termSizeQueue struct {
	fd         uintptr
	resizeChan chan remotecommand.TerminalSize
}

func newTermSizeQueue(fd uintptr) *termSizeQueue {
	return &termSizeQueue{
		fd:         fd,
		resizeChan: make(chan remotecommand.TerminalSize, 1),
	}
}

func (t *termSizeQueue) GetTermSize() remotecommand.TerminalSize {
	wsize, err := term.GetWinsize(t.fd)
	if err != nil {
		panic(err)
	}

	return remotecommand.TerminalSize{
		Width:  wsize.Width,
		Height: wsize.Height,
	}
}

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

func (t *termSizeQueue) Next() *remotecommand.TerminalSize {
	size, ok := <-t.resizeChan
	if !ok {
		return nil
	}
	return &size
}
