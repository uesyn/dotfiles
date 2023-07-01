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
		Action: func(cCtx *cli.Context) error {
			logger := logr.FromContextOrDiscard(cCtx.Context)
			params := &runtime.Params{}
			if err := params.SetParams(cCtx); err != nil {
				logger.Error(err, "failed to set params")
				return err
			}
			logger = logger.WithValues("devboxName", params.Name, "namespace", params.Namespace)

			infos, err := params.Manager.List(cCtx.Context, params.Namespace)
			if err != nil {
				return err
			}

			printer := printers.NewTablePrinter(printers.PrintOptions{})
			columns := []metav1.TableColumnDefinition{
				{Name: "Name", Type: "string"},
				{Name: "Namespace", Type: "string"},
				{Name: "Template", Type: "string"},
				{Name: "Ready", Type: "bool"},
				{Name: "Phase", Type: "string"},
				{Name: "Node", Type: "string"},
				{Name: "Protected", Type: "bool"},
			}
			var rows []metav1.TableRow
			for _, info := range infos {
				row := metav1.TableRow{
					Cells: []interface{}{
						info.GetDevboxName(),
						info.GetNamespace(),
						info.GetTemplateName(),
						info.IsReady(),
						info.GetPhase(),
						info.GetNode(),
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
