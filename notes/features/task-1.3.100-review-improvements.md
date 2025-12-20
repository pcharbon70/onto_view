# Task 1.3.100 — Section 1.3 Review Improvements

## Problem Statement

The Section 1.3 code review identified 0 blockers, 3 concerns, and 8 suggestions for improving the OWL Entity Extraction modules. While the code is production-ready, addressing these items will improve maintainability, performance, and code quality.

**Impact:**
- Reduce code duplication by ~25% (~350 lines)
- Improve API consistency across entity modules
- Add defensive validation for security
- Enhance developer experience with better documentation

## Solution Overview

Implement improvements in priority order:

1. **Shared Helpers Module** - Extract duplicated code to `OntoView.Ontology.Entity.Helpers`
2. **Namespace Constants Module** - Create `OntoView.Ontology.Namespaces` for shared RDF/OWL IRIs
3. **Type Reference Standardization** - Consistent typespec references across modules
4. **Stream-Based Extraction** - Add `extract_all_stream/1` for memory-efficient processing
5. **IRI Validation** - Add length bounds checking for security
6. **Entity Limits** - Add optional `:limit` option to extraction functions
7. **Enhanced Error Messages** - Context-rich error tuples
8. **Moduledoc Examples** - Add usage examples to all modules

## Technical Details

### Files to Create

1. `lib/onto_view/ontology/namespaces.ex` - Shared namespace constants
2. `lib/onto_view/ontology/entity/helpers.ex` - Shared helper functions
3. `test/onto_view/ontology/namespaces_test.exs` - Namespace tests
4. `test/onto_view/ontology/entity/helpers_test.exs` - Helper tests

### Files to Modify

1. `lib/onto_view/ontology/entity/class.ex`
2. `lib/onto_view/ontology/entity/object_property.ex`
3. `lib/onto_view/ontology/entity/data_property.ex`
4. `lib/onto_view/ontology/entity/individual.ex`

### Module Design

#### OntoView.Ontology.Namespaces

```elixir
defmodule OntoView.Ontology.Namespaces do
  @moduledoc "Standard RDF/OWL/RDFS namespace IRIs"

  # Prefixes
  def rdf, do: "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  def rdfs, do: "http://www.w3.org/2000/01/rdf-schema#"
  def owl, do: "http://www.w3.org/2002/07/owl#"
  def xsd, do: "http://www.w3.org/2001/XMLSchema#"

  # RDF types
  def rdf_type, do: {:iri, rdf() <> "type"}

  # OWL entity types
  def owl_class, do: {:iri, owl() <> "Class"}
  def owl_object_property, do: {:iri, owl() <> "ObjectProperty"}
  def owl_datatype_property, do: {:iri, owl() <> "DatatypeProperty"}
  def owl_named_individual, do: {:iri, owl() <> "NamedIndividual"}
  # ... etc
end
```

#### OntoView.Ontology.Entity.Helpers

```elixir
defmodule OntoView.Ontology.Entity.Helpers do
  @moduledoc "Shared helper functions for OWL entity extraction"

  @max_iri_length 8192

  # Domain/range extraction (shared by ObjectProperty and DataProperty)
  def extract_domain(store, subject_iri)
  def extract_range(store, subject_iri)

  # IRI validation
  def validate_iri(iri)
  def valid_iri?(iri)

  # List helpers
  def filter_by_field(entities, field, value)
  def group_by_field(entities, field)

  # Limit application
  def apply_limit(enumerable, :infinity), do: enumerable
  def apply_limit(enumerable, limit), do: Enum.take(enumerable, limit)
end
```

## Success Criteria

1. All 197 existing tests pass
2. New tests for Helpers and Namespaces modules
3. No duplicate `extract_domain/2` or `extract_range/2` functions
4. All modules use Namespaces for IRI constants
5. Stream variants available for large ontology processing
6. IRI validation prevents excessively long IRIs
7. Error messages include context (IRI, entity type)

## Implementation Plan

### Step 1: Create Namespaces Module
- [x] Create `lib/onto_view/ontology/namespaces.ex`
- [x] Add all RDF/RDFS/OWL/XSD namespace constants
- [x] Write tests for namespace functions

### Step 2: Create Helpers Module
- [x] Create `lib/onto_view/ontology/entity/helpers.ex`
- [x] Extract `extract_domain/2` and `extract_range/2`
- [x] Add `validate_iri/1` function
- [x] Add `apply_limit/2` function
- [x] Write tests for helper functions

### Step 3: Refactor Entity Modules
- [x] Update Class module to use Namespaces and Helpers
- [x] Update ObjectProperty module
- [x] Update DataProperty module
- [x] Update Individual module
- [x] Add `extract_all_stream/1` to each module
- [x] Add `:limit` option to `extract_all/2`
- [x] Enhance error messages with context

### Step 4: Add Usage Examples
- [x] Add @moduledoc examples to Class
- [x] Add @moduledoc examples to ObjectProperty
- [x] Add @moduledoc examples to DataProperty
- [x] Add @moduledoc examples to Individual

### Step 5: Verification
- [x] Run full test suite
- [x] Verify no duplicate code
- [x] Check type references are consistent

## Notes

- Suggestion 6 (Property-based testing) and Suggestion 7 (Telemetry) are deferred to Phase 2 as they require additional dependencies
- Concern 1 (Performance/caching) is addressed by adding Stream-based extraction; full caching deferred to Phase 2

## Current Status

- **Branch:** `feature/phase-1.3.100-review-improvements`
- **Status:** ✅ COMPLETED (2025-12-20)
- **What works:** All improvements implemented, 307 tests passing (235 entity + 72 new)
- **What's next:** Ready for commit and merge to develop
