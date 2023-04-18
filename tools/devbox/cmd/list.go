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
			ctx := logr.NewContext(cCtx.Context, logger)

			namespace := params.Namespace
			if params.AllNamespace {
				namespace = metav1.NamespaceAll
			}
			infos, err := params.Manager.List(ctx, namespace)
			if err != nil {
				logger.Error(err, "failed to list infos")
				os.Exit(1)
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
				phase, err := info.GetPhase(ctx)
				if err != nil {
					logger.Error(err, "failed to get devbox info")
					os.Exit(1)
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
			if err := printer.PrintObj(table, os.Stdout); err != nil {
				logger.Error(err, "failed to print list")
			}
			return nil
		},
	}
}
