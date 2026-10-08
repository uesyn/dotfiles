---
name: k8s-api-conventions
description: Kubernetes API design and implementation conventions distilled from the upstream kubernetes/community API conventions document. Use this skill whenever designing or implementing Kubernetes APIs — creating CRDs/custom resources, authoring Go API types with kubebuilder or controller-gen markers, implementing operators/controllers that write status or emit events, choosing field names, types, defaults, optional/required markers, conditions, or object references, or reviewing Kubernetes API and manifest changes for convention compliance — even if the user doesn't explicitly mention "conventions".
---

# Kubernetes API Conventions

Conventions for the Kubernetes API and APIs in its ecosystem (CRDs, operators,
controllers). Follow them when designing new API types, authoring Go types with
kubebuilder / controller-gen markers, writing controllers, or reviewing such
changes. The goal is consistency: clients, tooling, and RBAC should behave the
same across all Kubernetes-style APIs.

For details this file omits (PATCH types, shortNames/categories, the full
Status kind schema, defaulting vs PUT deep-dive, object reference examples
with controller behavior), read `references/api-conventions.md` — the full
upstream document, which has a table of contents.

## Core model: spec, status, and desired state

- `spec` describes desired state (user intent); `status` describes observed
  state. Controllers write `status` via the `/status` subresource; API servers
  ignore `status` in PUT/POST so read-modify-write cannot clobber it.
- Reconciliation is level-based, not edge-based: drive toward the latest
  `spec`; never assume intermediate values were observed. If a value moves
  2 → 5 → 3 in two PUTs, the system may settle at 3 without "touching" 5.
- Fields in `spec` have declarative names and semantics — they represent
  desired state, not actions yielding it (`SomethingDoer`, `DoneBy` are wrong).
- Types with both `spec` and `status` have no other top-level fields beyond
  `metadata`.
- Give the two stanzas distinct RBAC scopes: users write `spec` (read
  `status`), controllers read `spec` and write `status`.
- `phase` fields are a deprecated pattern — never add them. Use conditions.

## Conditions

Use `metav1.Condition` from k8s.io/apimachinery/pkg/apis/meta/v1 in status:

```go
// +listType=map
// +listMapKey=type
// +patchStrategy=merge
// +patchMergeKey=type
// +optional
Conditions []metav1.Condition `json:"conditions,omitempty" patchStrategy:"merge" patchMergeKey:"type" protobuf:"bytes,1,rep,name=conditions"`
```

- Required fields: `type`, `status` (True/False/Unknown), `lastTransitionTime`,
  `reason` (one-word CamelCase, non-empty), `message` (human-readable). Set
  `observedGeneration` so consumers can tell stale conditions from current.
- Report conditions on the first visit to a resource, even when the status is
  Unknown — absence of a condition is interpreted as Unknown, typically
  "reconciliation has not finished".
- Type names describe the observed state, not transitions: an adjective
  ("Ready", "OutOfDisk") or past-tense verb ("Succeeded", "Failed"), kept short
  ("Ready" over "MyResourceReady"). A transition that takes minutes (e.g.
  "Resizing") may itself be a condition using True/False/Unknown.
- Conditions are observations, not state machines; they may oscillate.

## Designing a kind

- Kind names are CamelCase and singular (`Pod`); resources are lowercase and
  plural (`pods`). List kinds end in `List` and carry the `items` field
  (`PodList`).
- Name the kind after the thing controlled, not `FooController` (`Job`, not
  `JobController`).
- API group: a subdomain you own (`foo.example.com`); never `*.k8s.io` or
  bare single-word groups. Versions match DNS_LABEL (`v1`, `v1beta1`).
- Objects carry `metadata` with `name`, `namespace`, `uid`; treat
  `resourceVersion` and `generation` as opaque system fields.
- Lists of named subobjects, never maps of subobjects:

  ```yaml
  # yes
  ports:
    - name: www
      containerPort: 80
  # no
  ports:
    www:
      containerPort: 80
  ```

  Exceptions (true maps): `labels`, `annotations`, `selectors`, `data`.
  Use `+listType=map` + `+listMapKey=<key>` (+ patchStrategy merge) for
  mergeable lists.
- Unions: when at most one of several fields may be set, make all of them
  optional with no default; validate at-most-one-set. Anticipate future
  members even if only one field exists initially.
- Idempotent creates: POSTing an existing name returns 409 `AlreadyExists`.
  Server-side name generation uses `metadata.generateName` + random suffix;
  clients retry on 409 after waiting per `Retry-After`.

## REST endpoints and verbs

- Standard pattern: GET/POST on `/<plural>`, GET/PUT/DELETE/PATCH on
  `/<plural>/<name>`, `GET /<plural>?watch=true`, plus subresources (`/status`,
  `/scale`, `/binding`).
- PUT is a full replace: omitted fields are cleared, partial updates are not
  accepted, and `status` is ignored. For partial changes use PATCH
  (merge / strategic-merge / JSON patch, selected by Content-Type) or
  server-side apply.
- Watch consumes `resourceVersion` from a prior list to guarantee no mutations
  are missed between list and watch.

## Primitive types

- Integers: `int32` preferred, `int64` when needed; never Go `int` in public
  fields; never unsigned (validate non-negative instead). `int64` fields must
  be bounds-checked within ±(2^53) or serialized as strings (JS `float64`
  loss of magnitude/precision).
- No floating point in spec — floats are not reliably round-trippable.
- Enums are string type aliases with CamelCase values (`ClusterFirst`,
  `ClientIP`); acronyms keep uniform case (`TCP`). Never numeric enums.
- Think twice about `bool`; most ideas grow into a set of mutually exclusive
  options. Prefer a string alias from the start
  (e.g. `TerminationMessagePolicy`).
- Durations: integer seconds with the unit in the field name — `fooSeconds`,
  `fooPeriodSeconds` (intervals), `fooTimeoutSeconds` (inactivity),
  `fooDeadlineSeconds` (completion). Never `metav1.Duration` (requires
  Go-compatible parsing in every client).
- Timestamps: `*metav1.Time`, RFC3339 in JSON; field name `somethingTime`.
- Quantities: `resource.Quantity` (`5Gi`), or make the unit explicit in the
  field name (`timeoutSeconds`).

## Optional vs required (Go markers)

Every field is explicitly `+optional` or `+required`:

```go
// +optional
Replicas *int32 `json:"replicas,omitempty"`
// +required
Name string `json:"name"`
```

- Optional: pointer type or native-nil type (map/slice), `omitempty` tag,
  `+optional` marker. Readers cannot rely on it unless a default exists.
- Required: `+required` marker, typically non-pointer; the zero value is
  usually not valid.
- Use a pointer when the zero value is a valid user choice and intent matters:
  `bool` fields are always `*bool` + `omitempty` (`false` is a valid choice).
- Need to distinguish "unset" from "empty" on a map/slice → `*[]T` / `*map[K]V`.
- Structs with only optional fields: consider `omitzero` to avoid marshalling
  the zero value.
- For CRDs: where the zero value is invalid, OpenAPI validation rejects it
  before any controller observes the object, so plain non-pointer types are
  safe and avoid nil-pointer risks.
- Avoid `+nullable`: it breaks JSON merge patch, proto serialization, and
  server-side apply. Don't design APIs that need to distinguish unset from
  `null`.

## Defaulting

Defaults are explicit in the API (not "unspecified = default behavior") so they
can evolve per API version and stored objects depict the full desired state.
Three mechanisms:

1. **Static** — `+default=` tag, applied synchronously by the API server per
   version. Best for values that are logically required and work well for most
   users. Derived defaults (from other fields) turn into the user's update
   problem — avoid when possible.
2. **Admission-controlled** — for defaults depending on other objects/cluster
   state (e.g. default StorageClass). Fields must stay optional.
3. **Late initialization** — controllers set fields after the call (e.g. the
   scheduler sets `pod.spec.nodeName`). Fields must stay optional; use
   patch/apply so controllers don't clobber each other.

All defaulting may only: set previously unset fields, add map keys, and add
values to mergeable lists. Never override user-provided values — invalid input
gets an error, not a silent correction.

When adding a field with a default, remember `kubectl replace` (PUT): PUT of
an old object can try to change the field to the new default even though the
user never specified it. Prefer patching the old value into the new object
when the field is unset, rather than erroring or reallocating.

## Concurrency

- Optimistic concurrency via `resourceVersion`: treat it as opaque, pass it
  back unmodified, never parse or compare it. It has no meaning across
  namespaces, kinds, or servers.
- On update conflict (409 `Conflict`): GET fresh, re-apply the change, retry
  with the new `resourceVersion`.
- Use `generation` / `observedGeneration` for level-based progress reporting.

## Object references

- Namespaced types should reference only same-namespace objects — namespaces
  are a security boundary. Built-in types and `ownerReferences` never support
  cross-namespace references; if a custom API allows them, document the
  semantics and handle permissions (double opt-in or admission checks).
- Field naming: `{purpose}Ref` / `{purpose}Refs` for object references
  (`secretRef`, `targetRef`); `{kind}Name` (e.g. `fooName`) for by-name refs.
- Field paths use JS-style syntax without a leading dot: `metadata.name`,
  `fields[1].state.current`.

Schemas (purely additive as referencable types grow):

```yaml
# single resource reference
secretRef:
  name: foo            # namespace omitted / discouraged
# multiple resource reference (bounded set of types)
fooRef:
  group: sns.services.k8s.aws
  kind: Topic          # or `resource: topics` — prefer resource
  name: foo
# generic object reference (arbitrary types; no version)
fooObjectRef:
  group: operator.openshift.io
  resource: openshiftapiservers
  name: cluster
# field reference (extract a value; version required)
fooFieldRef:
  version: v1
  resource: configmaps
  fieldPath: data.foo
```

- Prefer `resource` over `kind`: (group, resource) is unique in Kubernetes,
  (group, kind) is not. `kind` is acceptable only with a hard-coded
  kind→resource mapping (built-ins, Ingress backends); never rely on dynamic
  mapping.
- Controller duties around references:
  - Validate referenced fields before using them as API path segments (block
    `..`, `/`), and emit an event when validation fails.
  - Assume the referenced resource may not exist or may change version; make
    errors clear to the user.
  - Do not modify the referred object (limit writes to e.g. the `/scale`
    subresource).
  - Do not copy values from the referred object into the referrer's
    status/spec, other objects, or events — that leaks data the object author
    may not be allowed to read.

## Controller behavior

- Write only your own status, via the `/status` subresource.
- Set conditions on first visit, even Unknown.
- Emit events for situations users or administrators should know about.
  Reason: unique, specific, short, CamelCase (`FreeDiskSpaceInvalid` yes,
  `Started` no). Message: `"Error creating foo %s"` beats `"Error creating foo"`.
- Use `ownerReferences` for garbage collection / ownership; ownership never
  crosses namespaces.

## Naming quick reference

| Rule | Example |
|---|---|
| Go fields PascalCase, JSON camelCase, no underscores/dashes | `terminationGracePeriodSeconds` |
| Declarative field names | `DesiredReplicas`, not `ReplicasDoer` |
| Time when something occurs | `creationTimestamp`, `somethingTime` (never `stamp`) |
| Durations in seconds | `timeoutSeconds`, `periodSeconds`, `deadlineSeconds` |
| No abbreviations | except extremely common: `id`, `args`, `stdin` |
| Acronyms keep uniform case | `httpGet`, `TCP`, `IPVS` |
| By-name reference | `fooName` |
| Object reference | `fooRef` / `fooRefs` |
| Boolean property | `Fooable`, not `IsFooable` |
| Node vs Host | `Node` = cluster resource; `Host` = physical/virtual machine props (`hostPath`, `hostNetwork`) |

## Labels, annotations, and generic map keys

- Labels are for users to organize and select resources; the system provides
  conveniences (e.g. default selectors from pod templates) but never requires
  system prefixes in user label keys. Ensure uniqueness via one distinctive
  label value (name, uid, generation — generation is the most predictable).
- Annotations are for tooling and system extensions. Third-party components
  MUST prefix keys with a domain they own (`example.com/key-name`);
  unprefixed keys are reserved for end-users; `kubernetes.io` / `k8s.io`
  prefixes are reserved for Kubernetes. Annotations may carry arbitrary
  payloads including JSON.
- Never represent new API fields as annotations (deprecated
  `something.alpha.kubernetes.io/name` pattern) — new fields are real fields.
- Key naming: lowercase with dashes (`desired-replicas`, not `DesiredReplicas`).

## Client handling of API responses

- Errors always return the `Status` kind with a machine-readable, one-word
  CamelCase `reason` (`NotFound`, `AlreadyExists`, `Conflict`, `Invalid`, ...).
- 409 on create → already exists (change the name or GET-and-update); on
  update → GET, merge, retry with `resourceVersion`.
- 422 `Invalid` → fix the request, do not retry. 4xx generally → don't retry.
- 429 / 500 / 503 / 504 → retry with exponential backoff, honoring
  `Retry-After` when present.
