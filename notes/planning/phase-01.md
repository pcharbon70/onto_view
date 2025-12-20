# 📄 phase-1.md

## Ontology Ingestion, Parsing & Canonical Model

------------------------------------------------------------------------

## 🎯 Phase 1 Objective

Phase 1 establishes the **entire semantic foundation** of the system.
Its purpose is to ingest one or more cascading OWL/Turtle ontologies,
resolve their import dependency graphs, normalize all RDF triples,
extract OWL entities, compute class and property relationships, and
expose a stable, deterministic **canonical ontology query API** for all
downstream UI, visualization, and export layers.

------------------------------------------------------------------------

## 🧩 Section 1.1 --- Ontology File Loading & Import Resolution

This section ensures that one or more Turtle ontology files can be
loaded together into a **single logical ontology graph**, while fully
resolving recursive `owl:imports` relationships. Provenance must be
preserved and import cycles must be safely detected and rejected.

------------------------------------------------------------------------

### ✅ Task 1.1.1 --- Load Root Ontology Files

-   [x] 1.1.1.1 Implement `.ttl` file reader\
-   [x] 1.1.1.2 Validate file existence and readability\
-   [x] 1.1.1.3 Register file metadata (path, base IRI, prefix map)

**Status:** ✅ COMPLETED (2025-12-10)
**Implementation:** `lib/onto_view/ontology/loader.ex`
**Tests:** `test/onto_view/ontology/loader_test.exs` (16 tests, 87% coverage)

------------------------------------------------------------------------

### ✅ Task 1.1.2 --- Resolve `owl:imports` Recursively

-   [x] 1.1.2.1 Parse `owl:imports` triples\
-   [x] 1.1.2.2 Load all imported ontologies\
-   [x] 1.1.2.3 Build recursive import chain\
-   [x] 1.1.2.4 Preserve ontology-of-origin for each triple

**Status:** ✅ COMPLETED (2025-12-10)
**Implementation:** `lib/onto_view/ontology/import_resolver.ex`
**Tests:** `test/onto_view/ontology/import_resolver_test.exs` (15 tests, 88.5% coverage)

------------------------------------------------------------------------

### ✅ Task 1.1.3 --- Import Cycle Detection

-   [x] 1.1.3.1 Detect circular dependencies\
-   [x] 1.1.3.2 Abort load on cycle detection\
-   [x] 1.1.3.3 Emit diagnostic dependency trace

**Status:** ✅ COMPLETED (2025-12-10)
**Implementation:** `lib/onto_view/ontology/import_resolver.ex`
**Tests:** `test/onto_view/ontology/import_resolver_test.exs` (41 tests total, 89.5% coverage)

------------------------------------------------------------------------

### ✅ Task 1.1.99 --- Unit Tests: Ontology Import Resolution

-   [x] 1.1.99.1 Loads a single ontology correctly\
-   [x] 1.1.99.2 Resolves multi-level imports correctly\
-   [x] 1.1.99.3 Detects circular imports reliably\
-   [x] 1.1.99.4 Preserves per-ontology provenance correctly

**Status:** ✅ COMPLETED (2025-12-10)
**Implementation:** `test/onto_view/ontology/integration_test.exs`
**Tests:** 61 total tests (20 new integration tests), 89.2% coverage

------------------------------------------------------------------------

### ✅ Section 1.1 Code Review & Security Hardening

-   [x] Comprehensive code review completed\
-   [x] Priority 0 (critical) security fixes implemented\
-   [x] Priority 1 improvements implemented

**Status:** ✅ COMPLETED (2025-12-11)

**Priority 0 Security Fixes (COMPLETED 2025-12-10):**
-   [x] Path traversal prevention with base_dir enforcement
-   [x] Symlink detection and rejection
-   [x] File size limits (10MB default, configurable)
-   [x] Resource exhaustion detection (max_depth, max_total_imports, max_imports_per_ontology)
-   [x] File type validation (reject directories and special files)

**Priority 1 Improvements (COMPLETED 2025-12-11):**
-   [x] Resource exhaustion enforcement (errors now propagate instead of continuing)
-   [x] Error message sanitization via ErrorSanitizer module
-   [x] Code deduplication via RdfHelpers and FixtureHelpers modules
-   [x] Comprehensive security test suite (20 tests)
-   [x] Resource limits test suite (13 tests)

**Implementation:**
-   `lib/onto_view/ontology/error_sanitizer.ex` (186 lines, 96.6% coverage)
-   `lib/onto_view/ontology/rdf_helpers.ex` (178 lines)
-   `test/support/fixture_helpers.ex` (82 lines, 100% coverage)
-   `test/onto_view/ontology/security_test.exs` (282 lines, 20 tests)
-   `test/onto_view/ontology/resource_limits_test.exs` (172 lines, 13 tests)
-   Modified: `lib/onto_view/ontology/import_resolver.ex` (resource limit enforcement)

**Tests:** 143 total tests (121 passing, 22 RdfHelpers deferred), 85.2% coverage

**Documentation:**
-   Review: `notes/reviews/section-1.1-comprehensive-review.md`
-   Summary: `notes/summaries/section-1.1-priority-1-improvements-summary.md`

------------------------------------------------------------------------

## 🧩 Section 1.2 --- RDF Triple Parsing & Canonical Normalization

This section converts raw Turtle syntax into a **canonical RDF triple
store** independent of source formatting. This normalized layer becomes
the sole foundation for all OWL semantic extraction.

------------------------------------------------------------------------

### ✅ Task 1.2.1 --- RDF Triple Parsing

-   [x] 1.2.1.1 Parse `(subject, predicate, object)` triples\
-   [x] 1.2.1.2 Normalize IRIs\
-   [x] 1.2.1.3 Expand prefix mappings\
-   [x] 1.2.1.4 Separate literals from IRIs

**Status:** ✅ COMPLETED (2025-12-13)
**Implementation:**
- `lib/onto_view/ontology/triple_store.ex` (TripleStore module)
- `lib/onto_view/ontology/triple_store/triple.ex` (Triple struct)
- `lib/onto_view/ontology.ex` (Added build_triple_store/1)
**Tests:**
- `test/onto_view/ontology/triple_test.exs` (26 tests)
- `test/onto_view/ontology/triple_store_test.exs` (57 tests, 1 skipped)
**Coverage:** 100% for new modules (all subtasks fully tested)
**Fixtures:** `test/support/fixtures/ontologies/blank_nodes.ttl`
**Bug Fix:** Fixed provenance tracking in ImportResolver.build_provenance_dataset/1

------------------------------------------------------------------------

### ✅ Task 1.2.2 --- Blank Node Stabilization

-   [x] 1.2.2.1 Detect blank nodes\
-   [x] 1.2.2.2 Generate stable internal identifiers\
-   [x] 1.2.2.3 Preserve blank node reference consistency

**Status:** ✅ COMPLETED (2025-12-13)
**Implementation:**
- `lib/onto_view/ontology/triple_store/blank_node_stabilizer.ex` (BlankNodeStabilizer module)
- `lib/onto_view/ontology/triple_store.ex` (Integration with triple extraction)
**Tests:**
- `test/onto_view/ontology/blank_node_stabilizer_test.exs` (29 tests)
**Coverage:** 100% for new module
**Design:** Hybrid provenance + incremental counter strategy
**Format:** `"{ontology_iri}_bn{counter}"` (e.g., "http://example.org/ont#_bn0001")

------------------------------------------------------------------------

### ✅ Task 1.2.3 --- Triple Indexing Engine

-   [x] 1.2.3.1 Index by subject\
-   [x] 1.2.3.2 Index by predicate\
-   [x] 1.2.3.3 Index by object

**Status:** ✅ COMPLETED (2025-12-13)
**Implementation:**
- `lib/onto_view/ontology/triple_store.ex` (Added indexes to struct, build functions, query functions)
**Tests:**
- `test/onto_view/ontology/triple_indexing_test.exs` (39 tests: 7 doctests + 32 unit tests)
**Coverage:** 100% for index building and query functions
**Design:** Map-based indexes using `Enum.group_by/2`
**Performance:** O(log n) lookups vs O(n) linear scans
**Query Functions:** `by_subject/2`, `by_predicate/2`, `by_object/2`

------------------------------------------------------------------------

### ✅ Task 1.2.99 --- Unit Tests: Triple Normalization

-   [ ] 1.2.99.1 IRIs normalized correctly\
-   [ ] 1.2.99.2 Prefixed names expand correctly\
-   [ ] 1.2.99.3 Blank nodes stabilize\
-   [ ] 1.2.99.4 Triple indexes resolve correctly

------------------------------------------------------------------------

## 🧩 Section 1.3 --- OWL Entity Extraction

This section extracts all OWL semantic entities including **classes,
object properties, data properties, and individuals** across all
imported ontologies.

------------------------------------------------------------------------

### ✅ Task 1.3.1 --- Class Extraction

-   [x] 1.3.1.1 Detect `owl:Class`\
-   [x] 1.3.1.2 Extract class IRIs\
-   [x] 1.3.1.3 Attach ontology-of-origin metadata

**Status:** ✅ COMPLETED (2025-12-19)
**Implementation:** `lib/onto_view/ontology/entity/class.ex`
**Tests:** `test/onto_view/ontology/entity/class_test.exs` (26 tests, 100% coverage)
**Fixtures:**
- `test/support/fixtures/ontologies/entity_extraction/classes.ttl`
- `test/support/fixtures/ontologies/entity_extraction/classes_imported.ttl`
- `test/support/fixtures/ontologies/entity_extraction/classes_with_imports.ttl`
**Summary:** `notes/summaries/task-1.3.1-class-extraction-summary.md`

------------------------------------------------------------------------

### ✅ Task 1.3.2 --- Object Property Extraction

-   [x] 1.3.2.1 Detect `owl:ObjectProperty`\
-   [x] 1.3.2.2 Register domain placeholders\
-   [x] 1.3.2.3 Register range placeholders

**Status:** ✅ COMPLETED (2025-12-20)
**Implementation:** `lib/onto_view/ontology/entity/object_property.ex`
**Tests:** `test/onto_view/ontology/entity/object_property_test.exs` (39 tests, 100% coverage)
**Fixtures:**
- `test/support/fixtures/ontologies/entity_extraction/object_properties.ttl`
**Summary:** `notes/summaries/task-1.3.2-object-property-extraction-summary.md`

------------------------------------------------------------------------

### ✅ Task 1.3.3 --- Data Property Extraction

-   [ ] 1.3.3.1 Detect `owl:DataProperty`\
-   [ ] 1.3.3.2 Register datatype ranges

------------------------------------------------------------------------

### ✅ Task 1.3.4 --- Individual Extraction

-   [x] 1.3.4.1 Detect named individuals\
-   [x] 1.3.4.2 Associate individuals with their classes

**Status:** ✅ COMPLETED (2025-12-20)
**Implementation:** `lib/onto_view/ontology/entity/individual.ex`
**Tests:** `test/onto_view/ontology/entity/individual_test.exs` (43 tests, 100% coverage)
**Fixtures:**
- `test/support/fixtures/ontologies/entity_extraction/individuals.ttl`
**Summary:** `notes/summaries/task-1.3.4-individual-extraction-summary.md`

------------------------------------------------------------------------

### ✅ Task 1.3.99 --- Unit Tests: OWL Entity Extraction

-   [ ] 1.3.99.1 Detects all classes correctly\
-   [ ] 1.3.99.2 Detects all properties correctly\
-   [ ] 1.3.99.3 Detects all individuals correctly\
-   [ ] 1.3.99.4 Prevents duplicate IRIs

------------------------------------------------------------------------

## 🧩 Section 1.4 --- Class Hierarchy Graph Construction

This section builds the **full subclass taxonomy** using
`rdfs:subClassOf`, enabling hierarchical exploration and graph
visualization.

------------------------------------------------------------------------

### ✅ Task 1.4.1 --- Parent → Child Graph

-   [ ] 1.4.1.1 Build subclass adjacency list\
-   [ ] 1.4.1.2 Normalize `owl:Thing` as root

------------------------------------------------------------------------

### ✅ Task 1.4.2 --- Child → Parent Graph

-   [ ] 1.4.2.1 Build reverse lookup index\
-   [ ] 1.4.2.2 Enable ancestry traversal

------------------------------------------------------------------------

### ✅ Task 1.4.3 --- Multiple Inheritance Detection

-   [ ] 1.4.3.1 Detect multiple parents\
-   [ ] 1.4.3.2 Preserve all inheritance paths

------------------------------------------------------------------------

### ✅ Task 1.4.99 --- Unit Tests: Class Hierarchy

-   [ ] 1.4.99.1 Builds correct subclass chains\
-   [ ] 1.4.99.2 Supports multiple inheritance\
-   [ ] 1.4.99.3 Detects root classes correctly

------------------------------------------------------------------------

## 🧩 Section 1.5 --- Property Domain & Range Resolution

This section establishes **semantic connectivity** between classes using
OWL object and data property definitions.

------------------------------------------------------------------------

### ✅ Task 1.5.1 --- Domain Resolution

-   [ ] 1.5.1.1 Extract `rdfs:domain`\
-   [ ] 1.5.1.2 Map outbound relation tables

------------------------------------------------------------------------

### ✅ Task 1.5.2 --- Range Resolution

-   [ ] 1.5.2.1 Extract `rdfs:range`\
-   [ ] 1.5.2.2 Map inbound relation tables

------------------------------------------------------------------------

### ✅ Task 1.5.3 --- Data Property Typing

-   [ ] 1.5.3.1 Attach XSD datatype IRIs\
-   [ ] 1.5.3.2 Validate datatype semantics

------------------------------------------------------------------------

### ✅ Task 1.5.99 --- Unit Tests: Property Mappings

-   [ ] 1.5.99.1 Domains resolve correctly\
-   [ ] 1.5.99.2 Ranges resolve correctly\
-   [ ] 1.5.99.3 Object/data properties are separated correctly

------------------------------------------------------------------------

## 🧩 Section 1.6 --- Annotation & Documentation Metadata

This section extracts and normalizes all **human-readable documentation
signals** intended for UI rendering.

------------------------------------------------------------------------

### ✅ Task 1.6.1 --- Label Extraction

-   [ ] 1.6.1.1 Extract `rdfs:label`\
-   [ ] 1.6.1.2 Preserve language tags

------------------------------------------------------------------------

### ✅ Task 1.6.2 --- Comment & Definition Extraction

-   [ ] 1.6.2.1 Extract `rdfs:comment`\
-   [ ] 1.6.2.2 Extract `skos:definition`\
-   [ ] 1.6.2.3 Extract `dc:description`

------------------------------------------------------------------------

### ✅ Task 1.6.99 --- Unit Tests: Annotations

-   [ ] 1.6.99.1 Multi-language labels supported\
-   [ ] 1.6.99.2 Comments bind to correct entities

------------------------------------------------------------------------

## 🧩 Section 1.7 --- Canonical Ontology Query API

This section defines the **official semantic boundary** between ontology
infrastructure and all UI layers.

------------------------------------------------------------------------

### ✅ Task 1.7.1 --- Public Query Functions

-   [ ] 1.7.1.1 Implement `list_classes/0`\
-   [ ] 1.7.1.2 Implement `get_class/1`\
-   [ ] 1.7.1.3 Implement `list_properties/0`\
-   [ ] 1.7.1.4 Implement `get_property/1`\
-   [ ] 1.7.1.5 Implement `get_inbound_relations/1`\
-   [ ] 1.7.1.6 Implement `get_outbound_relations/1`

------------------------------------------------------------------------

### ✅ Task 1.7.99 --- Unit Tests: Query API

-   [ ] 1.7.99.1 Query consistency guaranteed\
-   [ ] 1.7.99.2 Import completeness guaranteed\
-   [ ] 1.7.99.3 Deterministic ordering enforced

------------------------------------------------------------------------

## 🔗 Section 1.99 --- Phase 1 Integration Testing

This section validates that **all ontologies operate as a single unified
semantic graph**.

------------------------------------------------------------------------

### ✅ Task 1.99.1 --- Multi-Ontology Load Validation

-   [ ] 1.99.1.1 Load all 5 Elixir ontologies together\
-   [ ] 1.99.1.2 Resolve full import dependency chain

------------------------------------------------------------------------

### ✅ Task 1.99.2 --- Cross-Ontology Graph Traversal

-   [ ] 1.99.2.1 Traverse subclass chains across ontology boundaries\
-   [ ] 1.99.2.2 Traverse property relations across ontology boundaries

------------------------------------------------------------------------

### ✅ Task 1.99.3 --- Global Integrity Validation

-   [ ] 1.99.3.1 Validate zero duplicate entities\
-   [ ] 1.99.3.2 Validate all IRIs dereference cleanly

