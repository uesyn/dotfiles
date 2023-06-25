package release

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/go-logr/logr"
	"github.com/uesyn/devbox/util"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	meta "k8s.io/apimachinery/pkg/apis/meta/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/yaml"
	"k8s.io/client-go/kubernetes"
)

var _ Driver = (*secretDriver)(nil)

const (
	releaseContentsKey         = "contents"
	devboxInfoSecretLabalKey   = "app.kubernetes.io/part-of"
	devboxInfoSecretLabalValue = "devbox"
)

type secretDriver struct {
	c kubernetes.Interface
}

func newSecretDriver(c kubernetes.Interface) *secretDriver {
	return &secretDriver{c: c}
}

func (d *secretDriver) Create(ctx context.Context, devboxName, namespace string, r *Release) error {
	logger := logr.FromContextOrDiscard(ctx)
	logger.V(1).Info("save release to kubernetes secret")

	secret, err := d.newSecret(devboxName, namespace, r)
	if err != nil {
		return err
	}
	_, err = d.c.CoreV1().Secrets(namespace).Create(ctx, secret, meta.CreateOptions{})
	if apierrors.IsAlreadyExists(err) {
		logger.V(1).Info("release already exists")
		return ErrAlreadyExists
	}
	return err
}

func (d *secretDriver) Get(ctx context.Context, devboxName, namespace string) (*Release, error) {
	logger := logr.FromContextOrDiscard(ctx)
	logger.V(1).Info("get release from kubernetes secrets")

	secretName := secretNameFromDevboxName(devboxName)
	secret, err := d.c.CoreV1().Secrets(namespace).Get(ctx, secretName, metav1.GetOptions{})
	if err != nil {
		return nil, err
	}
	return d.extractRelease(secret)
}

func (d *secretDriver) Delete(ctx context.Context, devboxName, namespace string) error {
	logger := logr.FromContextOrDiscard(ctx)
	logger.V(1).Info("delete release from kubernetes secrets")

	name := secretNameFromDevboxName(devboxName)
	secret := corev1.Secret{}
	secret.SetName(name)
	secret.SetNamespace(namespace)

	err := d.c.CoreV1().Secrets(namespace).Delete(ctx, name, metav1.DeleteOptions{})
	if apierrors.IsNotFound(err) {
		logger.V(1).Info("secret not found", "secretName", name)
	}
	if err != nil && apierrors.IsNotFound(err) {
		return err
	}
	return nil
}

const (
	fieldManager = "devbox"
)

func (d *secretDriver) Update(ctx context.Context, devboxName, namespace string, r *Release) error {
	logger := logr.FromContextOrDiscard(ctx)
	logger.V(1).Info("update release on kubernetes secrets")

	secret, err := d.newSecret(devboxName, namespace, r)
	if err != nil {
		return err
	}

	data, err := json.Marshal(secret)
	if err != nil {
		return err
	}
	if _, err := d.c.CoreV1().Secrets(namespace).Patch(ctx, secret.GetName(), types.ApplyPatchType, data, metav1.PatchOptions{
		Force:        util.Pointer(true),
		FieldManager: fieldManager,
	}); err != nil {
		return err
	}
	return nil
}

func (d *secretDriver) List(ctx context.Context, namespace string) ([]*Release, error) {
	logger := logr.FromContextOrDiscard(ctx)
	logger.V(1).Info("get releases to list from kubernetes secrets", namespaceKey, namespace)

	labelSelector := labels.Set{devboxInfoSecretLabalKey: devboxInfoSecretLabalValue}.AsSelector()
	secrets, err := d.c.CoreV1().Secrets(namespace).List(ctx, metav1.ListOptions{
		LabelSelector: labelSelector.String(),
	})
	if err != nil {
		return nil, err
	}

	var releases []*Release
	for _, secret := range secrets.Items {
		r, err := d.extractRelease(&secret)
		if err != nil {
			return nil, err
		}
		releases = append(releases, r)
	}
	return releases, nil
}

func secretNameFromDevboxName(devboxName string) string {
	return fmt.Sprintf("dev.uesyn.devbox.%s", devboxName)
}

func (d *secretDriver) newSecret(devboxName, namespace string, r *Release) (*corev1.Secret, error) {
	name := secretNameFromDevboxName(devboxName)
	labels := map[string]string{
		devboxInfoSecretLabalKey: devboxInfoSecretLabalValue,
	}
	secret := &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Secret",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: namespace,
			Labels:    labels,
		},
	}
	if err := d.setRelease(secret, r); err != nil {
		return nil, err
	}
	return secret, nil
}

func (d *secretDriver) extractRelease(s *corev1.Secret) (*Release, error) {
	if s.Data == nil {
		return nil, errors.New("empty release")
	}
	value, ok := s.Data[releaseContentsKey]
	if !ok {
		return nil, errors.New("empty release")
	}
	r, err := decodeReleaseContents(value)
	if err != nil {
		return nil, fmt.Errorf("failed to decode release contents: %w", err)
	}
	return r, nil
}

func (d *secretDriver) setRelease(s *corev1.Secret, r *Release) error {
	encoded, err := encodeReleaseContents(r)
	if err != nil {
		return fmt.Errorf("failed to encode release:%w", err)
	}
	data := map[string][]byte{
		releaseContentsKey: encoded,
	}
	s.Data = data
	return nil
}

func encodeReleaseContents(r *Release) ([]byte, error) {
	buf := bytes.NewBuffer(nil)
	w := gzip.NewWriter(buf)
	err := json.NewEncoder(w).Encode(r)
	if err != nil {
		return nil, err
	}
	if err := w.Close(); err != nil {
		return nil, err
	}
	encodedData := make([]byte, base64.StdEncoding.EncodedLen(len(buf.Bytes())))
	base64.StdEncoding.Encode(encodedData, buf.Bytes())
	return encodedData, nil
}

func decodeReleaseContents(data []byte) (*Release, error) {
	decoded, err := base64.StdEncoding.DecodeString(string(data))
	if err != nil {
		return nil, err
	}

	reader, err := gzip.NewReader(bytes.NewReader(decoded))
	if err != nil {
		return nil, err
	}
	r := Release{}
	if err := yaml.NewYAMLOrJSONDecoder(reader, 1024).Decode(&r); err != nil {
		return nil, err
	}
	return &r, nil
}
