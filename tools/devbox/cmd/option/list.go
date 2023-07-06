package option

import (
	"context"
	"errors"
	"os"
	"strings"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	cmdutil "github.com/uesyn/devbox/cmd/util"
	"github.com/uesyn/devbox/manager"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/cli-runtime/pkg/printers"
	"k8s.io/client-go/kubernetes"
)

type ListOptions struct {
	namespace string
	clientset kubernetes.Interface
	manager   manager.Manager
}

func (o *ListOptions) AddFlags(fs *pflag.FlagSet) {}

func (o *ListOptions) Complete(f cmdutil.Factory) error {
	m, err := f.Manager()
	if err != nil {
		return err
	}
	o.manager = m

	namespace, _, err := f.Namespace()
	if err != nil {
		return err
	}
	o.namespace = namespace

	clientset, err := f.KubeClientSet()
	if err != nil {
		return err
	}
	o.clientset = clientset
	return nil
}

func (o *ListOptions) Validate() error {
	if o.manager == nil {
		return errors.New("must set manager")
	}

	if o.clientset == nil {
		return errors.New("must set clientset")
	}
	return nil
}

func (o *ListOptions) Run(ctx context.Context) error {
	logger := logr.FromContextOrDiscard(ctx).WithValues("namespace", o.namespace)
	infos, err := o.manager.List(ctx, o.namespace)
	if err != nil {
		logger.Error(err, "failed to get list infos")
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
		{Name: "IPs", Type: "string"},
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
				strings.Join(info.GetIPs(), ","),
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
}
