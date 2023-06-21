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
			&cli.StringFlag{
				Name:    "template",
				Aliases: []string{"t"},
				Value:   "default",
				Usage:   "template name",
			},
			&cli.StringSliceFlag{
				Name:  "address",
				Value: cli.NewStringSlice("127.0.0.1"),
				Usage: "Addresses are binded for port-forward",
			},
			&cli.StringSliceFlag{
				Name:    "port",
				Aliases: []string{"p"},
				Usage:   "Forwarded ports",
			},
			&cli.StringFlag{
				Name:  "ssh-port",
				Usage: "Port listened by ssh server on devbox",
				Value: "22",
			},
			&cli.StringFlag{
				Name:  "ssh-user",
				Usage: "Username to be logged in",
				Value: "devbox",
			},
			&cli.StringFlag{
				Name:    "ssh-identity-file",
				Aliases: []string{"i"},
				Usage:   "SSH identity file",
			},
			&cli.StringFlag{
				Name:    "shell",
				Aliases: []string{"s"},
				Usage:   "shell",
				Value:   "bash",
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
			var addresses []string
			for i := range params.Addresses {
				addresses = append(addresses, params.Addresses[i])
			}
			var ports []string
			for i := range params.Ports {
				ports = append(ports, params.Ports[i])
			}

			localPortNum, err := getFreePort()
			if err != nil {
				logger.Error(err, "failed to get free port for SSH")
				return err
			}
			localPort := strconv.Itoa(localPortNum)
			ports = append(ports, fmt.Sprintf("%s:%s", localPort, params.SSHPort))

			go func() {
				err := params.Manager.PortForward(ctx, params.Name, params.Namespace, ports, addresses)
				if err != nil {
					logger.Error(err, "failed to forward ports")
				}
			}()

			const localhost = "localhost"
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

			// SSH
			execConfig := params.Config.GetExecConfig()
			sshOpts := ssh.Options{
				User:         params.SSHUser,
				Port:         strconv.Itoa(localPortNum),
				Address:      localhost,
				IdentityFile: params.SSHIdentityFile,
			}
			envs, err := execConfig.GetEnvs()
			if err != nil {
				logger.Error(err, "failed to load envs config")
				return err
			}
			if err := sshOpts.Run(cCtx.Context, params.Shell, envs); err != nil {
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

func isListening(addr string, port string) bool {
	address := net.JoinHostPort(addr, port)
	conn, err := net.DialTimeout("tcp", address, time.Second)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}
