package client

import (
	"github.com/moby/term"
	"k8s.io/client-go/tools/remotecommand"
)

type termSizeQueue struct {
	fd         uintptr
	resizeChan chan *remotecommand.TerminalSize
}

func newTermSizeQueue(fd uintptr) *termSizeQueue {
	return &termSizeQueue{
		fd:         fd,
		resizeChan: make(chan *remotecommand.TerminalSize, 1),
	}
}

func (t *termSizeQueue) GetTermSize() *remotecommand.TerminalSize {
	wsize, err := term.GetWinsize(t.fd)
	if err != nil {
		panic(err)
	}

	return &remotecommand.TerminalSize{
		Width:  wsize.Width,
		Height: wsize.Height,
	}
}

func (t *termSizeQueue) startMonitor() {
	size := t.GetTermSize()
	t.resizeChan <- size

	go func() {
		for {
			current := t.GetTermSize()
			if current.Width == size.Width &&
				current.Height == size.Height {
				continue
			}
			t.resizeChan <- current
			size = current
		}
	}()
}

func (t *termSizeQueue) Next() *remotecommand.TerminalSize {
	size, ok := <-t.resizeChan
	if !ok {
		return nil
	}
	return size
}
