# Task 1.4.1 — Parent → Child Graph Summary

## Overview

Task 1.4.1 implements the class hierarchy construction using `rdfs:subClassOf` relationships. This enables hierarchical exploration and graph visualization of OWL classes.

## Implementation

### New Module

Created `OntoView.Ontology.Hierarchy.ClassHierarchy` with the following capabilities:

**Core Functions:**
- `build/1` - Constructs hierarchy from TripleStore
- `children/2` - Gets direct children of a class
- `root_classes/1` - Gets classes directly under owl:Thing
- `has_children?/2` - Checks if class has children
- `leaf_classes/1` - Gets classes with no children
- `child_count/2` - Counts direct children
- `parents/1` - Lists all parent classes
- `class_count/1` - Total class count
- `class?/2` - Checks if IRI is a known class

### Task Coverage

**Task 1.4.1.1: Build subclass adjacency list**
- Extracts all `rdfs:subClassOf` triples from the store
- Builds parent → children map from triple relationships
- Handles multiple inheritance (class can appear under multiple parents)

**Task 1.4.1.2: Normalize owl:Thing as root**
- Identifies "orphan" classes (declared but no explicit superclass)
- Adds orphan classes as children of `owl:Thing`
- Uses IRI `http://www.w3.org/2002/07/owl#Thing` as universal root

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `lib/onto_view/ontology/hierarchy/class_hierarchy.ex` | 289 | Class hierarchy module |
| `test/onto_view/ontology/hierarchy/class_hierarchy_test.exs` | 253 | Hierarchy tests |
| `test/support/fixtures/ontologies/class_hierarchy.ttl` | 113 | Test fixture with hierarchies |
| `notes/features/task-1.4.1-parent-child-graph.md` | 100 | Feature planning document |

## Files Modified

| File | Changes |
|------|---------|
| `lib/onto_view/ontology/namespaces.ex` | Added `owl_thing/0` function |

## Test Fixture Design

The `class_hierarchy.ttl` fixture includes:

1. **Simple Linear Hierarchy**: Animal → Mammal → Dog/Cat
2. **Multiple Inheritance**: Student, Employee → WorkingStudent
3. **Orphan Classes**: Event, Location (no rdfs:subClassOf)
4. **Deep Hierarchy**: LevelA → LevelB → LevelC → LevelD → LevelE
5. **Wide Hierarchy**: Vehicle with 6 direct children

**Total classes in fixture:** 23

## Test Coverage

| Test Category | Tests |
|---------------|-------|
| build/1 | 3 |
| children/2 | 6 |
| root_classes/1 | 2 |
| has_children?/2 | 3 |
| leaf_classes/1 | 2 |
| child_count/2 | 4 |
| parents/1 | 2 |
| class_count/1 | 1 |
| class?/2 | 2 |
| Multiple inheritance | 2 |
| owl:Thing normalization | 3 |
| **Total** | **30 tests** |

## API Examples

```elixir
# Build hierarchy from triple store
hierarchy = ClassHierarchy.build(store)

# Get direct children
children = ClassHierarchy.children(hierarchy, "http://example.org/Animal")
# => ["http://example.org/Mammal"]

# Get root classes (under owl:Thing)
roots = ClassHierarchy.root_classes(hierarchy)
# => ["http://example.org/Animal", "http://example.org/Person", ...]

# Check for children
ClassHierarchy.has_children?(hierarchy, "http://example.org/Animal")
# => true

# Get leaf classes
leaves = ClassHierarchy.leaf_classes(hierarchy)
# => ["http://example.org/Dog", "http://example.org/Cat", ...]

# Count children
ClassHierarchy.child_count(hierarchy, "http://example.org/Vehicle")
# => 6
```

## Architecture Notes

- **Data Structure**: Uses MapSet for O(1) class membership checks
- **Adjacency List**: Map from parent IRI to list of child IRIs
- **Integration**: Builds on top of existing `TripleStore` and `Entity.Class` modules
- **Immutability**: Hierarchy struct is immutable; rebuild for updates

## Algorithm

1. Extract all declared classes using `Entity.Class.extract_all/1`
2. Query `rdfs:subClassOf` triples using `TripleStore.by_predicate/2`
3. Build parent → children adjacency list from triples
4. Identify orphan classes (declared but not in any subClassOf triple)
5. Add orphans as children of `owl:Thing`

## Next Steps

- **Task 1.4.2**: Child → Parent Graph (reverse lookup index)
- **Task 1.4.3**: Multiple Inheritance Detection
- **Task 1.4.99**: Unit Tests for Class Hierarchy
