// Ballerina type definitions for the Trigger Construct Spec (v1.0).
// Mirrors spec.md field-by-field; see spec.md for full semantics and worked examples.

# The root trigger-model document.
#
# + version - Spec version, as `v<major>.<minor>`. Minor is additive and must stay readable by an
#             older `v1.x` consumer. Major is structural and must be refused. See spec.md
#             section 11
# + listeners - Listener entry points
# + serviceTypes - Service-type alternatives this connector exposes
# + annotations - Registry of annotation types referenced elsewhere, defined once
# + rules - Constraints spanning more than one service type. Rules scoped to a single service type
#           live on that `ServiceType` instead; every `Subject` here must name its `serviceType`
public type TriggerModel record {|
    string version;
    Listener[] listeners;
    ServiceType[] serviceTypes;
    Annotation[] annotations?;
    Rule[] rules?;
|};

# A reference to a Ballerina type, optionally qualified with cross-module package info.
#
# + name - The type name. Same module as this file's own primary construct unless `packageInfo` is set
# + packageInfo - Present only when `name` comes from a different module
public type TypeRef record {|
    string name;
    PackageInfo packageInfo?;
|};

# Coordinates identifying the package/module a cross-module type reference comes from.
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
# + deprecated - Why this listener is deprecated. Present only when the library still accepts it
#                but no longer recommends it
# + services - `ServiceType.id` values this listener can host
# + multipleServicesAllowed - Can one instance of this listener host more than one service at all?
# + multipleServicesOfSameTypeAllowed - Can two of those services be of the same `ServiceType`?
#                                       Omitted when `multipleServicesAllowed` is `false`, where it
#                                       is impossible anyway. Absent means unconstrained
# + requiredImports - Side-effect-only imports needed at runtime, never referenced by name
# + platformDependencies - Native/binary dependencies needed at build time, never referenced by
#                          Ballerina `import`
public type Listener record {|
    TypeRef 'type;
    string deprecated?;
    string[] services;
    boolean multipleServicesAllowed;
    boolean multipleServicesOfSameTypeAllowed?;
    RequiredImport[] requiredImports?;
    PlatformDependency[] platformDependencies?;
|};

# A package that must be imported for its side effect,
# e.g. `import ballerinax/mssql.cdc.driver as _;`.
#
# + importType - Why this import is needed, for example `"driver"`
# + packageInfo - The package to import
public type RequiredImport record {|
    "driver" importType;
    PackageInfo packageInfo;
|};

# A native/binary dependency that must be declared in `Ballerina.toml`'s
# `[[platform.<javaVersion>.dependency]]` table, distinct from `RequiredImport` (a Ballerina
# package `import`): this is a jar the build must put on the classpath, not something referenced
# by module name. No `javaVersion`/`platform` key here, the generator knows the Java version of
# the distribution it targets, so restating it per connector would go stale. No `path` either,
# that is wherever the user places their own downloaded copy, which this metadata cannot know.
#
# + groupId - Maven-style group id for the artifact
# + artifactId - Maven-style artifact id for the artifact
# + version - Version, possibly a wildcard pattern, for example `3.1.*`
# + scope - `"provided"` when the jar must stay compile-time-only (e.g. a vendor license forbids
#           bundling it into the final artifact); absent means normally bundled
# + acquisition - How to obtain the artifact when it is not resolvable from a public repository
# + nativeLibraries - OS-specific native libraries this jar needs at run time
public type PlatformDependency record {|
    string groupId;
    string artifactId;
    string version;
    "provided" scope?;
    Acquisition acquisition?;
    NativeLibrary[] nativeLibraries?;
|};

# How to obtain a dependency the build cannot resolve from a public repository.
#
# + url - Where to obtain it. Machine-actionable, a tool can link to it or open it, which a
#         prose sentence alone does not allow
# + note - What the user must do once there: licensing, which file to choose, and so on
public type Acquisition record {|
    string url?;
    string note;
|};

# An OS specific native library the JVM must load at run time.
#
# Modeled separately from the jar because its absence is not a build failure. The package compiles
# and the service then fails at run time, so nothing in the build graph records the requirement.
#
# No environment variable field, since it is determined by `os` and is stated once in spec.md
# section 2.
#
# + os - Target operating system
# + file - The library file name to install for that OS
public type NativeLibrary record {|
    "linux"|"windows"|"macos" os;
    string file;
|};

# One service-type alternative this connector exposes.
#
# + id - Referenced from `Listener.services` and sibling constructs. Every id starts with `$`
# + 'type - `TypeRef` for the service object type
# + concrete - `true` if the type declares its own methods directly (introspectable); `false` for marker/abstract types
# + multipleListenersAllowed - Can one service instance attach to more than one listener at once?
# + deprecated - Why this service type is deprecated, as prose for a human
# + annotations - Ids into `TriggerModel.annotations`, `attachPoint: "service"`, the annotations
#                 attachable to a service of this type
# + identifier - Omitted entirely when the identifier slot carries no meaning for this service type
# + handlers - The handler-shape block
# + rules - Relationship constraints scoped to this service type
public type ServiceType record {|
    string id;
    TypeRef 'type;
    string deprecated?;
    string[] annotations?;
    boolean concrete;
    boolean multipleListenersAllowed;
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

# Whether a `HandlerOption` is one fixed method name, or a shape the user instantiates repeatedly
# under names of their own choosing.
public type AddMode "subset"|"many";

# The handler-shape block for a service type.
#
# + backedByConcreteType - `true` means the type's own declared methods are the handlers, and
#                          `options` is omitted, there is nothing this file could say that
#                          introspecting the type would not already answer
# + options - The only source of truth for handler shapes when `backedByConcreteType` is `false`;
#             omitted entirely when it is `true`
public type Handlers record {|
    boolean backedByConcreteType;
    HandlerOption[] options?;
|};

public type HandlerKind "remote"|"resource";

# A constraint on one part of a resource handler's signature.
#
# No syntactic form is recorded. What a resource path may look like is fixed by the Ballerina
# language, so restating it per connector would only repeat the language spec.
#
# + presence - Whether this part is required or optional
# + values - The legal literal values, when this part is an enum-like choice. A single `"*"` means
#            any value the language accepts, rather than a fixed set
public type ValueSpec record {|
    Presence presence;
    string[] values?;
|};

# One legal handler shape.
#
# + name - Under `subset`, the method name to emit. Under `many`, always `"*"`, since the user
#          names each instance
# + kind - `remote` or `resource`
# + addMode - `subset` (default when absent) means this is one fixed method name the user either
#             declares or does not, governed by `presence`. `many` means this is a shape the user
#             instantiates any number of times under names of their own choosing
# + doc - What this handler is for and when it fires. A handler described here has no concrete
#         type behind it, so there is no doc comment to introspect
# + deprecated - Why this handler is deprecated, as prose for a human. A generator emitting
#                Ballerina puts it in the `# # Deprecated` doc section
# + presence - Only meaningful under `addMode: "subset"`, a `many` shape has no fixed occurrence
#              count to require
# + annotations - Ids into the top-level `annotations[]`, `attachPoint: "function"`
# + returnAnnotations - Ids into the top-level `annotations[]`, `attachPoint: "return"`
# + params - The handler's parameter list
# + returns - `TypeRef` or a union
# + accessor - Resource kind only. The accessor in `resource function <accessor> <path>()`. HTTP
#              puts its verbs here, GraphQL puts `get` or `subscribe`
# + path - Resource kind only. The path in `resource function <accessor> <path>()`
public type HandlerOption record {|
    string name;
    HandlerKind kind;
    AddMode addMode?;
    string doc?;
    string deprecated?;
    Presence presence?;
    string[] annotations?;
    string[] returnAnnotations?;
    Param[] params?;
    TypeRefOrUnion 'returns?;
    ValueSpec accessor?;
    ValueSpec path?;
|};

# One parameter of a handler option.
#
# + name - The parameter name to emit. Required on every fixed slot, since codegen renders the
#          parameter from this entry alone. Omitted only when `addMode` is `"many"`, where the
#          user names each occurrence
# + doc - What this parameter carries. Same reason as `HandlerOption.doc`
# + deprecated - Why this parameter is deprecated, as prose for a human
# + 'type - `TypeRef` or a union; restates the full static surface even where `dataBinding` also implies it
# + presence - `required` or `optional` for this slot
# + addMode - `"many"` means this slot repeats zero or more times, each occurrence independently named/typed
# + dataBinding - Inline data binding for this slot; present only when the raw value can be
#                 projected into a user-defined type
# + annotations - Ids into `annotations[]`, `attachPoint: "parameter"`
public type Param record {|
    string name?;
    string doc?;
    string deprecated?;
    TypeRefOrUnion 'type;
    Presence presence;
    "many" addMode?;
    DataBinding dataBinding?;
    string[] annotations?;
|};

# Fields common to every `Subject`.
#
# + serviceType - `ServiceType.id` this subject belongs to. Defaults to the enclosing service type
#                 when the rule is nested; required in a top-level `TriggerModel.rules` entry
# + role - This subject's name within its rule. Asymmetric constraints fix the legal names
#          (e.g. `when`/`then`); symmetric ones use free-form labels, referenced by
#          `Rule.prefer`. Omit when the rule never needs to address it
public type SubjectBase record {|
    string serviceType?;
    string role?;
|};

# The service's identifier / base-path slot.
#
# + kind - Discriminator for this subject shape
public type IdentifierSubject record {|
    *SubjectBase;
    "identifier" kind;
|};

# An annotation as a whole, its presence, not any field inside it.
#
# + kind - Discriminator for this subject shape
# + name - Id into `TriggerModel.annotations`
public type AnnotationSubject record {|
    *SubjectBase;
    "annotation" kind;
    string name;
|};

# One field inside an annotation's value.
#
# + kind - Discriminator for this subject shape
# + annotation - Id into `TriggerModel.annotations`
# + path - Field path within that annotation's record; multi-element for nested fields,
#          e.g. `["retryConfig", "maxCount"]`
public type AnnotationFieldSubject record {|
    *SubjectBase;
    "annotationField" kind;
    string 'annotation;
    string[] path;
|};

# A handler function.
#
# + kind - Discriminator for this subject shape
# + name - One of the service type's `HandlerOption.name` values
public type HandlerSubject record {|
    *SubjectBase;
    "handler" kind;
    string name;
|};

# One parameter of a handler function.
#
# + kind - Discriminator for this subject shape
# + handler - The enclosing handler's name
# + name - The parameter's `Param.name`
public type ParamSubject record {|
    *SubjectBase;
    "param" kind;
    string handler;
    string name;
|};

# What a `Rule` constrains. A tagged union discriminated by `kind`. A consumer that does not
# recognise a `kind` skips the rule with a warning, the same policy as an unknown `Rule.rule` id.
public type Subject IdentifierSubject|AnnotationSubject|AnnotationFieldSubject|HandlerSubject|ParamSubject;

# Whether a rule violation blocks or merely advises.
public type Severity "error"|"warning";

# A relationship constraint. Rules are referenced, never defined here. `rule` names a constraint
# from an open registry the consumer already implements. Adding a constraint is a registry entry,
# not a schema change.
#
# + id - Stable identifier, unique within the file; surfaces in the emitted diagnostic
# + rule - Registry id such as `structure.exactlyOne`. Open vocabulary, so an unknown id is
#          skipped rather than failed
# + subjects - What this constraint ranges over
# + severity - Defaults to `"error"`
# + message - Diagnostic text for a consumer to surface. Recommended
# + prefer - `role` a generator should default to. A hint, never part of the constraint
public type Rule record {|
    string id;
    string rule;
    Subject[] subjects;
    Severity severity?;
    string message?;
    string prefer?;
|};

public type AttachPoint "service"|"function"|"parameter"|"return";

# A reusable annotation reference, defined once and referenced by id elsewhere.
#
# + id - Referenced from whichever construct the annotation attaches to: `ServiceType.annotations`
#        (service), `HandlerOption.annotations` (function), `HandlerOption.returnAnnotations`
#        (return), `Param.annotations` (parameter), or a `Rule` subject of kind
#        `annotation`/`annotationField`
# + 'type - `TypeRef` for the annotation type, can be cross-module
# + attachPoint - Where this annotation attaches in Ballerina source. Determines which construct
#                 field carries the reference, every attach point has a precise one, so there is
#                 no reverse `appliesTo` list
# + presence - Whether this annotation must be attached at all
public type Annotation record {|
    string id;
    TypeRef 'type;
    AttachPoint attachPoint;
    Presence presence;
|};

public type ShapeForm "bare"|"array"|"stream"|"included";

# One legal embedding of a `TypedescVariant`'s bound type in the final declared type.
#
# + form - `bare` (T stands alone, no wrapping), `array` (`T[]`), `stream` (`stream<T, ...>`), or
#          `included` (T spliced into one field of a fixed envelope record via `*Envelope;`)
# + element - For `array`/`stream`: whether each element is `bare` or an `included` record
# + envelope - For `included` (bare or nested under `array`/`stream`): the record spliced in via `*Envelope;`
# + bindableFields - For `included`: field names bound to this variant's typedesc; every other
#                    field of `envelope` stays fixed
# + completionType - For `stream`: the stream's completion type, for example `error?`
public type Shape record {|
    ShapeForm form;
    "bare"|"included" element?;
    TypeRef envelope?;
    string[] bindableFields?;
    TypeRef completionType?;
|};

# One independent `typedesc<T>`-bound variant within a `DataBinding`. Variants never share a
# bound or shapes with one another, each is fully self-describing, even when its values happen
# to coincide with another variant's. A rule with two alternative bounds that share identical
# shapes (e.g. `json` or `record {}`, both bare) is two variants, not one variant with a union
# `constraint`, `constraint` names exactly one type, so the variant itself stays simple.
#
# + constraint - This variant's `typedesc<T>` upper bound, exactly one type, never a union
# + excludes - Instantiations excluded from this variant's bound because another variant already
#              owns them (e.g. an envelope type excluded from a `bare` shape's `anydata` bound,
#              since that instantiation belongs to this rule's `included` variant instead)
# + shapes - Legal embeddings of this variant's bound; not shared with other variants
public type TypedescVariant record {|
    TypeRef constraint;
    TypeRef[] excludes?;
    Shape[] shapes;
|};

# Data binding for one parameter slot, written inline on the `Param` it belongs to.
#
# + typedescs - Independent typedesc variants; each carries its own bound and its own legal shapes
public type DataBinding record {|
    TypedescVariant[] typedescs;
|};
