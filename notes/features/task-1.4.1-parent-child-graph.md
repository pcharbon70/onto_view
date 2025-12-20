# Task 1.4.1 — Parent → Child Graph

## Problem Statement

The OWL entity extraction system (Section 1.3) extracts individual classes but does not capture their hierarchical relationships. To enable hierarchical exploration and graph visualization, we need to build a class hierarchy graph based on `rdfs:subClassOf` relationships.

**Impact:**
- Enable hierarchical class exploration in UI
- Support graph visualization of class taxonomy
- Provide ancestry/descendant queries for classes
- Identify root classes and leaf classes

## Solution Overview

Implement a `ClassHierarchy` module that:

1. **Builds a subclass adjacency list** - Maps each parent class to its direct children
2. **Normalizes `owl:Thing` as root** - Ensures classes without explicit parents are children of `owl:Thing`

## Technical Details

### Files to Create

1. `lib/onto_view/ontology/hierarchy/class_hierarchy.ex` - Class hierarchy module
2. `test/onto_view/ontology/hierarchy/class_hierarchy_test.exs` - Hierarchy tests
3. `test/support/fixtures/ontologies/class_hierarchy.ttl` - Test fixture with hierarchies

### Files to Modify

1. `lib/onto_view/ontology/namespaces.ex` - Add `owl_thing/0` constant

### Module Design

#### OntoView.Ontology.Hierarchy.ClassHierarchy

```elixir
defmodule OntoView.Ontology.Hierarchy.ClassHierarchy do
  @moduledoc """
  Builds and queries the OWL class hierarchy based on rdfs:subClassOf relationships.

  ## Task Coverage

  - Task 1.4.1.1: Build subclass adjacency list
  - Task 1.4.1.2: Normalize owl:Thing as root
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.Namespaces

  @type t :: %__MODULE__{
    parent_to_children: %{String.t() => [String.t()]},
    root_iri: String.t()
  }

  defstruct [:parent_to_children, :root_iri]

  # Build hierarchy from triple store
  @spec build(TripleStore.t()) :: t()
  def build(store)

  # Get direct children of a class
  @spec children(t(), String.t()) :: [String.t()]
  def children(hierarchy, parent_iri)

  # Get all root classes (children of owl:Thing)
  @spec root_classes(t()) :: [String.t()]
  def root_classes(hierarchy)

  # Check if a class has children
  @spec has_children?(t(), String.t()) :: boolean()
  def has_children?(hierarchy, iri)

  # Get all leaf classes (classes with no children)
  @spec leaf_classes(t()) :: [String.t()]
  def leaf_classes(hierarchy)

  # Count children of a class
  @spec child_count(t(), String.t()) :: non_neg_integer()
  def child_count(hierarchy, parent_iri)
end
```

### Algorithm

1. **Extract all `rdfs:subClassOf` triples** from the store
2. **Build adjacency list**: For each triple `(child, rdfs:subClassOf, parent)`, add child to parent's list
3. **Find orphan classes**: Classes that are declared but have no `rdfs:subClassOf` relationship
4. **Normalize roots**: Add orphan classes as children of `owl:Thing`

### Edge Cases

- Classes with no explicit superclass → children of `owl:Thing`
- `owl:Thing` itself → special root node
- Multiple inheritance → class appears in multiple parent lists
- Circular subclass relationships → detect and handle gracefully
- Classes from different ontologies → all included in same hierarchy

## Success Criteria

1. All existing tests pass
2. New tests for ClassHierarchy module (target: 20+ tests)
3. Correctly identifies parent → child relationships
4. Normalizes orphan classes under `owl:Thing`
5. Handles multiple inheritance correctly
6. Provides efficient O(1) child lookups

## Implementation Plan

### Step 1: Add owl:Thing to Namespaces
- [ ] Add `owl_thing/0` function to Namespaces module

### Step 2: Create ClassHierarchy Module
- [ ] Create module with struct definition
- [ ] Implement `build/1` to extract subclass relationships
- [ ] Implement `children/2` for direct child lookup
- [ ] Implement `root_classes/1` for top-level classes
- [ ] Implement `has_children?/2` predicate
- [ ] Implement `leaf_classes/1` for terminal classes
- [ ] Implement `child_count/2` for counting children

### Step 3: Create Test Fixtures
- [ ] Create `class_hierarchy.ttl` with:
  - Simple linear hierarchy (A → B → C)
  - Multiple inheritance (D → E, F → E)
  - Orphan classes (no rdfs:subClassOf)
  - Classes with multiple children

### Step 4: Write Tests
- [ ] Test build/1 with various hierarchies
- [ ] Test children/2 returns correct children
- [ ] Test root_classes/1 identifies roots
- [ ] Test orphan normalization under owl:Thing
- [ ] Test multiple inheritance handling
- [ ] Test empty hierarchy handling

### Step 5: Verification
- [ ] Run full test suite
- [ ] Verify integration with TripleStore

## Notes

- This is the parent → child direction; Task 1.4.2 will add child → parent lookups
- Task 1.4.3 will add multiple inheritance detection utilities
- The hierarchy is built on-demand from the TripleStore, not cached (caching deferred to Phase 2)

## Current Status

- **Branch:** `feature/phase-1.4.1-parent-child-graph`
- **Status:** ✅ COMPLETED (2025-12-20)
- **What works:** All subtasks implemented, 30 tests passing
- **What's next:** Ready for commit and merge to develop
