---
name: kubebuilder
description: |
  Complete guide for building Kubernetes Operators using kubebuilder v4.
  Use this skill when the user wants to create, scaffold, develop, or deploy Kubernetes Operators.
  Covers project initialization, API/CRD definition, controller implementation, webhook configuration,
  testing, and deployment with best practices.
---

# kubebuilder-operator

A comprehensive skill for building production-ready Kubernetes Operators using kubebuilder v4.

## When to Use This Skill

This skill guides you through the entire kubebuilder workflow from initial scaffolding to deployment:
- Creating a new Operator project
- Defining Custom Resource Definitions (CRDs)
- Implementing controllers with reconciliation logic
- Setting up webhooks for validation and mutating
- Writing integration tests
- Building and deploying to Kubernetes clusters

## Prerequisites Check

Before starting, verify these requirements:

1. **Go** (v1.21+): `go version`
2. **kubebuilder** CLI: `kubebuilder version` (v4.x expected)
3. **kubectl** configured: `kubectl version --client`
4. **Docker** (for building images): `docker version`
5. **Kubernetes cluster** (local or remote) for testing

If kubebuilder is not installed:
```bash
# macOS/Linux
curl -L -o kubebuilder "https://github.com/kubernetes-sigs/kubebuilder/releases/download/v4.1.1/kubebuilder_$(go env GOOS)_$(go env GOARCH)"
chmod +x kubebuilder
sudo mv kubebuilder /usr/local/bin/
```

Or via homebrew:
```bash
brew install kubebuilder
```

## Full Workflow

### 1. Initialize Project

Create a new Operator project:

```bash
mkdir my-operator
cd my-operator
kubebuilder init --domain yourorg.com --repo github.com/yourusername/my-operator
```

**Key options:**
- `--domain`: Domain suffix for CRD groups (e.g., `yourorg.com`)
- `--repo`: Go module path (required for v4)
- `--owner`: Copyright owner name

**After init, you'll have:**
- `main.go`: Entry point
- `Makefile`: Build automation
- `PROJECT`: Kubebuilder config file
- `go.mod`: Go module dependencies
- `config/`: Kubernetes manifests

### 2. Create API and Controller

Generate a custom resource type and its controller:

```bash
kubebuilder create api --group mygroup --version v1 --kind MyResource --controller=true --resource=true
```

**Parameters:**
- `--group`: API group (shared across resources)
- `--version`: API version (`v1`, `v2`, `v1alpha1`, etc.)
- `--kind`: Resource kind name (PascalCase)
- `--controller=false`: Skip controller if not needed
- `--resource=false`: Skip CRD if not needed

**Generated files:**
- `api/v1/myresource_types.go`: API type definitions
- `internal/controller/myresource_controller.go`: Controller logic
- `internal/controller/myresource_controller_test.go`: Integration tests

### 3. Define Your API

Edit `api/v1/myresource_types.go` to define the spec and status:

```go
// MyResourceSpec defines the desired state of MyResource
type MyResourceSpec struct {
    // INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
    // Important: Run "make" to regenerate code after modifying this file

    // +kubebuilder:validation:Required
    // +kubebuilder:validation:MinLength=1
    // Name is the name of something important
    Name string `json:"name"`

    // +kubebuilder:validation:Optional
    // +kubebuilder:default=3
    // Replicas is the number of replicas
    Replicas int32 `json:"replicas,omitempty"`

    // +kubebuilder:validation:Optional
    // Config holds configuration data
    Config map[string]string `json:"config,omitempty"`
}

// MyResourceStatus defines the observed state of MyResource
type MyResourceStatus struct {
    // INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
    // Important: Run "make" to regenerate code after modifying this file

    // Phase is the current phase of the resource
    // +kubebuilder:validation:Enum=Pending;Running;Failed;Succeeded
    Phase string `json:"phase,omitempty"`

    // Conditions represent the latest available observations of the resource
    Conditions []metav1.Condition `json:"conditions,omitempty"`

    // Ready indicates if the resource is ready
    Ready bool `json:"ready,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Namespaced
// +kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Ready",type="boolean",JSONPath=".status.ready"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"
type MyResource struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MyResourceSpec   `json:"spec,omitempty"`
    Status MyResourceStatus `json:"status,omitempty"`
}
```

**Common marker comments:**
- `+kubebuilder:validation:Required`: Field must be populated
- `+kubebuilder:validation:Optional`: Optional field
- `+kubebuilder:default=X`: Default value
- `+kubebuilder:validation:Enum=X;Y;Z`: Allowed values
- `+kubebuilder:validation:MinLength=X` / `MaxLength=X`: String length
- `+kubebuilder:validation:Minimum=X` / `Maximum=X`: Numeric bounds
- `+kubebuilder:resource:scope=Cluster`: Cluster-scoped resource (default: Namespaced)
- `+kubebuilder:printcolumn`: Add fields to `kubectl get` output

Regenerate code after editing:
```bash
make generate
make manifests
```

### 4. Implement Controller Logic

Edit `internal/controller/myresource_controller.go`:

```go
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Fetch the MyResource instance
    myResource := &mygroupv1.MyResource{}
    if err := r.Get(ctx, req.NamespacedName, myResource); err != nil {
        if errors.IsNotFound(err) {
            // Resource deleted, cleanup is handled by owner references
            return ctrl.Result{}, nil
        }
        log.Error(err, "unable to fetch MyResource")
        return ctrl.Result{}, err
    }

    // Set initial status
    if myResource.Status.Phase == "" {
        myResource.Status.Phase = "Pending"
        if err := r.Status().Update(ctx, myResource); err != nil {
            return ctrl.Result{}, err
        }
    }

    // TODO: Implement your reconciliation logic here
    // 1. Create/update child resources
    // 2. Update status based on child resource states
    // 3. Handle deletion/finalizers if needed

    // Set resource as ready when reconciliation succeeds
    myResource.Status.Ready = true
    myResource.Status.Phase = "Running"
    meta.SetStatusCondition(&myResource.Status.Conditions, metav1.Condition{
        Type:               "Ready",
        Status:             metav1.ConditionTrue,
        ObservedGeneration: myResource.GetGeneration(),
        Reason:             "ReconciliationSuccessful",
        Message:            "Resource has been successfully reconciled",
    })

    if err := r.Status().Update(ctx, myResource); err != nil {
        return ctrl.Result{}, err
    }

    return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}
```

**Reconciliation pattern:**
1. Get the requested resource
2. Handle not-found (resource was deleted)
3. Fetch related resources
4. Create/update child resources
5. Update status
6. Return result with optional requeue

**Key utilities:**
- `controllerutil.SetControllerReference()`: Establish ownership for garbage collection
- `r.Create()`, `r.Update()`, `r.Patch()`: Resource operations
- `r.Status().Update()`: Update status subresource
- `ctrl.Result{RequeueAfter: duration}`: Periodic reconciliation
- `ctrl.Result{Requeue: true}`: Retry immediately on error

### 5. Add Webhooks (Optional)

For validation and defaulting:

```bash
kubebuilder create webhook --group mygroup --version v1 --kind MyResource --defaulting --programmatic-validation
```

Implement in `api/v1/myresource_webhook.go`:

```go
//+kubebuilder:webhook:path=/mutate-mygroup-yourorg-com-v1-myresource,mutating=true,failurePolicy=fail,sideEffects=None,groups=mygroup.yourorg.com,resources=myresources,verbs=create;update,versions=v1,name=myresource.kb.io,admissionReviewVersions=v1

var _ webhook.Defaulter = &MyResource{}

// Default applies default values
func (r *MyResource) Default() {
    if r.Spec.Replicas == 0 {
        r.Spec.Replicas = 1
    }
}

//+kubebuilder:webhook:path=/validate-mygroup-yourorg-com-v1-myresource,mutating=false,failurePolicy=fail,sideEffects=None,groups=mygroup.yourorg.com,resources=myresources,verbs=create;update,versions=v1,name=vmyresource.kb.io,admissionReviewVersions=v1

var _ webhook.Validator = &MyResource{}

// ValidateCreate validates create operations
func (r *MyResource) ValidateCreate() (admission.Warnings, error) {
    if r.Spec.Name == "" {
        return nil, errors.New("name is required")
    }
    return nil, nil
}

// ValidateUpdate validates update operations
func (r *MyResource) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
    return r.ValidateCreate()
}

// ValidateDelete validates delete operations
func (r *MyResource) ValidateDelete() (admission.Warnings, error) {
    return nil, nil
}
```

### 6. Generate Manifests

Generate Kubernetes manifests:

```bash
make manifests
```

This creates/updates:
- `config/crd/bases/*.yaml`: CRD definitions
- `config/rbac/*.yaml`: RBAC configurations
- `config/manager/manager.yaml`: Operator deployment manifest
- `config/webhook/*.yaml`: Webhook configurations (if applicable)

### 7. Install and Run Locally

Install CRDs to your cluster:
```bash
make install
```

Run the operator locally (for development):
```bash
make run
```

The operator will use your current kubectl context.

### 8. Write Tests

Integration tests in `internal/controller/myresource_controller_test.go`:

```go
var _ = Describe("MyResource Controller", func() {
    Context("When reconciling a resource", func() {
        It("should successfully reconcile the resource", func() {
            ctx := context.Background()
            
            // Create the resource
            myResource := &mygroupv1.MyResource{
                ObjectMeta: metav1.ObjectMeta{
                    GenerateName: "test-resource-",
                    Namespace:    "default",
                },
                Spec: mygroupv1.MyResourceSpec{
                    Name:     "test",
                    Replicas: 1,
                },
            }
            
            By("creating the resource")
            Expect(k8sClient.Create(ctx, myResource)).Should(Succeed())
            
            By("waiting for reconciliation")
            Eventually(func() string {
                fetched := &mygroupv1.MyResource{}
                err := k8sClient.Get(ctx, client.ObjectKeyFromObject(myResource), fetched)
                if err != nil {
                    return ""
                }
                return fetched.Status.Phase
            }, time.Second*30, time.Second).Should(Equal("Running"))
            
            // Cleanup
            Expect(k8sClient.Delete(ctx, myResource)).Should(Succeed())
        })
    })
})
```

Run tests:
```bash
make test
```

### 9. Build and Deploy

Build the container image:
```bash
make docker-build docker-push IMG=your-registry.com/my-operator:v0.1.0
```

Deploy to cluster:
```bash
make deploy IMG=your-registry.com/my-operator:v0.1.0
```

Uninstall:
```bash
make undeploy
```

## Best Practices

### 1. Idempotency
Controllers must be idempotent. Running reconciliation multiple times should produce the same result.

### 2. Status Subresource
Always use status subresource for status updates to avoid conflicts:
- `+kubebuilder:subresource:status` marker
- Use `r.Status().Update()` not `r.Update()` for status

### 3. Owner References
Set owner references on created child resources for automatic cleanup:
```go
if err := controllerutil.SetControllerReference(parent, child, r.Scheme); err != nil {
    return err
}
```

### 4. Requeue vs Watch
- Use `RequeueAfter` for periodic checking
- Use `Watches()` to watch related resources, not polling

### 5. Logging
Use structured logging:
```go
log.FromContext(ctx).Info("reconciling", "name", req.Name, "namespace", req.Namespace)
```

### 6. Finalizers
For resources requiring cleanup:
```go
if !controllerutil.ContainsFinalizer(resource, myFinalizer) {
    controllerutil.AddFinalizer(resource, myFinalizer)
    return ctrl.Result{}, r.Update(ctx, resource)
}

if resource.ObjectMeta.DeletionTimestamp.IsZero() {
    // Handle deletion
    defer func() {
        controllerutil.RemoveFinalizer(resource, myFinalizer)
        if err := r.Update(ctx, resource); err != nil {
            // Handle error
        }
    }()
}
```

### 7. RBAC
Add RBAC markers for permissions:
```go
//+kubebuilder:rbac:groups=core,resources=configmaps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=events,verbs=create;patch
```

## Common Commands Reference

```bash
# Generate code and manifests
make generate
make manifests

# Install CRDs
make install

# Run locally
make run

# Build Docker image
make docker-build IMG=registry/image:tag

# Deploy to cluster
make deploy IMG=registry/image:tag

# Run tests
make test

# Create API/resource
kubebuilder create api --group GROUP --version VERSION --kind KIND

# Create webhook
kubebuilder create webhook --group GROUP --version VERSION --kind KIND --defaulting --validation=programmatic

# Edit project configuration
kubebuilder edit --multigroup=true
```

## Troubleshooting

### Issue: "kubebuilder not found"
Solution: Install via curl or homebrew (see Prerequisites)

### Issue: "make generate" fails with "no such file"
Solution: Install controller-gen: `make controller-gen`

### Issue: CRD not updated after changing API
Solution: Run `make generate` then `make manifests`, then reinstall with `make install`

### Issue: Controller not reconciling
Solution: Check RBAC permissions and ensure owner references are set correctly

### Issue: Webhooks not working
Solution: Ensure cert-manager is installed in the cluster for webhook certificates

## Resources

- [Kubebuilder Documentation](https://book.kubebuilder.io/)
- [Kubernetes Controller Runtime](https://pkg.go.dev/sigs.k8s.io/controller-runtime)
- [Custom Resource Definitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [Operator SDK](https://sdk.operatorframework.io/)

## Example Workflow

```bash
# 1. Create project
mkdir webapp-operator
cd webapp-operator
kubebuilder init --domain example.com --repo github.com/user/webapp-operator

# 2. Create API
kubebuilder create api --group apps --version v1 --kind WebApp

# 3. Edit api/v1/webapp_types.go with your spec
# 4. Edit internal/controller/webapp_controller.go with logic
# 5. Edit api/v1/webapp_webhook.go with validation (optional)

# 6. Generate code and manifests
make generate
make manifests

# 7. Install and test locally
make install
make run  # In terminal 1
kubectl apply -f config/samples/apps_v1_webapp.yaml  # In terminal 2

# 8. Build and deploy
make docker-build docker-push IMG=registry/webapp-operator:v1.0.0
make deploy IMG=registry/webapp-operator:v1.0.0
```
