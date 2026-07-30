# Ballerina Trigger Construct Spec

An architectural reference for a machine-readable schema that encodes the **authoring rules**
for Ballerina *trigger* services, so that coding agents and the WSO2 Integrator can
programmatically construct a correct service for any given trigger.

This document covers the *why* — problem, audience, scope, design decisions. For the *what* —
the literal JSON field reference — see `spec.md`. Worked instances are in `examples/*.json`.

---

## 1. Background — what a Ballerina service is made of

A Ballerina service declaration is assembled from a small set of constructs:

| Construct | Role |
|---|---|
| **Listener** | The network endpoint the service attaches to (e.g. a Kafka/RabbitMQ/HTTP listener). |
| **Service type** | The service object type that defines the service's structure and legal handlers. |
| **Service annotation** | Optional configuration attached to the service (e.g. `@x:ServiceConfig { … }`). |
| **Handler functions** | Remote or resource methods invoked on inbound messages (e.g. `onMessage`, `get foo()`). |
| **Handler annotations** | Annotations on handler functions or their parameters (e.g. payload/header binding). |
| **Base path / service identifier** | The string after the service type — a path, a config-carrying name, or unused. |

Three of these are **structurally required** to declare a working service: a **listener**, a
**service type**, and **at least one handler function**. The rest are conditional — some
connectors require a service annotation, some use a base path, most use neither.

## 2. Problem

Which constructs are required, which are optional, and how they relate to one another
**cannot be resolved from the syntax tree or the semantic model alone**:

- The **syntax tree** describes what a service *looks like once written*.
- The **semantic model** describes what types are *valid*.
- Neither encodes **authoring intent** — e.g. *"to build a working RabbitMQ consumer you MUST
  supply a queue name, and you may supply it either through the service annotation or through
  the service identifier, but exactly one."*

Because the Ballerina Central API docs are generated from the syntax tree and semantic model,
there is no documentation that explains how to *construct* a service for a given trigger. As a
result, coding agents and the WSO2 Integrator have no programmatic way to decide the correct
path for writing a service.

This project defines the missing layer: a schema that captures the construction rules and
cross-construct constraints that sit **above** syntax and semantics.

## 3. Audience / consumers

| Consumer | Needs | Failure mode without this schema |
|---|---|---|
| **Coding agents** | Know which constructs are required and how they relate, then introspect the library to fill in the details and emit source code. | Generated services that are incomplete or invalid. |
| **WSO2 Integrator** (visual / low-code) | Know which fields are required/optional and which choices are mutually exclusive, to drive correct code generation. | A UI that lets users build invalid services. |
| **Validation tooling** | A well-formed contract to check trigger instances against. | No way to verify correctness. |

## 4. Governing principle — metadata is the *complement* of introspection (DRY)

> The metadata carries **only** the facts a coding agent cannot recover by introspecting the
> library source. It **references** introspectable entities by name; it never repeats them.

From the metadata **plus** library introspection, an agent generates the service source code.
Every field in the schema must justify its place by being **non-introspectable**. This single
test decides most inclusion questions:

- **Listener** — its init signature is introspectable → the metadata holds only a *reference* to
  which listener type is the entry point. **No init fields.**
- **Service type** — a concrete type's declared methods are introspectable → *reference* only.
- **Handler functions** — if a handler comes from a **concrete service type**, it is
  introspectable → **not specified**. Only handlers with *no* concrete-type backing (marker /
  abstract types, or open user-named resource methods) are described.
- **Service / handler annotations** — the record type (field names, types, optional/required
  markers, defaults, enums) is introspectable → **not restated**.

What is genuinely **not** introspectable — and therefore *is* the payload:

1. **Presence rules** — which constructs are required / optional for this trigger.
2. **Relationships** — exclusion/choice across constructs (`oneOf`, `atMostOne`).
3. **Identifier / base-path semantics** — whether the identifier is a path, a config-carrying
   name, or unused.
4. **Requiredness overrides** — where a construct/field is semantically required even though its
   type declares it optional (because it may be supplied elsewhere).

## 5. Scope

### In scope
- **Inbound trigger services only** (listener + service).
- **One meta-schema** — a single JSON Schema defining the shape of a "trigger model." Each
  connector yields an instance that validates against it.
- The **authoring-rules overlay**: entry-point references, presence rules, relationship rules
  (`oneOf`/`atMostOne`), identifier semantics, and handler-shape blocks for the non-concrete case.

### Out of scope
- **Clients / actions** (the outbound / connector-invocation side).
- **Handler business logic.**
- **Deployment / runtime configuration.**
- **Human-readable prose docs** — this replaces the *need* for them programmatically; it does
  not generate them.
- **Instance generation** (introspection / curation pipeline) — the schema must keep instances
  generatable, but building the generator is a separate, downstream concern.

## 6. Design decisions (locked)

| Decision | Choice | Consequence |
|---|---|---|
| **Deliverable** | One meta-schema. | Instances validate against it; the schema is the contract. |
| **Fidelity** | Requiredness + relationships. | Captures presence rules and cross-construct relationships. Excludes import statements, literal listener-init expressions, and rendered handler-signature source. Acceptance test = *well-formed + constraints satisfiable*, **not** *compiles*. |
| **Constraint vocabulary** | Minimal + `rules`: `required`, `optional`, `default`, `enum`, plus typed relationship rules (`oneOf` = exactly one, `atMostOne` = zero or one). | The annotation-vs-identifier "same config, two sources" case **is** expressible (`oneOf`); WebSocket's "these two handlers may not coexist, but neither is mandatory" case needed `atMostOne`. If/then conditionals, cross-field `requires`, and derived defaults are **not** — see spec.md §11. |

## 7. The model payload

A trigger-model instance reduces to four things:

1. **Entry-point references** — which listener type and which service type form the trigger, and
   how they pair. (Introspection can enumerate all types but not tell you *which* are the
   intended entry points.)
2. **Presence rules** — required / optional per construct.
3. **Relationship rules** — `oneOf` (exactly one, e.g. queue-name-from-annotation **or**
   from-identifier) and `atMostOne` (zero or one, e.g. two handlers that can't coexist but
   neither is mandatory).
4. **Identifier / base-path semantics** — path vs. config-carrying name vs. unused.

Plus, conditionally:

5. **Handler-shape blocks** — present **only** when handlers are not backed by a concrete service
   type (open / user-named resource methods).

### Annotation model (service + handler annotations, symmetric)

Both service annotations and handler annotations get **first-class, symmetric** treatment,
differing only in attachment point (service vs. handler/parameter). Each carries a minimal
overlay:

- **Reference** to the annotation type (`module:AnnotationType`) — introspect the record for its
  fields, types, defaults, and enums.
- **Per-field requiredness override** — only where the trigger's semantic requiredness diverges
  from the record's own optional/required markers.
- **Rule membership** — participation in a `oneOf`/`atMostOne` relationship group.

Handler annotations are modeled **"define once, reference many"**: a top-level section references
each relevant annotation type once; handlers point at it. This is DRY-consistent — the record is
never restated, and defining it once avoids per-handler repetition.

> **Note:** `enum` and `default` are introspected from the annotation record and are **never
> restated**. In practice they survive in the vocabulary only for *type-less* constructs — the
> identifier string, which has no record behind it.

## 8. Validation surface

An instance is considered correct when it is:

- **Well-formed** — validates against the meta-schema.
- **Referentially consistent** — every referenced listener / service / annotation type resolves.
- **Constraint-satisfiable** — presence rules and `rules` groups (`oneOf`/`atMostOne`) are jointly satisfiable.

Compilation of generated code is explicitly **not** the acceptance test at this fidelity level.
