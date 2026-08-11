# Ballerina Trigger Construct Spec

An architectural reference for a machine-readable schema that encodes the **authoring rules**
for Ballerina *trigger* services, so that coding agents and the WSO2 Integrator can
programmatically construct a correct service for any given trigger.

This document covers the why: problem, audience, scope, and design decisions. For the what, see
`spec.md` for the field reference and `spec.json` for the machine-checkable schema. Worked
instances are in `examples/*.json`.

---

## 1. Background

A Ballerina service declaration is assembled from a small set of constructs:

| Construct | Role |
|---|---|
| **Listener** | The network endpoint the service attaches to (e.g. a Kafka/RabbitMQ/HTTP listener). |
| **Service type** | The service object type that defines the service's structure and legal handlers. |
| **Service annotation** | Optional configuration attached to the service (e.g. `@x:ServiceConfig { .. }`). |
| **Handler functions** | Remote or resource methods invoked on inbound messages (e.g. `onMessage`, `get foo()`). |
| **Handler annotations** | Annotations on handler functions or their parameters (e.g. payload/header binding). |
| **Base path / service identifier** | The string after the service type. A path, a config carrying name, or unused. |

Three of these are **structurally required** to declare a working service: a **listener**, a
**service type**, and **at least one handler function**. The rest are conditional. Some
connectors require a service annotation, some use a base path, most use neither.

## 2. Problem

Which constructs are required, which are optional, and how they relate to one another
**cannot be resolved from the syntax tree or the semantic model alone**:

- The **syntax tree** describes what a service *looks like once written*.
- The **semantic model** describes what types are *valid*.
- Neither encodes **authoring intent**, for example *"to build a working RabbitMQ consumer you MUST
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

## 4. Governing principle: metadata complements introspection

> The metadata carries **only** the facts a coding agent cannot recover by introspecting the
> library source. It **references** introspectable entities by name; it never repeats them.

From the metadata **plus** library introspection, an agent generates the service source code.
Every field in the schema must justify its place by being **non-introspectable**. This single
test decides most inclusion questions:

- **Listener.** Its init signature is introspectable, so the metadata holds only a reference to
  which listener type is the entry point. No init fields.
- **Service type.** A concrete type's declared methods are introspectable, so this is a reference
  only.
- **Handler functions.** A handler from a concrete service type is introspectable and is not
  specified. Only handlers with no concrete type backing are described.
- **Annotations.** The record type is introspectable and is never restated.

What is genuinely not introspectable, and therefore is the payload:

1. **Presence rules.** Which constructs are required or optional for this trigger.
2. **Relationships.** Exclusion, choice, and requirement across constructs, as named rules from an
   open registry.
3. **Identifier semantics.** Whether the identifier is a path, a config carrying name, or unused.
4. **Requiredness overrides.** Where a construct is semantically required even though its type
   declares it optional, because it may be supplied elsewhere.

## 5. Scope

### In scope
- **Inbound trigger services only** (listener + service).
- **One meta-schema.** `spec.json` defines the shape of a trigger model. Each connector yields an
  instance that validates against it.
- The **authoring-rules overlay**: entry-point references, presence rules, relationship rules
  (an open registry of named constraints), identifier semantics, and handler-shape blocks for the
  non-concrete case.

### Out of scope
- **Clients / actions** (the outbound / connector-invocation side).
- **Handler business logic.**
- **Deployment / runtime configuration.**
- **Human readable prose docs.** This replaces the need for them programmatically. It does not
  generate them.
- **Instance generation.** The schema must keep instances generatable, but building the generator
  is a separate concern.

## 6. Design decisions (locked)

| Decision | Choice | Consequence |
|---|---|---|
| **Deliverable** | One meta-schema. | Instances validate against it; the schema is the contract. |
| **Fidelity** | Requiredness + relationships. | Captures presence rules and cross-construct relationships. Excludes import statements, literal listener-init expressions, and rendered handler-signature source. Acceptance test = *well-formed + constraints satisfiable*, **not** *compiles*. |
| **Constraint vocabulary** | `required`, `optional`, `default`, `enum`, plus an open registry of named relationship rules referenced by id. spec.md section 6. | The registry, not a closed enum, is the extension point. A new constraint kind is a registry row, not a schema revision. |

## 7. The model payload

A trigger-model instance reduces to four things:

1. **Entry point references.** Which listener type and which service type form the trigger, and
   how they pair. Introspection can enumerate all types but cannot say which are the intended
   entry points.
2. **Presence rules.** Required or optional per construct.
3. **Relationship rules.** Named constraints from an open registry. New kinds are registry rows,
   not schema changes.
4. **Identifier semantics.** Path, config carrying name, or unused.
5. **Handler shape blocks.** Only when handlers are not backed by a concrete service type.

### Annotation model (service + handler annotations, symmetric)

Both service annotations and handler annotations get **first-class, symmetric** treatment,
differing only in attachment point (service vs. handler/parameter). Each carries a minimal
overlay:

- **A reference** to the annotation type. Introspect the record for its fields, types, defaults,
  and enums.
- **Per field requiredness override**, only where the trigger's requiredness diverges from the
  record's own markers.
- **Rule membership**, as a subject addressing the annotation field by path.

Annotations are defined once and referenced many times. The top level `annotations[]` lists each
type once and the construct that carries it points at that id, so the record is never restated.

`enum` and `default` are introspected from the annotation record and are never restated here. They
survive in the vocabulary only for the identifier string, which has no record behind it.

## 8. Validation surface

An instance is considered correct when it is:

- **Well formed.** Validates against `spec.json`.
- **Referentially consistent.** Every referenced listener, service, and annotation id resolves.
- **Constraint satisfiable.** Presence rules and every `rules[]` entry are jointly satisfiable.

Compilation of generated code is explicitly **not** the acceptance test at this fidelity level.
