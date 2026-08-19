# Ballerina Trigger Construct Spec: Format Specification (v1.0)

| Field | Value |
|---|---|
| Spec version | v1.0 |
| Author | Lakshan Weerasinghe (WSO2) |
| Last revised | 2026-08-11 |
| Reviewed by | Not yet reviewed |

Field reference for the JSON shape in `examples/*.json`. `spec.json` is the machine-checkable
schema; an instance must validate against it. `README.md` covers the why.

Top-level keys:

| Key | Presence | Contents |
|---|---|---|
| `version` | required | Spec version this instance conforms to, such as `"v1.0"`. Section 11. |
| `listeners` | required | Listener entry points. |
| `serviceTypes` | required | Service type alternatives this connector exposes. |
| `annotations` | optional | Annotation types referenced elsewhere, defined once. |
| `rules` | optional | Constraints spanning more than one service type. Single service type rules live on their `serviceTypes[]` entry. |

**General rule:** a field that would be empty, unused, or derivable from other fields is left out.
Never an empty array, null, or default placeholder.

---

## 0. Ids

Every construct that a file's own contents can point back into carries an id:
`listeners[]`, `serviceTypes[]`, `handlers.options[]`, `params[]`, a handler's return type,
`annotations[]`, and `rules[]`. Every id starts with `$`, and so does every reference to one.

```json
"id": "$serviceConfig"
"annotations": ["$serviceConfig"]
```

The prefix keeps an id reference from reading like anything else. Other values in this file are
Ballerina identifiers, type names, enum values, and free text, and a bare id looks like all of
them. `"services": ["$service"]` is clearly a pointer into `serviceTypes[]`.

Ids are scoped per construct kind and every reference site names the kind it targets, so `$` alone
is enough. No per kind sigil.

**Flat vs. hierarchical.** `listeners[]`, `annotations[]`, and `rules[]` are flat, top level lists,
so their ids are single segments: `$serviceConfig`, `$listener`. A handler, its return type, and
its params nest inside one `serviceTypes[]` entry, so their ids are hierarchical: dot separated
segments that scope the id under its owner, built by appending the child's own name to the
parent's id.

```
$service                    serviceTypes[] entry
$service.onMessage          handlers.options[] entry on $service
$service.onMessage.returns  the return type of $service.onMessage
$service.onMessage.records  a param of $service.onMessage
```

A handler backed by a concrete type has no `options[]` entry to carry an id at all — its
methods are introspectable by name, so there is nothing here to reference. Hierarchical ids
therefore only ever appear under a non concrete service type.

`role` labels (section 6.1) and the handler/param `name` fields are not ids and are never
prefixed with `$` — `name` is what gets emitted as Ballerina source, `id` is only for
cross-referencing within this file.

---

## 1. `TypeRef`

A type reference is a **tree**, never a type expression in a string. A node is either a plain
`name`, or a constructed type given by `shape` plus the parts that shape is built from.

```json
{ "name": "Caller" }
{ "shape": "array", "elementType": { "name": "byte", "builtin": true } }
```

| Field | Meaning |
|---|---|
| `name` | A named type. Mutually exclusive with `shape`. |
| `packageInfo` | Only alongside `name`, and only for a type from another module. |
| `builtin` | Only alongside `name`. `true` when `name` is one of Ballerina's own language types. Absent, never `false`, for a module type. Section 1.3. |
| `subtypeFamily` | Only alongside `name`. `true` when this reference stands for the named type and every introspectable subtype of it, not the exact type alone. Meaningful inside `dataBinding`. Section 1.4. |
| `shape` | How a constructed type is built. Section 1.1. |
| `elementType` | The type the shape holds. |
| `completionType` | `stream` only, and optional. |

A `name` is unqualified and belongs to the module this file describes. A consumer already knows
which module that is from wherever it obtained the file, so it is not restated here. `()` is nil and
`record {}` is an open record; both are atomic names.

**Unions** are an array of `TypeRef`, first element being the codegen default. **Nilable** `T?` is an
explicit `()` union member rather than a flag, so a union is also how a nilable part appears:

```json
"type": [{ "name": "AnydataConsumerRecord" }, { "name": "BytesConsumerRecord" }]
"returns": [{ "name": "error", "builtin": true }, { "name": "()", "builtin": true }]
```

### 1.1 Shapes

| `shape` | `elementType` | `completionType` | Ballerina |
|---|---|---|---|
| `array` | the element | not applicable, an array terminates with nothing | `T[]` |
| `stream` | the value | optional, what the stream terminates with | `stream<T>`, `stream<T, C>` |
| `readonly` | the intersected type | not applicable, an intersection terminates with nothing | `readonly & T` |

```json
{ "shape": "array", "elementType": { "name": "byte", "builtin": true } }
{ "shape": "array", "elementType": { "shape": "array", "elementType": { "name": "string", "builtin": true } } }
{ "shape": "stream", "elementType": { "name": "anydata", "builtin": true }, "completionType": [{ "name": "Error" }, { "name": "()", "builtin": true }] }
{ "shape": "readonly", "elementType": { "shape": "array", "elementType": { "name": "byte", "builtin": true } } }
```

which are `byte[]`, `string[][]`, `stream<anydata, Error?>`, and `readonly & byte[]`.

**Why a discriminator rather than a key per kind.** A field named `arrayOf` or `streamOf` makes
every new composite kind a new field, so `map<T>` could not be expressed without changing this
schema. With `shape` naming the kind, a new kind is a new `shape` value and a row in the table
above, reusing `elementType` where it fits and adding a part only where the kind genuinely has one.
Under section 11.1 that is additive.

`shape` is closed, unlike the rule registry in section 6.2. An unrecognised rule can be skipped and
the rest of the manifest still used; an unrecognised type shape cannot, because the type could not
be written at all, so it should fail loudly rather than silently.

**Why a tree at all.** Every type inside a composite is itself a `TypeRef`, so it can carry its own
`packageInfo` and be qualified independently. As a string, `"stream<anydata, Error?>"` gave a
consumer nothing to attach a module to: the `Error` was invisible, and qualifying whole names
produced `grpc:stream<anydata, Error?>` or left `Error` bare, neither of which resolves.

### 1.2 Qualifying a name for output

Names carry no module prefix, because the prefix depends on the alias the reader's file chose for
its import. A consumer emitting Ballerina adds it: the alias for the described module on an
unqualified leaf, and `packageInfo.moduleName` on a cross module one. With the tree this is a
decision per leaf rather than string surgery:

| `TypeRef` | Renders as, when the described module is `grpc` |
|---|---|
| `{ "name": "Caller" }` | `grpc:Caller` |
| `{ "name": "anydata", "builtin": true }` | `anydata`, a language type, never qualified |
| `{ "streamOf": {"name":"anydata","builtin":true}, "completion": [{"name":"Error"},{"name":"()","builtin":true}] }` | `stream<anydata, grpc:Error?>` |
| `{ "streamOf": {"arrayOf":{"name":"string","builtin":true}}, "completion": [{"name":"error","builtin":true},{"name":"()","builtin":true}] }` | `stream<string[], error?>` |

Whether a leaf is a language type or a module type decides how a consumer qualifies it, section
1.2, so it is a fact the consumer needs and `builtin` states it directly rather than leaving it to
be inferred. Case is a reliable authoring convention in the corpus, `Error` is the module's error
subtype and `error` is the language's, but a consumer should read `builtin` rather than pattern
match on casing.

### 1.3 `builtin`

```json
{ "name": "anydata", "builtin": true }
{ "name": "error", "builtin": true }
{ "name": "Error" }
```

`builtin` is `true` only on Ballerina's own language types: the basic types (`int`, `float`,
`decimal`, `string`, `boolean`, `byte`), `anydata`, `any`, `error`, `()`, `record {}`, `json`,
`xml`, `map`, `table`, and similarly. It is absent, never `false`, on every module type, following
the same leave it out rule as everywhere else in this file.

**Why this is stated rather than left to introspection.** Every other fact in this file earns its
place by being something introspection cannot recover, section 4 of `README.md`. Ballerina's set of
language types is technically fixed and could be hardcoded by a consumer, but hardcoding a second
copy of that set in every consumer, kept in sync by hand as the language adds one, is worse than a
one bit flag stated once per leaf. So `builtin` is metadata for convenience, not for
non-introspectability, the one field in this schema justified that way.

### 1.4 `subtypeFamily`

A `dataBinding` variant's `constraint` and `excludes`, and a `shapes[].envelope`, are all
`TypeRef`s that describe a **relationship** a declared type must satisfy, not a type to declare
verbatim. `subtypeFamily` says that relationship is "is a subtype of", open ended over every
subtype the named type's own module declares, rather than "is exactly this type."

HTTP is the worked case. A resource may return a subtype of `http:StatusCodeResponse`, such as the
built-in `http:Ok`/`http:Created`/`http:BadRequest` family or a user's own narrowing of one of
them, and whichever is declared has its `body` field bound the same way `AnydataConsumerRecord`'s
`value` field is, section 9:

```json
"returns": {
  "id": "$service.resource.returns",
  "type": [
    { "name": "anydata", "builtin": true },
    { "name": "Response" },
    { "name": "StatusCodeResponse", "subtypeFamily": true },
    { "name": "error", "builtin": true }
  ],
  "dataBinding": {
    "typedescs": [
      {
        "constraint": { "name": "anydata", "builtin": true },
        "excludes": [{ "name": "StatusCodeResponse", "subtypeFamily": true }],
        "shapes": [{ "form": "bare" }]
      },
      {
        "constraint": { "name": "anydata", "builtin": true },
        "shapes": [{ "form": "included", "envelope": { "name": "StatusCodeResponse", "subtypeFamily": true }, "bindableFields": ["body"] }]
      }
    ]
  }
}
```

Without `subtypeFamily` the only way to say this would be one `typedescs[]` entry per concrete
subtype, `http:Ok`, `http:Created`, and every other status code response, plus every user defined
narrowing, none of which this file could ever enumerate since user narrowings do not exist until a
consumer's own generation session creates one. `subtypeFamily` names the module's own type instead
and leaves "which subtypes exist" to introspection, the same trade `builtin` makes for the
language's fixed type set, only here the set is genuinely open rather than fixed.

`excludes` reads the same way it always has, disambiguating the same declared type from satisfying
two variants at once, section 9, except now the exclusion is a whole family: a user record that
happens to be a subtype of `StatusCodeResponse` is excluded from the `bare` variant regardless of
which subtype it is, not only when it is `StatusCodeResponse` itself.

---

## 2. `listeners[]`

```json
{
  "id": "$listener",
  "doc": "Polls the configured broker connection and dispatches each batch to the attached service.",
  "type": { "name": "Listener" },
  "services": ["$service"],
  "multipleServicesAllowed": true,
  "multipleServicesOfSameTypeAllowed": true,
  "requiredImports": [
    { "importType": "driver", "packageInfo": { "org": "ballerinax", "packageName": "mssql.cdc.driver", "moduleName": "mssql.cdc.driver", "version": "1.0.2" } }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | **Required.** Flat, since a listener nests inside nothing. `$listener`, or `$listener1`/`$listener2` when a connector declares more than one. |
| `doc` | **Required.** What this listener is and when a service attaches to it. Section 5.2 explains why this is required unconditionally rather than only when introspection cannot recover it. |
| `type` | `TypeRef` for the listener class. |
| `deprecated` | Optional. Section 5.3. |
| `services` | `serviceTypes[].id` values this listener can host. |
| `multipleServicesAllowed` | Can one instance of this listener host more than one service at all? |
| `multipleServicesOfSameTypeAllowed` | Can two of those services be of the same service type? Omitted when `multipleServicesAllowed` is `false`. Absent means unconstrained. |
| `requiredImports` | Optional. Side effect only imports such as `import ballerinax/mssql.cdc.driver as _;` that nothing references by name. |
| `platformDependencies` | Optional. Native dependencies, below. |

Listener init fields are never modeled, they are introspectable. There is no `presence` field, a
listener is always required.

### 2.1 `platformDependencies`

`requiredImports` covers Ballerina packages. Some connectors also need a native jar the build
cannot fetch at all, such as SAP JCo, whose licence forbids publishing `sapjco3.jar` publicly.
This mirrors the `[[platform.<javaVersion>.dependency]]` table in `Ballerina.toml`.

```json
"platformDependencies": [
  {
    "groupId": "com.sap",
    "artifactId": "com.sap.conn.jco",
    "version": "3.1.*",
    "scope": "provided",
    "acquisition": {
      "url": "https://support.sap.com/en/index.html",
      "note": "Download sapjco3.jar from the SAP Service Marketplace, with the native library for each OS you deploy to."
    },
    "nativeLibraries": [
      { "os": "linux", "file": "libsapjco3.so" },
      { "os": "windows", "file": "sapjco3.dll" },
      { "os": "macos", "file": "libsapjco3.dylib" }
    ]
  }
]
```

| Field | Meaning |
|---|---|
| `groupId`, `artifactId`, `version` | Maven coordinates. `version` may be a wildcard such as `3.1.*`. |
| `scope` | `"provided"` keeps the jar compile time only, for example when a licence forbids bundling it. Absent means bundled. |
| `acquisition` | How to get an artifact no public repository serves. `url` is machine actionable, `note` carries the instructions. |
| `nativeLibraries` | OS specific libraries needed at run time. |

`nativeLibraries` is modeled separately because a missing native library is not a build failure.
The package compiles and the service then fails at run time. Nothing in the build graph records
the requirement, which is exactly what this metadata exists to carry.

Where the library must go is determined by `os`, so it is stated once here instead of on every
entry:

| `os` | Discoverable via |
|---|---|
| `linux` | `LD_LIBRARY_PATH` |
| `windows` | `PATH` |
| `macos` | `DYLD_LIBRARY_PATH` |

No `path` field, that is the user's own download location. No `javaVersion` key, the generator
knows the Java version of the distribution it targets.

---

## 3. `serviceTypes[]`

```json
{
  "id": "$service",
  "doc": "Consumes messages from the subscribed topics/queue and dispatches each poll's batch.",
  "type": { "name": "Service" },
  "concrete": false,
  "multipleListenersAllowed": true,
  "annotations": ["$serviceConfig"],
  "identifier": { "presence": "optional", "form": ["stringLiteral"] },
  "handlers": { }
}
```

| Field | Meaning |
|---|---|
| `id` | **Required.** Referenced from `listeners[].services` and sibling constructs. Also the hierarchy root for this type's `handlers.options[]` and their `params[]`, section 0. |
| `doc` | **Required**, even when `concrete` is `true`. What this service type is for. Unlike handler `doc` (section 5.2), this is required unconditionally: id and doc together are what make every top level construct in the file navigable on its own, not only what introspection cannot recover. |
| `type` | `TypeRef` for the service object type. |
| `concrete` | `true` when the type declares its own methods and they can be introspected. `false` for a marker or abstract type. |
| `multipleListenersAllowed` | Can one service attach to more than one listener at once, as in `service X on l1, l2 {}`? |
| `deprecated` | Optional. Section 5.3. |
| `annotations` | Ids of annotations with `attachPoint: "service"`. Section 8. |
| `identifier` | Omit entirely when the identifier slot carries no meaning. `form` values: `basePath`, `stringLiteral`. |
| `handlers` | Section 4. |
| `rules` | Optional. Section 6. |

No `presence` field. One entry means required, several entries mean each is individually optional
and the choice comes from whatever supplied the generation intent.

When a connector really does require at least one of several handlers, that is a `rules[]` entry,
not a `presence` marker. See `structure.atLeastOne` in section 6.2.

**Error handlers never count.** A service whose only handler is `onError` receives nothing and does
nothing, so every service type must require at least one handler that actually processes input.
Where one processing handler is always mandatory, `presence: "required"` on that handler says it.
Where any one of several will do, a `structure.atLeastOne` rule over the processing handlers says
it, with the error handler left out of the subjects.

### 3.1 Attachment cardinality

Three facts decide what may attach to what. Two live on the listener, because they describe the
listener instance, and one lives on the service type.

| Question | Field | On |
|---|---|---|
| Which service types may this listener host at all? | `services` | listener |
| May one listener instance host more than one service? | `multipleServicesAllowed` | listener |
| May two of those be the same service type? | `multipleServicesOfSameTypeAllowed` | listener |
| May one service attach to several listeners at once? | `multipleListenersAllowed` | service type |

SAP JCo is the worked case for the middle two. One `jco:Listener` hosts both `IDocService` and
`RfcService`, so `multipleServicesAllowed` is `true`, but a second service of either type on the
same listener is an error, so `multipleServicesOfSameTypeAllowed` is `false`:

```json
{
  "type": { "name": "Listener" },
  "services": ["$idocService", "$rfcService"],
  "multipleServicesAllowed": true,
  "multipleServicesOfSameTypeAllowed": false
}
```

The reason is that neither type has an identifier, so two `IDocService` declarations would leave
inbound dispatch ambiguous. Where a service type does carry an identifier, as HTTP and GraphQL do
with a base path, two instances are distinguishable and repeating is allowed.

`multipleServicesOfSameTypeAllowed` is omitted when `multipleServicesAllowed` is `false`, since one
service at most already rules it out.

---

## 4. `handlers`

```json
"handlers": { "backedByConcreteType": false, "options": [ ] }
```

A concrete backed type says nothing further, so `options` is omitted too:

```json
"handlers": { "backedByConcreteType": true }
```

| Field | Meaning |
|---|---|
| `backedByConcreteType` | `true` means the type's own methods are the handlers, so introspection already answers everything this file could say. `false` means `options` is the only source of truth. |
| `options` | Only when `backedByConcreteType` is `false`. Section 5. |

Whether a handler is a fixed name or a repeatable shape is a property of that handler, not of the
block, so it lives on each option as `addMode`. Section 5.1.

---

## 5. `handlers.options[]`

```json
{
  "id": "$service.onConsumerRecord",
  "name": "onConsumerRecord",
  "kind": "remote",
  "doc": "Invoked with each batch of records polled from the subscribed topics.",
  "presence": "required",
  "annotations": ["$functionConfig"],
  "params": [ ],
  "returns": {
    "id": "$service.onConsumerRecord.returns",
    "type": [{ "name": "error", "builtin": true }, { "name": "()", "builtin": true }]
  }
}
```

| Field | Meaning |
|---|---|
| `id` | **Required.** Hierarchical: the owning `serviceTypes[].id` plus this handler's `name`. Section 0. |
| `name` | Under `subset`, the method name to emit. Under `many`, always `"*"`, since the user names each instance. |
| `kind` | `"remote"` or `"resource"`. |
| `addMode` | `subset` (default when absent) or `many`. Section 5.1. |
| `doc` | **Required.** What this handler is for and when it fires. Section 5.2. |
| `deprecated` | Optional. Section 5.3. |
| `presence` | Only under `addMode: "subset"`. A `many` shape has no fixed occurrence count to require. |
| `annotations` | Ids of annotations with `attachPoint: "function"`. |
| `returns` | The return type, grouped like a `param`. Section 5.4. |

A `resource` handler is identified by its accessor and path, matching the language form
`resource function <accessor> <path>()`. Both are required for `kind: "resource"` and neither
applies to `kind: "remote"`.

| Field | Shape | Meaning |
|---|---|---|
| `accessor` | `{ presence, values }` | The legal accessors. HTTP puts its verbs here, GraphQL puts `get` or `subscribe`. |
| `path` | `{ presence }` | Whether a path is required. No syntactic form is recorded, since the language already fixes what a resource path may look like. |

`values` is a fixed set, or a single `"*"` meaning any accessor the language accepts:

```json
"accessor": { "presence": "required", "values": ["get", "post", "put", "delete"] }
"accessor": { "presence": "required", "values": ["*"] }
```

These two fields are deliberately library neutral. HTTP calls its accessor a method and GraphQL
calls its path a field name, but both are the same two positions in the same language construct,
so the schema names them once. GraphQL's operation kind is not recorded either, since it follows
from what is already there: a query is `resource` with accessor `get`, a subscription is `resource`
with accessor `subscribe`, and a mutation is `remote`.

### 5.1 `addMode`

`addMode` says whether an option is one fixed method or a shape the user repeats.

| Value | Meaning | `name` is | `presence` |
|---|---|---|---|
| `subset` (default) | One fixed method name. The user declares it or does not. | The method name to emit. | Applies. |
| `many` | A shape the user instantiates any number of times under names of their own choosing. | Always `"*"`. | Does not apply. |

It sits on the option rather than on `handlers` because the two can coexist. A service type may
offer fixed lifecycle handlers alongside open user named ones, and a block level flag cannot say
that.

A `many` option is always named `"*"`. The user picks the real name, so there is none to record.

```json
{ "name": "*", "kind": "remote", "addMode": "many" }
```

One service type may carry several `"*"` options when it offers several distinct shapes. gRPC has
four, one per RPC kind, and GraphQL has three, one per operation. They are told apart by their
params, returns, and `doc`, not by their name.

### 5.2 `doc`

Everywhere else the rule is: if introspection recovers it, leave it out. Docs invert that, but only
for the non concrete case, and for the same reason. A handler backed by a concrete type has a real
method with a real doc comment, so its docs are introspectable and are not restated here. A handler
described in `options[]` has no such method, so there is no doc comment to read.

| `backedByConcreteType` | `doc` |
|---|---|
| `true` | There are no `options`, so the question does not arise. Introspect the methods. |
| `false` | Required. It is the only description a generator or agent will see. |

Because `options` exists only when `backedByConcreteType` is `false`, every handler written here is
non concrete by construction. So `doc` is simply required, with no condition attached, and the same
holds for `params[].doc`.

On a `many` slot the doc describes what one occurrence is, which is the only place that gets said:
an HTTP `*` handler has two `many` params distinguished otherwise only by their annotation.

### 5.3 `deprecated`

A string saying why. Attaches to `listeners[]`, `serviceTypes[]`, `handlers.options[]`, and
`params[]`, the four constructs a library can retire while still accepting.

```json
"deprecated": "Superseded by the typed content handlers, which deliver the file body already bound to a declared type."
```

Presence of the field is the deprecation; the value is the explanation. There is no `since` or
`replacement`, since the reason can name a version or a successor in the sentence itself if either
matters.

**The reason is written to be read.** A generator emitting Ballerina puts it in the construct's
`# # Deprecated` doc section, beside the `@deprecated` annotation, which is where the language
expects the explanation to live:

```ballerina
# Invoked once per poll with the files added and deleted since the previous poll.
#
# # Deprecated
# Superseded by the typed content handlers, which deliver the file body already bound to a
# declared type.
@deprecated
remote function onFileChange(ftp:WatchEvent event) returns error? {
}
```

So write it as a sentence a user should see. It is separate from `doc`: `doc` says what the
construct does, `deprecated` says why not to use it.

A deprecated handler still counts for `structure.atLeastOne`. It remains legal, just not
recommended, so a service satisfying the rule with only a deprecated handler is valid.

### 5.4 `returns`

A return, when present, is grouped into one object rather than three sibling fields, the same
reasoning that gives a `param` its own object instead of flattening `type`/`dataBinding` onto the
handler:

```json
"returns": {
  "id": "$service.resource.returns",
  "type": [{ "name": "anydata", "builtin": true }, { "name": "Response" }, { "name": "error", "builtin": true }],
  "dataBinding": {
    "typedescs": [{ "constraint": { "name": "anydata", "builtin": true }, "shapes": [{ "form": "bare" }] }]
  },
  "annotations": ["$cache"]
}
```

| Field | Meaning |
|---|---|
| `id` | **Required.** Hierarchical: the handler's `id` plus the fixed segment `returns`, for example `$service.resource.returns`. Section 0. |
| `type` | **Required.** `TypeRef` or a union. |
| `dataBinding` | Optional. Present only when one union member is a user declared subtype the runtime serializes out, such as HTTP's `anydata` response branch. Section 9.1. |
| `annotations` | Optional. Ids of annotations with `attachPoint: "return"`. |

No `name` and no `presence`: a return has no identifier to emit and is not itself optional the way
a param slot can be absent, so `param`'s two constructs that exist for those reasons are left out
here. `returns` is omitted entirely when a handler's language form forbids a return clause, as the
`file` connector's handlers do.

---

## 6. `rules[]`

A rule is referenced, never defined here. `rule` names a constraint from an open registry the
consumer already implements and `subjects` say what it ranges over. Adding
a constraint is a new registry entry, not a schema change.

```json
{
  "id": "$queueNameSource",
  "rule": "structure.exactlyOne",
  "message": "A RabbitMQ consumer needs its queue name from exactly one source: @rabbitmq:ServiceConfig { queueName } or the service identifier.",
  "subjects": [
    { "role": "fromAnnotation", "kind": "annotationField", "annotation": "$serviceConfig", "path": ["queueName"] },
    { "role": "fromIdentifier", "kind": "identifier" }
  ],
  "prefer": "fromAnnotation"
}
```

| Field | Meaning |
|---|---|
| `id` | Stable and unique within the file. Surfaces in the emitted diagnostic. |
| `rule` | Registry id. Open vocabulary, section 6.2. |
| `subjects` | What the constraint ranges over. Section 6.1. |
| `severity` | Optional. `error` (default) or `warning`. |
| `message` | Optional but recommended. Text for a consumer to surface, worded for the connector rather than synthesised from the rule id. |
| `prefer` | Optional. `role` a generator should default to. A hint, not part of the constraint. |

**Placement.** A rule scoped to one service type lives on that `serviceTypes[]` entry. A rule
spanning different service types lives in the top level `rules[]`, where every subject must name
its `serviceType`.

**Unknown ids.** A consumer that does not recognise a `rule` id or a subject `kind` skips that rule
with a logged warning and never fails. This is what lets an older consumer read a newer manifest.

**Consumers.** The same rule is evaluated by the compiler plugin against written source, by the
Integrator to keep a form from producing an invalid service, and by coding agents at generation
time. One rule, three executors, so the namespace marks the category and not the executor.

### 6.1 `subjects[]`

A tagged union. `kind` discriminates, so a malformed subject is always distinguishable.

| `kind` | Fields | Addresses |
|---|---|---|
| `identifier` | none | The identifier or base path slot. |
| `annotation` | `name` | An annotation as a whole, its presence rather than a field inside it. |
| `annotationField` | `annotation`, `path` | One field inside an annotation. `path` is an array, so nested fields such as `["retryConfig", "maxCount"]` are reachable. |
| `handler` | `name` | A handler function. |
| `param` | `handler`, `name` | One parameter of a handler. |

Every subject also accepts:

| Field | Meaning |
|---|---|
| `serviceType` | Which service type this subject belongs to. Defaults to the enclosing one. Required in a top level rule. |
| `role` | This subject's name within its rule. Asymmetric constraints fix the names such as `when` and `then`. Symmetric ones use free labels, referenced by `prefer`. |

### 6.2 Constraint registry

| Rule id | Subjects | Semantics |
|---|---|---|
| `structure.exactlyOne` | N symmetric | Exactly one present. |
| `structure.atMostOne` | N symmetric | Zero or one, never more. |
| `structure.atLeastOne` | N symmetric | One or more. |
| `structure.allOrNone` | N symmetric | All present, or none. |
| `structure.requires` | `when`, `then` | If `when` is present, `then` must be present. |
| `structure.conflictsWith` | `when`, `then` | If `when` is present, `then` must be absent. |

The first three appear in the corpus. The rest are reachable without touching the schema.

`structure.atLeastOne` shows the design working. README section 6 originally ruled out "at least
one of N" because the old closed enum made it a schema change. Evidence turned up in the SMB
library, which requires at least one `onFile*` handler or `onFileDelete`, and expressing it cost
one registry row and one rule instance.

Asymmetric constraints use `role` instead of positional members:

```json
{
  "id": "$batchSizeNeedsBatchMode",
  "rule": "structure.requires",
  "severity": "warning",
  "message": "batchSize has no effect unless mode is \"batch\".",
  "subjects": [
    { "role": "when", "kind": "param", "handler": "onMessage", "name": "batchSize" },
    { "role": "then", "kind": "annotationField", "annotation": "$serviceConfig", "path": ["mode"] }
  ]
}
```

---

## 7. `params[]`

```json
{
  "id": "$service.onUpdate.afterEntry",
  "name": "afterEntry",
  "doc": "The row state after the change.",
  "type": { "name": "record {}", "builtin": true },
  "presence": "required",
  "dataBinding": { "typedescs": [{ "constraint": { "name": "record {}", "builtin": true }, "shapes": [{ "form": "bare" }] }] },
  "annotations": ["$payload"]
}
```

| Field | Meaning |
|---|---|
| `id` | **Required.** Hierarchical: the owning handler's `id` plus this parameter's `name`. On an `addMode: "many"` slot this names the slot itself, not each user named occurrence. Section 0. |
| `name` | The parameter name to emit. Required on every fixed slot, omitted only when `addMode` is `"many"`. |
| `doc` | **Required.** What this parameter carries. Section 5.2. |
| `deprecated` | Optional. Section 5.3. |
| `type` | `TypeRef` or a union. States the full static surface for this slot even where `dataBinding` also implies it. |
| `presence` | `required` or `optional`. |
| `addMode` | Optional `"many"`. The slot repeats, each occurrence independently named and typed, as with HTTP query params, GraphQL field arguments, and MCP tool arguments. |
| `dataBinding` | Inline data binding for this slot. Present only when the value can be projected into a user defined type. Section 9. |
| `annotations` | Ids of annotations with `attachPoint: "parameter"`. |

**On `name`.** A handler in `options[]` has no method behind it, so codegen renders the parameter
from this entry alone. Omitting the name does not add flexibility, it makes each generator invent
its own. The one exception is `addMode: "many"`, where the user names each occurrence.

Array order is meaningful. A parameter that must come first is listed first, with no separate
ordering field.

---

## 8. `annotations[]`

```json
{ "id": "$serviceConfig", "type": { "name": "ServiceConfig" }, "attachPoint": "service", "presence": "optional" }
```

| Field | Meaning |
|---|---|
| `id` | Referenced from whichever construct the annotation attaches to. |
| `type` | `TypeRef`, may be cross module. |
| `attachPoint` | `service`, `function`, `parameter`, or `return`. |
| `presence` | `required` or `optional`. |

Every attach point has a precise forward reference. The construct that carries the annotation names
it, and the annotation never reaches back with a list of what it applies to:

| `attachPoint` | Referenced from |
|---|---|
| `service` | `serviceTypes[].annotations` |
| `function` | `handlers.options[].annotations` |
| `return` | `handlers.options[].returns.annotations` |
| `parameter` | `params[].annotations` |

This replaces the earlier `appliesTo` reverse list, which named service types rather than the
attachment site. Every annotation in the corpus is now reachable by forward reference, so
`appliesTo` was removed rather than kept as an alternative.

No `fieldOverrides`. Every corpus instance was an unused empty array.

---

## 9. Data binding: `params[].dataBinding` and `handlers.options[].returns.dataBinding`

Written inline on the slot it describes, not in a top level registry. Modeled on Ballerina's
`typedesc<T>`: a user suppliable type, bound by an upper constraint, embedded into the declared
type in one or more ways. A binding is a set of independent variants that share nothing.

The same shape describes both directions of the one idea, a declared type narrower than a builtin
constraint that the runtime converts on the way past:

| Slot | Field | Direction | Worked case |
|---|---|---|---|
| `params[]` | `dataBinding` | Inbound. Wire payload converted into the declared type. | Kafka's `records` projecting a batch's value. |
| `handlers.options[].returns` | `dataBinding` | Outbound. The declared return type converted out to wire form. | An HTTP resource returning `anydata`, serialized as the response body. |

```json
"dataBinding": {
  "typedescs": [
    { "constraint": { "name": "anydata", "builtin": true }, "excludes": [{ "name": "AnydataMessage" }], "shapes": [{ "form": "bare" }] },
    { "constraint": { "name": "anydata", "builtin": true }, "shapes": [{ "form": "included", "envelope": { "name": "AnydataMessage" }, "bindableFields": ["content"] }] }
  ]
}
```

| Field | Meaning |
|---|---|
| `typedescs[]` | Independent variants, below. |

A binding describes one slot, so it carries no id and nothing references it. Two slots that bind
the same way each state it, which costs a little repetition and keeps every slot readable on its
own.

| `typedescs[]` field | Meaning |
|---|---|
| `constraint` | This variant's upper bound. Exactly one type, never a union. Two bounds sharing identical shapes are two variants. |
| `excludes` | Instantiations another variant already owns. |
| `shapes[]` | Legal embeddings of this variant's bound. |

| `shapes[].form` | Fields | Meaning |
|---|---|---|
| `bare` | none | `T` stands alone. The declared type is the bound type, no wrapping. |
| `array` | `element` | `T[]`. `element` says whether each item is `bare` or `included`. |
| `stream` | `element`, `completionType` | `stream<T, completionType>`. Same as `array` but streamed. |
| `included` | `envelope`, `bindableFields` | The user record does `*envelope;` and retypes only `bindableFields`. Everything else stays fixed. |

`envelope` (and `constraint`, and `excludes`) can carry `subtypeFamily: true` when the relationship
is "any subtype of this type", not the exact type alone, section 1.4. HTTP's `StatusCodeResponse`
family is the worked case: the envelope is not one fixed record the way `AnydataConsumerRecord` is,
it is a whole open ended set of records the `http` module and the user both add to.

**Why `excludes` exists.** An envelope record such as `AnydataMessage` is itself valid `anydata`,
so without it the same declared type would satisfy the `bare` variant and also be the unoverridden
instantiation of the `included` variant. A generator would have no way to know which was meant.
`excludes` removes the spurious reading so every declared type maps to exactly one variant.

Batching combines with either shape. Kafka batches both its variants, each stating `array`
independently:

```json
"dataBinding": {
  "typedescs": [
    { "constraint": { "name": "anydata", "builtin": true }, "excludes": [{ "name": "AnydataConsumerRecord" }], "shapes": [{ "form": "array", "element": "bare" }] },
    { "constraint": { "name": "anydata", "builtin": true }, "shapes": [{ "form": "array", "element": "included", "envelope": { "name": "AnydataConsumerRecord" }, "bindableFields": ["value"] }] }
  ]
}
```

Two bounds that happen to share shapes are still two variants. FTP's CSV rows may be `string[]` or
`record {}`, batched or streamed, and each restates its shapes:

```json
"dataBinding": {
  "typedescs": [
    {
      "constraint": { "name": "string[]" },
      "shapes": [
        { "form": "array", "element": "bare" },
        { "form": "stream", "element": "bare", "completionType": { "name": "error?" } }
      ]
    },
    {
      "constraint": { "name": "record {}", "builtin": true },
      "shapes": [
        { "form": "array", "element": "bare" },
        { "form": "stream", "element": "bare", "completionType": { "name": "error?" } }
      ]
    }
  ]
}
```

No rule level envelope, it lives on the `included` shape that uses it. No `fixedFields`, they are
the envelope's fields minus `bindableFields`.

### 9.1 `handlers.options[].returns.dataBinding`

Present only when one member of `returns.type`'s union is a builtin constraint the runtime
serializes the declared type out through, rather than a fixed type like `error` or a module type
like `http:Response`. Same `typedescs[]`/`shapes[]` shape as `dataBinding` above, read outbound
instead of inbound:

```json
"returns": {
  "id": "$service.resource.returns",
  "type": [{ "name": "anydata", "builtin": true }, { "name": "Response" }, { "name": "error", "builtin": true }],
  "dataBinding": {
    "typedescs": [{ "constraint": { "name": "anydata", "builtin": true }, "shapes": [{ "form": "bare" }] }]
  }
}
```

Here the `anydata` branch is the one a user's declared return type actually varies over; `Response`
and `error` are fixed alternatives with no schema to bind, so they are not variants and are not
restated inside `dataBinding`. A streamed return, as GraphQL's subscription fields and gRPC's
server and bidirectional streaming RPCs use, states it the same way `dataBinding` does for a
streamed param, `{ "form": "stream", "element": "bare" }`, since the bindable part is each element
the stream yields, not the stream itself.

No `excludes` has shown up on a return's `dataBinding` in the corpus yet: excluding an envelope only
matters when that envelope is itself valid `anydata` and would otherwise also satisfy the `bare`
variant, the same reasoning as the "Why `excludes` exists" note above, and no return type in the
corpus embeds one. The field remains legal here should a connector need it.

---

## 10. Vocabulary

| Concept | Values |
|---|---|
| `serviceTypes[].identifier.form` | `basePath`, `stringLiteral` |
| `handlers.options[].addMode` | `subset` (default), `many` |
| `handlers.options[].kind` | `remote`, `resource` |
| `handlers.options[].presence` | `required`, `optional` |
| `params[].addMode` | `many` |
| `annotations[].attachPoint` | `service`, `function`, `parameter`, `return` |
| `rules[].rule` | Open vocabulary. Registry in section 6.2. |
| `rules[].subjects[].kind` | `identifier`, `annotation`, `annotationField`, `handler`, `param` |
| `rules[].severity` | `error` (default), `warning` |
| `params[].dataBinding.typedescs[].shapes[].form` | `bare`, `array`, `stream`, `included` |
| `params[].dataBinding.typedescs[].shapes[].element` | `bare`, `included` |
| `listeners[].requiredImports[].importType` | `driver` |
| `listeners[].platformDependencies[].scope` | `provided` |
| `listeners[].platformDependencies[].nativeLibraries[].os` | `linux`, `windows`, `macos` |

---

## 11. Versioning

`version` has the form `v<major>.<minor>`, such as `"v1.0"`. There is no patch component, since an
editorial change that does not move the contract does not get a number.

| Component | Bump when | Consumer must |
|---|---|---|
| minor | Purely additive. Everything the previous version understood still means the same. | Keep reading. Skip what it does not recognise. |
| major | Structural. A field is renamed, removed, re-nested, retyped, or changes meaning. | Refuse the instance. |

### 11.1 Additive (minor)

| Change | Example |
|---|---|
| New entry in an open registry | Adding `structure.atLeastOne`. No schema change at all. |
| New value in an open vocabulary | A new subject `kind`, a new shape `form`, a new `importType`. |
| New optional field | Adding `doc` or `deprecated` to `handlers.options[]`. |
| New optional top level key | How `rules` was introduced. |

### 11.2 Structural (major)

| Change | Example |
|---|---|
| Field renamed or removed | `supportedModes` became `typedescs`. |
| Field retyped | `constraint` went from an array to a single `TypeRef`. |
| Field re-nested | `cardinality` moved off the rule and onto each shape. |
| Optional becomes required | Breaks every instance that omitted it. |
| Required becomes optional | Breaks every consumer that read it unconditionally. |
| A value's meaning changes | `presence: "optional"` coming to mean something new. |
| Registry entry or enum member removed | Dropping `structure.atMostOne`. |

Both directions of the optional and required flip are major. One breaks producers, the other breaks
consumers.

### 11.3 Compatibility

| Consumer built for | Instance declares | Behavior |
|---|---|---|
| `v1.3` | `v1.5` | Read it. Skip unknown rule ids, subject kinds, and fields, each with a logged warning. |
| `v1.5` | `v1.2` | Read it. A minor bump never removes anything. |
| `v1.x` | `v2.0` | Refuse, with a diagnostic naming the required major version. |

### 11.4 Why minor bumps are safe

The open vocabulary and the skip unknown policy in section 6 are what make this work. Because a
consumer that meets an unfamiliar rule id skips it instead of failing, a new constraint kind is a
registry row and is additive by construction. Without that policy every new rule kind would force a
major bump.

The corollary for authors: anything expected to grow should get an open vocabulary before v1.0
freezes.

### 11.5 The v1.0 baseline

This spec is unreleased, so every structural change made up to the first published `v1.0` is free.
The clock starts at publication. Restructuring that is known to be wanted is cheapest now.
