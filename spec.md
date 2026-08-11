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

Three constructs carry an id: `serviceTypes[]`, `annotations[]`, and `rules[]`. Every id starts
with `$`, and so does every reference to one.

```json
"id": "$serviceConfig"
"annotations": ["$serviceConfig"]
```

The prefix keeps an id reference from reading like anything else. Other values in this file are
Ballerina identifiers, type names, enum values, and free text, and a bare id looks like all of
them. `"services": ["$service"]` is clearly a pointer into `serviceTypes[]`.

Ids are scoped per construct kind and every reference site names the kind it targets, so `$` alone
is enough. No per kind sigil.

Handler names, parameter names, and `role` labels are not ids and are never prefixed.

---

## 1. `TypeRef`

Every type reference uses one shape:

```json
{ "name": "Caller" }
```

Add `packageInfo` only when the type is not from this file's home module, which is the module the
listener belongs to:

```json
{ "name": "Header", "packageInfo": { "org": "ballerina", "packageName": "http", "moduleName": "http", "version": "2.16.5" } }
```

A union is an array of `TypeRef`, first element being the codegen default:

```json
"type": [{ "name": "AnydataConsumerRecord[]" }, { "name": "BytesConsumerRecord[]" }]
```

A nilable type `T?` is written as an explicit `()` union member, not a separate flag:

```json
"returns": [{ "name": "error" }, { "name": "()" }]
```

---

## 2. `listeners[]`

```json
{
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
| `type` | `TypeRef` for the listener class. |
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
| `id` | Referenced from `listeners[].services` and sibling constructs. |
| `type` | `TypeRef` for the service object type. |
| `concrete` | `true` when the type declares its own methods and they can be introspected. `false` for a marker or abstract type. |
| `multipleListenersAllowed` | Can one service attach to more than one listener at once, as in `service X on l1, l2 {}`? |
| `deprecated` | Optional. Section 5.2. |
| `annotations` | Ids of annotations with `attachPoint: "service"`. Section 8. |
| `identifier` | Omit entirely when the identifier slot carries no meaning. `form` values: `basePath`, `stringLiteral`. |
| `handlers` | Section 4. |
| `rules` | Optional. Section 6. |

No `presence` field. One entry means required, several entries mean each is individually optional
and the choice comes from whatever supplied the generation intent.

When a connector really does require at least one of several handlers, that is a `rules[]` entry,
not a `presence` marker. See `structure.atLeastOne` in section 6.2.

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
"handlers": { "backedByConcreteType": false, "addMode": "subset", "options": [ ] }
```

A concrete backed type says nothing further. Both `addMode` and `options` are omitted:

```json
"handlers": { "backedByConcreteType": true }
```

| Field | Meaning |
|---|---|
| `backedByConcreteType` | `true` means the type's own methods are the handlers, so introspection already answers everything this file could say. `false` means `options` is the only source of truth. |
| `addMode` | Only when `backedByConcreteType` is `false`. `"subset"` is a fixed set of names, each with its own `presence`. `"many"` is open ended and user named, written as one option named `"*"`. |
| `options` | Only when `backedByConcreteType` is `false`. Section 5. |

---

## 5. `handlers.options[]`

```json
{
  "name": "onConsumerRecord",
  "kind": "remote",
  "doc": "Invoked with each batch of records polled from the subscribed topics.",
  "presence": "required",
  "annotations": ["$functionConfig"],
  "params": [ ],
  "returns": [{ "name": "error" }, { "name": "()" }]
}
```

| Field | Meaning |
|---|---|
| `name` | Handler method name, or `"*"` for an open handler. |
| `kind` | `"remote"` or `"resource"`. |
| `doc` | What this handler is for and when it fires. Section 5.1. |
| `deprecated` | Optional. Section 5.2. |
| `presence` | Only under `addMode: "subset"`. |
| `annotations` | Ids of annotations with `attachPoint: "function"`. |
| `returnAnnotations` | Ids of annotations with `attachPoint: "return"`. |
| `returns` | `TypeRef` or a union. |

Resource kind extras: HTTP adds `method` and `path`; GraphQL adds `accessor`, `fieldName`, and
`graphqlOperation`. Each is a `{ presence, values }` or `{ presence, form }` object.

### 5.1 `doc`

Everywhere else the rule is: if introspection recovers it, leave it out. Docs invert that, but only
for the non concrete case, and for the same reason. A handler backed by a concrete type has a real
method with a real doc comment, so its docs are introspectable and are not restated here. A handler
described in `options[]` has no such method, so there is no doc comment to read.

| `backedByConcreteType` | `doc` |
|---|---|
| `true` | Omit. Introspect the method. |
| `false` | Author it. It is the only description a generator or agent will see. |

The same applies to `params[].doc`.

### 5.2 `deprecated`

Attaches to `serviceTypes[]`, `handlers.options[]`, and `params[]`, the three constructs a library
can retire while still accepting.

```json
"deprecated": { "reason": "Superseded by the typed content handlers.", "since": "2.4.0", "replacement": "onFileJson" }
```

| Field | Meaning |
|---|---|
| `reason` | Required. A deprecation with no reason gives a generator nothing to relay. |
| `since` | Optional. Package version the deprecation took effect. |
| `replacement` | Optional. What to use instead. |

The mechanism has to exist before the first deprecation, since one that waits for a schema revision
cannot be announced on time. No corpus instance yet.

---

## 6. `rules[]`

A rule is referenced, never defined here. `rule` names a constraint from an open registry the
consumer already implements, `subjects` say what it ranges over, and `args` parameterize it. Adding
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
| `args` | Optional. Constraint specific parameters. |
| `severity` | Optional. `error` (default) or `warning`. |
| `message` | Optional but recommended. Supports `{placeholder}` interpolation from `args`. |
| `reportOn` | Optional. `role` of the subject the diagnostic points at. Defaults to the service declaration. |
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
| `role` | This subject's name within its rule. Asymmetric constraints fix the names such as `when` and `then`. Symmetric ones use free labels, referenced by `prefer` and `reportOn`. |

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
  "name": "afterEntry",
  "doc": "The row state after the change.",
  "type": { "name": "record {}" },
  "presence": "required",
  "dataBinding": { "typedescs": [{ "constraint": { "name": "record {}" }, "shapes": [{ "form": "bare" }] }] },
  "annotations": ["$payload"]
}
```

| Field | Meaning |
|---|---|
| `name` | The parameter name to emit. Required on every fixed slot, omitted only when `addMode` is `"many"`. |
| `doc` | What this parameter carries. Same non concrete rule as section 5.1. |
| `deprecated` | Optional. Section 5.2. |
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
| `return` | `handlers.options[].returnAnnotations` |
| `parameter` | `params[].annotations` |

This replaces the earlier `appliesTo` reverse list, which named service types rather than the
attachment site. Every annotation in the corpus is now reachable by forward reference, so
`appliesTo` was removed rather than kept as an alternative.

No `fieldOverrides`. Every corpus instance was an unused empty array.

---

## 9. `params[].dataBinding`

Written inline on the parameter it describes, not in a top level registry. Modeled on Ballerina's
`typedesc<T>`: a user suppliable type, bound by an upper constraint, embedded into the declared
type in one or more ways. A binding is a set of independent variants that share nothing.

```json
"dataBinding": {
  "typedescs": [
    { "constraint": { "name": "anydata" }, "excludes": [{ "name": "AnydataMessage" }], "shapes": [{ "form": "bare" }] },
    { "constraint": { "name": "anydata" }, "shapes": [{ "form": "included", "envelope": { "name": "AnydataMessage" }, "bindableFields": ["content"] }] }
  ]
}
```

| Field | Meaning |
|---|---|
| `typedescs[]` | Independent variants, below. |

A binding describes one slot, so it carries no id and nothing references it. Two parameters that
bind the same way each state it, which costs a little repetition and keeps every parameter
readable on its own.

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

**Why `excludes` exists.** An envelope record such as `AnydataMessage` is itself valid `anydata`,
so without it the same declared type would satisfy the `bare` variant and also be the unoverridden
instantiation of the `included` variant. A generator would have no way to know which was meant.
`excludes` removes the spurious reading so every declared type maps to exactly one variant.

Batching combines with either shape. Kafka batches both its variants, each stating `array`
independently:

```json
"dataBinding": {
  "typedescs": [
    { "constraint": { "name": "anydata" }, "excludes": [{ "name": "AnydataConsumerRecord" }], "shapes": [{ "form": "array", "element": "bare" }] },
    { "constraint": { "name": "anydata" }, "shapes": [{ "form": "array", "element": "included", "envelope": { "name": "AnydataConsumerRecord" }, "bindableFields": ["value"] }] }
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
      "constraint": { "name": "record {}" },
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

---

## 10. Vocabulary

| Concept | Values |
|---|---|
| `serviceTypes[].identifier.form` | `basePath`, `stringLiteral` |
| `handlers.addMode` | `subset`, `many` |
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
