package template

import (
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"

	"github.com/spf13/afero"
	"github.com/uesyn/dotfiles/tools/devcon/devbox"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	utilyaml "k8s.io/apimachinery/pkg/util/yaml"
	"sigs.k8s.io/kustomize/api/krusty"
	"sigs.k8s.io/kustomize/api/types"
	"sigs.k8s.io/kustomize/kyaml/filesys"
	"sigs.k8s.io/yaml"
)

const (
	kustomizationFileName = "kustomization.yaml"
)

type Loader interface {
	Load(templateName, name, namespace string) (devbox.Devbox, error)
	ListTemplates() ([]string, error)
}

type loader struct {
	templateRootDir      string
	loadRestrictionsNone bool
	fs                   afero.Fs
}

var _ Loader = &loader{}

func NewLoader(root string, loadRestrictionsNone bool) *loader {
	return &loader{
		templateRootDir:      root,
		loadRestrictionsNone: loadRestrictionsNone,
		fs:                   afero.NewReadOnlyFs(afero.NewOsFs()),
	}
}

func (l *loader) Load(templateName, name, namespace string) (devbox.Devbox, error) {
	objs, err := l.build(templateName, name, namespace)
	if err != nil {
		return nil, err
	}
	return devbox.NewDevbox(objs)
}

var (
	unsupportedTemplateTypeError = errors.New("unsupported template type")
	templateNotFoundError        = errors.New("template not found")
)

func (l *loader) build(templateName, name, namespace string) ([]*unstructured.Unstructured, error) {
	templateDir := l.templateDir(templateName)
	kustomizationFilePath := l.kustomizeFilePath(templateDir)
	fSys := MakeFsOnCoWAfero(l.fs)

	if !fSys.Exists(templateDir) {
		return nil, templateNotFoundError
	}

	if l.isKustomizeDir(templateDir) {
		fSys, err := l.updateKustomizeFile(fSys, kustomizationFilePath, name, namespace)
		if err != nil {
			return nil, err
		}
		return l.buildKustomize(fSys, templateDir)
	}
	return nil, unsupportedTemplateTypeError
}

func (l *loader) buildKustomize(fSys filesys.FileSystem, kustomizeDir string) ([]*unstructured.Unstructured, error) {
	kustomizeOpts := krusty.MakeDefaultOptions()
	if l.loadRestrictionsNone {
		kustomizeOpts.LoadRestrictions = types.LoadRestrictionsNone
	}
	kustomizer := krusty.MakeKustomizer(kustomizeOpts)
	resMap, err := kustomizer.Run(fSys, kustomizeDir)
	if err != nil {
		return nil, err
	}

	yamlData, err := resMap.AsYaml()
	if err != nil {
		return nil, err
	}
	return l.yamlToUnstructureds(yamlData)
}

func (l *loader) templateDir(templateName string) string {
	return filepath.Join(l.templateRootDir, templateName)
}

func (l *loader) kustomizeFilePath(dir string) string {
	return filepath.Join(dir, kustomizationFileName)
}

func (l *loader) isKustomizeDir(dir string) bool {
	stat, err := os.Stat(filepath.Join(dir, kustomizationFileName))
	return err == nil && !stat.IsDir()
}

func (l *loader) updateKustomizeFile(fSys filesys.FileSystem, kustomizationFilePath, suffix, namespace string) (filesys.FileSystem, error) {
	contents, err := fSys.ReadFile(kustomizationFilePath)
	if err != nil {
		return nil, err
	}
	var kustomization types.Kustomization
	if err := kustomization.Unmarshal(contents); err != nil {
		return nil, err
	}
	kustomization.FixKustomization()
	kustomization.NameSuffix = "-" + suffix
	kustomization.Namespace = namespace
	contents, err = yaml.Marshal(kustomization)
	if err != nil {
		return nil, err
	}
	if err := fSys.WriteFile(kustomizationFilePath, contents); err != nil {
		return nil, err
	}
	return fSys, nil
}

func (_ *loader) yamlToUnstructureds(data []byte) ([]*unstructured.Unstructured, error) {
	in := bytes.NewBuffer(data)
	dec := utilyaml.NewYAMLOrJSONDecoder(in, 4096)
	var res []*unstructured.Unstructured
	for {
		obj := &unstructured.Unstructured{}
		err := dec.Decode(&obj)
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if obj == nil {
			continue
		}
		res = append(res, obj)
	}
	return res, nil
}

func (l *loader) ListTemplates() ([]string, error) {
	f, err := l.fs.Open(l.templateRootDir)
	if err != nil {
		return nil, err
	}
	dirEntries, err := f.Readdirnames(-1)
	if err != nil {
		return nil, err
	}
	return dirEntries, nil
}
