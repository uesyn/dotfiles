package cmd

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"time"

	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/uesyn/devbox/ssh"
	"github.com/urfave/cli/v2"
)

func newSSHCommand() *cli.Command {
	return &cli.Command{
		Name:    "ssh",
		Usage:   "SSH to devbox",
		Aliases: []string{"s"},
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "name",
				Value: "default",
				Usage: "devbox name",
			},
			&cli.StringFlag{
				Name:    "namespace",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "kubernetes namespace where devbox run",
				EnvVars: []string{"DEVBOX_NAMESPACE"},
			},
			&cli.StringSliceFlag{
				Name:    "port",
				Aliases: []string{"p"},
				Usage:   "Forwarded ports. e.g., 8080:80, 8080",
			},
			&cli.StringFlag{
				Name:    "ssh-identity-file",
				Aliases: []string{"i"},
				Usage:   "Identity file for SSH authentication",
			},
		},
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}
			logger = logger.WithValues("devboxName", params.Name, "namespace", params.Namespace)
			ctx := logr.NewContext(cCtx.Context, logger)

			// Port forward
			localPort, err := getFreePort()
			if err != nil {
				logger.Error(err, "failed to get free port for SSH")
				return err
			}

			const localhost = "localhost"
			go func() {
				addresses := []string{localhost}
				ports := []string{fmt.Sprintf("%d:%d", localPort, params.SSHPort)}
				err := params.Manager.PortForward(ctx, params.Name, params.Namespace, ports, addresses)
				if err != nil {
					logger.Error(err, "failed to forward ports")
				}
			}()

			timeout := time.After(30 * time.Second)
			for {
				select {
				case <-timeout:
					err := errors.New("timeout exceeded")
					logger.Error(err, "failed to wait for port-forwarding")
					return err
				default:
				}
				if !isListening(localhost, localPort) {
					time.Sleep(100 * time.Millisecond)
					continue
				}
				break
			}

			sshOpts := ssh.Options{
				User:           params.SSHUser,
				Port:           localPort,
				IdentityFile:   params.SSHIdentityFile,
				Envs:           params.Envs,
				Command:        params.SSHCommand,
				ForwardedPorts: params.Ports,
			}
			if err := sshOpts.Complete(); err != nil {
				logger.Error(err, "failed to complete ssh options")
				return err
			}
			if err := sshOpts.Run(cCtx.Context); err != nil {
				logger.Error(err, "failed to run ssh")
				return err
			}
			return nil
		},
	}
}

func getFreePort() (int, error) {
	const invalidPort = -1

	a, err := net.ResolveTCPAddr("tcp", "localhost:0")
	if err != nil {
		return invalidPort, err
	}

	l, err := net.ListenTCP("tcp", a)
	if err != nil {
		return invalidPort, err
	}

	if err := l.Close(); err != nil {
		return invalidPort, err
	}
	return l.Addr().(*net.TCPAddr).Port, nil
}

func isListening(addr string, port int) bool {
	address := net.JoinHostPort(addr, strconv.Itoa(port))
	conn, err := net.DialTimeout("tcp", address, time.Second)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}
