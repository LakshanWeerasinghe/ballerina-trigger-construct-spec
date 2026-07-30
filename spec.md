# Ballerina Trigger Construct Spec — Format Specification (v1)

| Field | Value |
|---|---|
| Spec version | v1 |
| Author | Lakshan Weerasinghe (WSO2) |
| Last revised | 2026-07-30 |
| Reviewed by | Not yet reviewed |

Field reference for the JSON shape in `examples/*.json`. See `README.md` for the *why*
(problem, audience, DRY principle, scope) — this is the *what*.

**`version`** is a required top-level string (currently `"v1"`). Bump it whenever a field's
meaning changes incompatibly with what's described here, not for additive changes.

Top-level keys:

| Key | Presence | Contents |
|---|---|---|
| `version` | required | Schema version this instance conforms to, e.g. `"v1"`. |
| `listeners` | required | Array of listener entry points. |
| `serviceTypes` | required | Array of service-type alternatives this connector exposes. |
| `annotations` | optional | Registry of annotation types referenced elsewhere, defined once. |
| `dataBindingRules` | optional | Registry of payload/data-binding modes, defined once. |

**General rule:** a field that would be empty, unused, or fully derivable from other fields is
left out — never included as an empty array / null / default placeholder.

---

## 1. `TypeRef`

Every type reference (listener class, service type, annotation type, param/return type,
data-binding envelope) uses one shape:

```json
{ "name": "Caller" }
```
Cross-module (only when the type isn't from this file's own "home" module):
```json
{ "name": "Header", "packageInfo": { "org": "ballerina", "packageName": "http", "moduleName": "http", "version": "2.16.5" } }
```
"Home" module = whichever module the file's primary construct (its listener, usually) belongs to.

**Unions** are an array of `TypeRef`, first element = codegen default:
```json
"type": [{ "name": "AnydataConsumerRecord[]" }, { "name": "BytesConsumerRecord[]" }]
```
**Nilable** (`T?` = `T|()`) is an explicit `()` union member, not a separate flag:
```json
"returns": [{ "name": "error" }, { "name": "()" }]
```

---

## 2. `listeners[]`

```json
{
  "type": { "name": "Listener" },
  "services": ["service"],
  "requiredImports": [
    { "importType": "driver", "packageInfo": { "org": "ballerinax", "packageName": "mssql.cdc.driver", "moduleName": "mssql.cdc.driver", "version": "1.0.2" } }
  ]
}
```

| Field | Meaning |
|---|---|
| `type` | `TypeRef` for the listener class. |
| `services` | `serviceTypes[].id` values this listener can host. |
| `requiredImports` | Optional. Side-effect-only imports needed at runtime (e.g. `import ballerinax/mssql.cdc.driver as _;`) that nothing references by name. |

No listener init fields are ever modeled (introspectable). No `presence` field — a listener is
always required.

---

## 3. `serviceTypes[]`

```json
{
  "id": "service",
  "type": { "name": "Service" },
  "concrete": false,
  "multipleListenersAllowed": true,
  "multipleServicesPerListenerAllowed": true,
  "identifier": { "presence": "optional", "form": ["stringLiteral"] },
  "handlers": { "...": "..." },
  "rules": [ "...": "..." ]
}
```

| Field | Meaning |
|---|---|
| `id` | Referenced from `listeners[].services` and sibling constructs. |
| `type` | `TypeRef` for the service object type. |
| `concrete` | `true` = type declares its own methods (introspectable, see `handlers.backedByConcreteType`); `false` = marker/abstract type. |
| `multipleListenersAllowed` | Can one service instance attach to more than one listener at once (`service X on l1, l2 {}`)? |
| `multipleServicesPerListenerAllowed` | Can one listener host more than one service of this type at once? |
| `identifier` | Omit the whole key if the identifier slot carries no meaning for this connector. Present only when genuinely consulted. `form` values: `basePath`, `stringLiteral`. |
| `handlers` | §4. |
| `rules` | Optional, §6. |

No `presence` field here either — derived from array cardinality: one entry = required; multiple
entries = each individually optional, choice left to whatever supplied the generation intent (no
"at least one of N" enforcement — a generator is always externally directed).

---

## 4. `handlers`

```json
"handlers": { "backedByConcreteType": false, "addMode": "subset", "options": [ /* §5 */ ] }
```

| Field | Meaning |
|---|---|
| `backedByConcreteType` | `true` → `options: []`, nothing else to say. `false` → `options` is the only source of truth. |
| `addMode` | `"subset"` — fixed named vocabulary, each option has its own `presence`. `"many"` — open-ended, user-named (HTTP resource methods, GraphQL fields, MCP tools); represented as one `options` entry named `"*"`. |

---

## 5. `handlers.options[]`

```json
{
  "name": "onConsumerRecord",
  "kind": "remote",
  "presence": "required",
  "annotations": ["functionConfig"],
  "params": [ /* §7 */ ],
  "returns": [{ "name": "error" }, { "name": "()" }]
}
```

| Field | Meaning |
|---|---|
| `name` | Handler method name, or `"*"` for open/many. |
| `kind` | `"remote"` or `"resource"`. |
| `presence` | Only under `addMode: "subset"`. |
| `annotations` | Ids into `annotations[]`, `attachPoint: "function"`. |
| `returns` | `TypeRef` or array. |

Resource-kind extras: HTTP adds `method` (`{presence, values}`) and `path` (`{presence, form}`);
GraphQL adds `accessor` (`{presence, values}`), `fieldName` (`{presence, form}`), and
`graphqlOperation` (informational).

---

## 6. `rules[]` (nested inside a `serviceTypes[]` entry)

```json
"rules": [
  { "id": "queueNameSource", "type": "oneOf",
    "members": [{ "annotation": "serviceConfig", "field": "queueName", "preferred": true }, { "part": "identifier" }] },
  { "id": "messageHandlerChoice", "type": "oneOf",
    "members": [{ "handler": "onMessage" }, { "handler": "onRequest" }] },
  { "id": "textMessageVsGeneric", "type": "atMostOne",
    "members": [{ "handler": "onMessage" }, { "handler": "onTextMessage" }] }
]
```

Lives on the `serviceTypes[]` entry it constrains, not a top-level array — colocated with
`identifier`/`handlers`. `type` values:

| Type | Semantics |
|---|---|
| `oneOf` | Exactly one member — not zero, not more than one. |
| `atMostOne` | Zero or one member — never more than one, but zero is fine. |

Member shapes: `{ "annotation": id, "field": name, "preferred"?: true }` (a field inside a
top-level annotation), `{ "part": "identifier" }` (this service type's identifier), or
`{ "handler": name }` (one of this service type's own `handlers.options[].name`). No
`serviceType` qualifier — implicit from nesting. A rule spanning two *different* service types
would need a top-level `rules[]`; nothing in the corpus needs that yet.

---

## 7. `params[]`

```json
{
  "name": "afterEntry",
  "type": { "name": "record {}" },
  "presence": "required",
  "addMode": "many",
  "dataBinding": "rowState",
  "annotations": ["payload"]
}
```

| Field | Meaning |
|---|---|
| `name` | Optional domain-meaningful name — added only where real source evidence shows it matters, not retrofitted everywhere. |
| `type` | `TypeRef` or array; restates the full static surface for this slot even where `dataBindingRules` also says it. |
| `presence` | `required` / `optional`. |
| `addMode` | Optional `"many"` — slot repeats zero or more times, each occurrence independently named/typed (HTTP query/header, MCP tool args). Absent = at most one. |
| `dataBinding` | Id into `dataBindingRules[]`. Present only when the raw value can be projected into a user-defined type. Absent when the type is fixed and not further narrowable (e.g. a `byte[]`/`stream<byte[], error?>` choice is real but not a *binding* choice). |
| `annotations` | Ids into `annotations[]`, `attachPoint: "parameter"`. |

Array order is meaningful (e.g. a must-be-first param is simply listed first — no separate
ordering field).

---

## 8. `annotations[]`

```json
{ "id": "serviceConfig", "type": { "name": "ServiceConfig" }, "attachPoint": "service", "appliesTo": ["service"], "presence": "optional" }
```

| Field | Meaning |
|---|---|
| `id` | Referenced from `params[].annotations`, `handlers.options[].annotations`, `rules[].members[].annotation`. |
| `type` | `TypeRef`, can be cross-module. |
| `attachPoint` | `service` \| `function` \| `parameter` \| `return`. |
| `appliesTo` | `serviceTypes[].id` array — include **only** when no other reference already links this annotation (those are more precise, so `appliesTo` would be redundant). |
| `presence` | `required` / `optional`. |

No `fieldOverrides` — every instance in the corpus was an unused empty array; reintroduce only on
real need.

**Residual gap:** service-level/return-level annotations have no reference mechanism as precise
as `params[].annotations`, so they always rely on `appliesTo`.

---

## 9. `dataBindingRules[]`

```json
{
  "id": "messagePayload",
  "supportedModes": [
    { "mode": "direct", "typeConstraint": [{ "name": "anydata" }], "excludes": [{ "name": "AnydataMessage" }] },
    { "mode": "includedRecord", "includes": { "name": "AnydataMessage" }, "bindableFields": ["content"] }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | Referenced from `params[].dataBinding`. |
| `cardinality` | Optional `"array"` — the bound value is a batch; a mode's type is the array *element* type, not the whole param type. |
| `supportedModes[].mode` | See below. |

| `mode` | Fields | Meaning |
|---|---|---|
| `direct` | `typeConstraint`, `excludes`? | Param type directly *is* the target type — no wrapping. |
| `includedRecord` | `includes`, `bindableFields` | User record does `*EnvelopeType;`, overrides only `bindableFields`; everything else stays fixed. |
| `streamable` | `typeConstraint` | Same as `direct`, but `stream<...>` over the target type. |

No rule-level `envelopeType` unless the rule has an `includedRecord` mode (otherwise it falsely
implies a partial-envelope relationship that isn't there). No `fixedFields` — always derivable as
"the envelope's fields minus `bindableFields`."

---

## 10. Vocabulary quick-reference

| Concept | Values |
|---|---|
| `serviceTypes[].identifier.form` | `basePath`, `stringLiteral` |
| `handlers.addMode` | `many`, `subset` |
| `handlers.options[].kind` | `remote`, `resource` |
| `handlers.options[].presence` | `required`, `optional` |
| `params[].addMode` | `many` |
| `dataBindingRules[].supportedModes[].mode` | `direct`, `includedRecord`, `streamable` |
| `annotations[].attachPoint` | `service`, `function`, `parameter`, `return` |
| `rules[].type` | `oneOf`, `atMostOne` |
| `listeners[].requiredImports[].importType` | `driver` |

---

