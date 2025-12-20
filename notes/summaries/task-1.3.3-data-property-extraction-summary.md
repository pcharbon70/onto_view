# Task 1.3.3 — Data Property Extraction Summary

## Overview

Task 1.3.3 implements OWL data property extraction from the canonical triple store, including datatype range detection.

## Subtasks Completed

### 1.3.3.1 Detect owl:DatatypeProperty

Implemented detection of `owl:DatatypeProperty` declarations by scanning for `rdf:type owl:DatatypeProperty` assertions in the triple store.

**Key implementation details:**
- Uses `TripleStore.by_predicate/2` to efficiently find all `rdf:type` assertions
- Filters for objects matching `owl:DatatypeProperty`
- Validates that subjects are IRIs (not blank nodes)
- Deduplicates by IRI to handle multi-ontology declarations

### 1.3.3.2 Register Datatype Ranges

Implemented datatype range extraction by scanning `rdfs:range` assertions for each data property.

**Key implementation details:**
- Uses `TripleStore.by_subject/2` to find all triples for a property
- Filters for `rdfs:range` predicates with IRI objects
- Supports common XSD datatypes: string, integer, boolean, date, dateTime, decimal, double, anyURI, time, duration
- Returns list of datatype IRIs (may be empty for untyped properties)

## Files Created

### Implementation
- `lib/onto_view/ontology/entity/data_property.ex` (340 lines)

### Tests
- `test/onto_view/ontology/entity/data_property_test.exs` (583 lines, 55 tests)

### Fixtures
- `test/support/fixtures/ontologies/entity_extraction/data_properties.ttl` (118 lines)
  - 14 data properties with various datatypes
  - 4 OWL classes for domain testing
  - Covers all common XSD datatypes

## API Reference

### Core Extraction Functions

```elixir
# Extract all data properties
DataProperty.extract_all(store) :: [DataProperty.t()]

# Extract as map for O(1) lookups
DataProperty.extract_all_as_map(store) :: %{String.t() => DataProperty.t()}

# Extract from specific ontology
DataProperty.extract_from_graph(store, graph_iri) :: [DataProperty.t()]
```

### Query Functions

```elixir
# Count data properties
DataProperty.count(store) :: non_neg_integer()

# Check if IRI is a data property
DataProperty.is_data_property?(store, iri) :: boolean()

# Get data property by IRI
DataProperty.get(store, iri) :: {:ok, DataProperty.t()} | {:error, :not_found}

# List all data property IRIs
DataProperty.list_iris(store) :: [String.t()]

# Find properties with a specific domain
DataProperty.with_domain(store, class_iri) :: [DataProperty.t()]

# Find properties with a specific datatype range
DataProperty.with_range(store, datatype_iri) :: [DataProperty.t()]

# Group properties by their datatype
DataProperty.group_by_datatype(store) :: %{(String.t() | :untyped) => [DataProperty.t()]}
```

### DataProperty Struct

```elixir
%DataProperty{
  iri: String.t(),           # Full IRI of the property
  source_graph: String.t(),  # Ontology graph IRI (provenance)
  domain: [String.t()],      # List of domain class IRIs
  range: [String.t()]        # List of datatype IRIs
}
```

## Supported Datatypes

The module supports all standard XSD datatypes:

| Datatype | IRI |
|----------|-----|
| String | `xsd:string` |
| Integer | `xsd:integer` |
| Boolean | `xsd:boolean` |
| Date | `xsd:date` |
| DateTime | `xsd:dateTime` |
| Decimal | `xsd:decimal` |
| Double | `xsd:double` |
| AnyURI | `xsd:anyURI` |
| Time | `xsd:time` |
| Duration | `xsd:duration` |

## Test Coverage

55 tests covering:

- **Task 1.3.3.1 tests:** 6 tests for property detection
- **Task 1.3.3.2 tests:** 12 tests for datatype range extraction
- **Domain extraction tests:** 3 tests
- **Provenance tracking:** 2 tests for source graph
- **API function tests:** 27 tests for all public functions
- **Integration tests:** 2 tests with classes.ttl fixture
- **Struct tests:** 2 tests for struct fields

## Test Fixture Data Properties

| Property | Domain | Range |
|----------|--------|-------|
| hasName | Person | xsd:string |
| hasAge | Person | xsd:integer |
| isActive | Person | xsd:boolean |
| birthDate | Person | xsd:date |
| createdAt | (any) | xsd:dateTime |
| hasPrice | Product | xsd:decimal |
| hasWeight | Product | xsd:double |
| hasDescription | Person, Organization, Product | xsd:string |
| hasIdentifier | (any) | xsd:string |
| hasNote | Person | (untyped) |
| hasValue | (any) | (untyped) |
| hasHomepage | Person | xsd:anyURI |
| startTime | Event | xsd:time |
| hasDuration | Event | xsd:duration |

## Integration Notes

The DataProperty module follows the same patterns as:
- `OntoView.Ontology.Entity.Class` (Task 1.3.1)
- `OntoView.Ontology.Entity.ObjectProperty` (Task 1.3.2)
- `OntoView.Ontology.Entity.Individual` (Task 1.3.4)

This ensures consistency across the OWL entity extraction layer and enables unified querying in later phases.

## Next Steps

- Task 1.3.99: Integration tests for OWL Entity Extraction
- Section 1.4: Class Hierarchy Graph Construction
