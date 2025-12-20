# Task 1.3.4 — Individual Extraction Summary

## Overview

Task 1.3.4 implements OWL named individual extraction from the canonical triple store, including class association detection.

## Subtasks Completed

### 1.3.4.1 Detect Named Individuals

Implemented detection of `owl:NamedIndividual` declarations by scanning for `rdf:type owl:NamedIndividual` assertions in the triple store.

**Key implementation details:**
- Uses `TripleStore.by_predicate/2` to efficiently find all `rdf:type` assertions
- Filters for objects matching `owl:NamedIndividual`
- Validates that subjects are IRIs (not blank nodes)
- Deduplicates by IRI to handle multi-ontology declarations

### 1.3.4.2 Associate Individuals with Their Classes

Implemented class membership extraction by scanning all `rdf:type` assertions for each individual.

**Key implementation details:**
- Uses `TripleStore.by_subject/2` to find all triples for an individual
- Filters for `rdf:type` predicates with IRI objects
- Excludes meta-types: `owl:NamedIndividual`, `owl:Class`, `rdfs:Class`, `owl:ObjectProperty`, `owl:DatatypeProperty`, `owl:AnnotationProperty`, `owl:Ontology`
- Returns list of class IRIs (may be empty for unclassified individuals)

## Files Created

### Implementation
- `lib/onto_view/ontology/entity/individual.ex` (282 lines)

### Tests
- `test/onto_view/ontology/entity/individual_test.exs` (456 lines, 43 tests)

### Fixtures
- `test/support/fixtures/ontologies/entity_extraction/individuals.ttl` (102 lines)
  - 9 named individuals with various class memberships
  - 5 OWL classes for membership testing
  - Object and data properties for relationship testing

## API Reference

### Core Extraction Functions

```elixir
# Extract all named individuals
Individual.extract_all(store) :: [Individual.t()]

# Extract as map for O(1) lookups
Individual.extract_all_as_map(store) :: %{String.t() => Individual.t()}

# Extract from specific ontology
Individual.extract_from_graph(store, graph_iri) :: [Individual.t()]
```

### Query Functions

```elixir
# Count individuals
Individual.count(store) :: non_neg_integer()

# Check if IRI is an individual
Individual.is_individual?(store, iri) :: boolean()

# Get individual by IRI
Individual.get(store, iri) :: {:ok, Individual.t()} | {:error, :not_found}

# List all individual IRIs
Individual.list_iris(store) :: [String.t()]

# Find individuals of a specific class
Individual.of_class(store, class_iri) :: [Individual.t()]

# Find individuals without class membership
Individual.without_class(store) :: [Individual.t()]
```

### Individual Struct

```elixir
%Individual{
  iri: String.t(),           # Full IRI of the individual
  source_graph: String.t(),  # Ontology graph IRI (provenance)
  classes: [String.t()]      # List of class IRIs (may be empty)
}
```

## Test Coverage

43 tests covering:

- **Task 1.3.4.1 tests:** 6 tests for individual detection
- **Task 1.3.4.2 tests:** 8 tests for class association
- **Provenance tracking:** 2 tests for source graph
- **API function tests:** 22 tests for all public functions
- **Integration tests:** 2 tests with classes.ttl fixture
- **Struct tests:** 2 tests for struct fields

## Test Fixture Individuals

| Individual | Classes |
|------------|---------|
| JohnDoe | Person |
| JaneSmith | Manager, Employee, Person |
| BobJohnson | Employee |
| AliceWilliams | Employee |
| CarolDavis | Manager |
| AcmeCorp | Organization |
| TechStartup | Organization |
| ProjectAlpha | Project |
| UnclassifiedEntity | (none) |

## Integration Notes

The Individual module follows the same patterns as:
- `OntoView.Ontology.Entity.Class` (Task 1.3.1)
- `OntoView.Ontology.Entity.ObjectProperty` (Task 1.3.2)

This ensures consistency across the OWL entity extraction layer and enables unified querying in later phases.

## Next Steps

- Task 1.3.3: Data Property Extraction (if not yet completed)
- Task 1.3.99: Integration tests for OWL Entity Extraction
- Section 1.4: Class Hierarchy Graph Construction
