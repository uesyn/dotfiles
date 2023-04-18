package template

import (
	"path/filepath"

	"github.com/spf13/afero"
	"sigs.k8s.io/kustomize/kyaml/filesys"
)

func MakeFsOnCoWAfero(base afero.Fs) filesys.FileSystem {
	roBase := afero.NewReadOnlyFs(base)
	ufs := afero.NewCopyOnWriteFs(roBase, afero.NewMemMapFs())
	return MakeFsOnAfero(ufs)
}

func MakeFsOnAfero(base afero.Fs) filesys.FileSystem {
	return &fsOnAfero{aferoFs: base}
}

type fsOnAfero struct {
	aferoFs afero.Fs
}

var _ filesys.FileSystem = &fsOnAfero{}

func (f *fsOnAfero) Create(path string) (filesys.File, error) {
	return f.aferoFs.Create(path)
}

func (f *fsOnAfero) Mkdir(path string) error {
	return f.aferoFs.Mkdir(path, 0744)
}

func (f *fsOnAfero) MkdirAll(path string) error {
	return f.aferoFs.MkdirAll(path, 0744)
}

func (f *fsOnAfero) RemoveAll(path string) error {
	return f.aferoFs.RemoveAll(path)
}

func (f *fsOnAfero) Open(path string) (filesys.File, error) {
	return f.aferoFs.Open(path)
}

func (f *fsOnAfero) IsDir(path string) bool {
	stat, err := f.aferoFs.Stat(path)
	if err != nil {
		return false
	}
	return stat.IsDir()
}

func (f *fsOnAfero) ReadDir(path string) ([]string, error) {
	file, err := f.aferoFs.Open(path)
	if err != nil {
		return nil, err
	}
	return file.Readdirnames(-1)
}

func (f *fsOnAfero) CleanedAbs(path string) (filesys.ConfirmedDir, string, error) {
	stat, err := f.aferoFs.Stat(path)
	if err != nil {
		return "", "", err
	}
	if stat.IsDir() {
		return filesys.ConfirmedDir(path), "", nil
	}
	return filesys.ConfirmedDir(filepath.Dir(path)), filepath.Base(path), nil
}

func (f *fsOnAfero) Exists(path string) bool {
	_, err := f.aferoFs.Stat(path)
	return err == nil
}

func (f *fsOnAfero) Glob(pattern string) ([]string, error) {
	return afero.Glob(f.aferoFs, pattern)
}

func (f *fsOnAfero) ReadFile(path string) ([]byte, error) {
	return afero.ReadFile(f.aferoFs, path)
}

func (f *fsOnAfero) WriteFile(path string, data []byte) error {
	return afero.WriteFile(f.aferoFs, path, data, 0744)
}

func (f *fsOnAfero) Walk(path string, walkFn filepath.WalkFunc) error {
	return afero.Walk(f.aferoFs, path, walkFn)
}
