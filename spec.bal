// Ballerina type definitions for the Trigger Construct Spec (v1).
// Mirrors spec.md field-by-field; see spec.md for full semantics and worked examples.

# The root trigger-model document.
#
# + version - Schema version this instance conforms to, e.g. `"v1"`
# + listeners - Listener entry points
# + serviceTypes - Service-type alternatives this connector exposes
# + annotations - Registry of annotation types referenced elsewhere, defined once
# + dataBindingRules - Registry of payload/data-binding modes, defined once
public type TriggerModel record {|
    string version;
    Listener[] listeners;
    ServiceType[] serviceTypes;
    Annotation[] annotations?;
    DataBindingRule[] dataBindingRules?;
|};

# A reference to a Ballerina type, optionally qualified with cross-module package info.
#
# + name - The type name. Same module as this file's own primary construct unless `packageInfo` is set
# + packageInfo - Present only when `name` comes from a different module
public type TypeRef record {|
    string name;
    PackageInfo packageInfo?;
|};

# Coordinates identifying the package/module a cross-module `TypeRef` comes from.
#
# + org - The organization that owns the package
# + packageName - The package name
# + moduleName - The module name within the package
# + version - The package version
public type PackageInfo record {|
    string org;
    string packageName;
    string moduleName;
    string version;
|};

# A single `TypeRef`, or a union of alternatives ordered with the codegen default first.
public type TypeRefOrUnion TypeRef|TypeRef[];

# Whether a construct or field is mandatory.
public type Presence "required"|"optional";

# A listener entry point.
#
# + 'type - `TypeRef` for the listener class
# + services - `ServiceType.id` values this listener can host
# + requiredImports - Side-effect-only imports needed at runtime, never referenced by name
public type Listener record {|
    TypeRef 'type;
    string[] services;
    RequiredImport[] requiredImports?;
|};

# A package that must be imported for its side effect,
# e.g. `import ballerinax/mssql.cdc.driver as _;`.
#
# + importType - Why this import is needed, e.g. `"driver"`
# + packageInfo - The package to import
public type RequiredImport record {|
    "driver" importType;
    PackageInfo packageInfo;
|};

# One service-type alternative this connector exposes.
#
# + id - Referenced from `Listener.services` and sibling constructs
# + 'type - `TypeRef` for the service object type
# + concrete - `true` if the type declares its own methods directly (introspectable); `false` for marker/abstract types
# + multipleListenersAllowed - Can one service instance attach to more than one listener at once?
# + multipleServicesPerListenerAllowed - Can one listener host more than one service of this type at once?
# + identifier - Omitted entirely when the identifier slot carries no meaning for this service type
# + handlers - The handler-shape block
# + rules - Relationship constraints scoped to this service type
public type ServiceType record {|
    string id;
    TypeRef 'type;
    boolean concrete;
    boolean multipleListenersAllowed;
    boolean multipleServicesPerListenerAllowed;
    IdentifierSpec identifier?;
    Handlers handlers;
    Rule[] rules?;
|};

public type IdentifierForm "basePath"|"stringLiteral";

# The identifier slot's requiredness and legal syntactic form(s).
#
# + presence - Whether the identifier is required or optional
# + form - The legal syntactic forms this identifier can take
public type IdentifierSpec record {|
    Presence presence;
    IdentifierForm[] form;
|};

# How many of `HandlerOption`s can/must be implemented at once.
public type AddMode "many"|"subset";

# The handler-shape block for a service type.
#
# + backedByConcreteType - `true` means the type's own declared methods are the handlers and `options` is empty
# + addMode - Not present when `backedByConcreteType` is `true`
# + options - The only source of truth for handler shapes when `backedByConcreteType` is `false`
public type Handlers record {|
    boolean backedByConcreteType;
    AddMode addMode?;
    HandlerOption[] options;
|};

public type HandlerKind "remote"|"resource";

# A `{presence, values|form}` constraint used by resource-kind handler extras
# (HTTP's `method`/`path`, GraphQL's `accessor`/`fieldName`).
#
# + presence - Whether this extra is required or optional
# + values - The legal literal values, when this extra is an enum-like choice
# + form - The legal syntactic forms, when this extra describes a shape rather than a fixed value
public type ValueSpec record {|
    Presence presence;
    string[] values?;
    string[] form?;
|};

# One legal handler shape.
#
# + name - Handler method name, or `"*"` for an open/many-shaped handler
# + kind - `remote` or `resource`
# + presence - Only meaningful under `addMode: "subset"`
# + annotations - Ids into the top-level `annotations[]`, `attachPoint: "function"`
# + params - The handler's parameter list
# + returns - `TypeRef` or a union
# + method - Resource-kind extra (HTTP): legal HTTP verbs
# + path - Resource-kind extra (HTTP): legal path-segment shapes
# + accessor - Resource-kind extra (GraphQL): `get`/`subscribe`
# + fieldName - Resource-kind extra (GraphQL): field-name shape
# + graphqlOperation - Resource-kind extra (GraphQL): informational only
public type HandlerOption record {|
    string name;
    HandlerKind kind;
    Presence presence?;
    string[] annotations?;
    Param[] params?;
    TypeRefOrUnion 'returns?;
    ValueSpec method?;
    ValueSpec path?;
    ValueSpec accessor?;
    ValueSpec fieldName?;
    string graphqlOperation?;
|};

# One parameter of a handler option.
#
# + name - Optional domain-meaningful name; present only where source evidence shows it matters
# + 'type - `TypeRef` or a union; restates the full static surface even where `dataBinding` also implies it
# + presence - `required` or `optional` for this slot
# + addMode - `"many"` means this slot repeats zero or more times, each occurrence independently named/typed
# + dataBinding - Id into `dataBindingRules[]`; present only when the raw value can be projected into a user-defined type
# + annotations - Ids into `annotations[]`, `attachPoint: "parameter"`
public type Param record {|
    string name?;
    TypeRefOrUnion 'type;
    Presence presence;
    "many" addMode?;
    string dataBinding?;
    string[] annotations?;
|};

# The kind of relationship a `Rule` expresses:
# `oneOf` - exactly one member, not zero, not more than one.
# `atMostOne` - zero or one member, never more than one.
public type RuleType "oneOf"|"atMostOne";

# A relationship constraint scoped to the enclosing `ServiceType`.
#
# + id - Local identifier for this rule
# + 'type - The relationship kind this rule expresses
# + members - The participants in the relationship
public type Rule record {|
    string id;
    RuleType 'type;
    RuleMember[] members;
|};

# One participant in a `Rule`. Exactly one of `annotation`+`field`, `part`, or `handler` is set.
#
# + annotation - Id of a top-level annotation
# + field - Field name inside that annotation's record
# + preferred - Marks the canonical/idiomatic choice for a generator to default to
# + part - `"identifier"`, this service type's own identifier slot
# + handler - One of this service type's own `HandlerOption.name` values
public type RuleMember record {|
    string 'annotation?;
    string 'field?;
    boolean preferred?;
    "identifier" part?;
    string handler?;
|};

public type AttachPoint "service"|"function"|"parameter"|"return";

# A reusable annotation reference, defined once and referenced by id elsewhere.
#
# + id - Referenced from `Param.annotations`, `HandlerOption.annotations`, or `RuleMember.annotation`
# + 'type - `TypeRef` for the annotation type, can be cross-module
# + attachPoint - Where this annotation attaches in Ballerina source
# + appliesTo - `ServiceType.id` array; include only when no other reference already links this annotation
# + presence - Whether this annotation must be attached at all
public type Annotation record {|
    string id;
    TypeRef 'type;
    AttachPoint attachPoint;
    string[] appliesTo?;
    Presence presence;
|};

public type DataBindingMode "direct"|"includedRecord"|"streamable";

# One binding mode a `DataBindingRule` supports.
#
# + mode - `direct` (param type directly is the target, no wrapping), `includedRecord` (user
#          record does `*EnvelopeType;`, overrides only `bindableFields`), or `streamable`
#          (same as `direct`, but `stream<...>` over the target type)
# + typeConstraint - Legal alternatives, for `direct`/`streamable` modes
# + excludes - Types excluded from `typeConstraint`'s general category, e.g. `anydata` excluding the envelope type
# + includes - The base record being included via `*Type;`, for `includedRecord` mode
# + bindableFields - Field names the user's record is free to override, for `includedRecord` mode
public type SupportedMode record {|
    DataBindingMode mode;
    TypeRef[] typeConstraint?;
    TypeRef[] excludes?;
    TypeRef includes?;
    string[] bindableFields?;
|};

# One data-binding rule, defined once and referenced by id from `Param.dataBinding`.
#
# + id - Referenced from `Param.dataBinding`
# + cardinality - `"array"` means the bound value is a batch; a mode's type is the array element type
# + supportedModes - The legal binding modes for this rule
public type DataBindingRule record {|
    string id;
    "array" cardinality?;
    SupportedMode[] supportedModes;
|};
