package cmd

import (
	"os"

	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/cmd/runtime"
	"github.com/urfave/cli/v2"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/cli-runtime/pkg/printers"
)

func newListCommand() *cli.Command {
	return &cli.Command{
		Name:    "list",
		Usage:   "List devbox",
		Aliases: []string{"ls"},
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "namespace",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "kubernetes namespace where devbox run",
				EnvVars: []string{"DEVBOX_NAMESPACE"},
			},
			&cli.BoolFlag{
				Name:    "all",
				Aliases: []string{"a"},
				Value:   false,
				Usage:   "if present, list devboxes across all namespaces.",
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

			namespace := params.Namespace
			if params.AllNamespace {
				namespace = metav1.NamespaceAll
			}
			infos, err := params.Manager.List(cCtx.Context, namespace)
			if err != nil {
				return err
			}

			printer := printers.NewTablePrinter(printers.PrintOptions{})
			columns := []metav1.TableColumnDefinition{
				{Name: "Name", Type: "string"},
				{Name: "Namespace", Type: "string"},
				{Name: "Template", Type: "string"},
				{Name: "Status", Type: "string"},
				{Name: "Protected", Type: "bool"},
			}
			var rows []metav1.TableRow
			for _, info := range infos {
				phase, err := info.GetPhase(cCtx.Context)
				if err != nil {
					logger.Error(err, "failed to get devbox info")
					return err
				}
				row := metav1.TableRow{
					Cells: []interface{}{
						info.GetDevboxName(),
						info.GetNamespace(),
						info.GetTemplateName(),
						phase,
						info.Protected(),
					},
				}
				rows = append(rows, row)
			}
			table := &metav1.Table{
				ColumnDefinitions: columns,
				Rows:              rows,
			}
			return printer.PrintObj(table, os.Stdout)
		},
	}
}
