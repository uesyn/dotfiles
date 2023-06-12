package client

import (
	"time"
)

func (t *termSizeQueue) startMonitor() {
	t.resizeChan <- t.GetTermSize()

	go func() {
		lastSize := t.GetTermSize()
		for {
			size := t.GetTermSize()
			if size.Height != lastSize.Height || size.Width != lastSize.Width {
				lastSize.Height = size.Height
				lastSize.Width = size.Width
				t.resizeChan <- size
			}
			time.Sleep(250 * time.Millisecond)
		}
	}()
}
