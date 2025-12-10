# Task 1.1.3 - Import Cycle Detection

**Feature Branch:** `feature/phase-1.1.3-cycle-detection`
**Date:** 2025-12-10
**Status:** In Progress

---

## Overview

Task 1.1.3 adds explicit circular dependency detection to the ontology import resolution system. While Task 1.1.2 already prevents infinite loops through visited set tracking, it does so silently. This task makes cycle detection explicit, providing diagnostic traces to help ontology authors identify and fix circular import issues.

## Objectives

Implement three subtasks:

1. **1.1.3.1** - Detect circular dependencies in owl:imports chains
2. **1.1.3.2** - Abort load operation when cycle is detected
3. **1.1.3.3** - Emit diagnostic dependency trace showing the circular path

## Current State Analysis

### Existing Cycle Prevention (Task 1.1.2)

The current `ImportResolver` (lib/onto_view/ontology/import_resolver.ex:81-156) uses a `MapSet` to track visited ontologies:

```elixir
visited = MapSet.new()
# ...
new_visited = MapSet.put(visited, iri)
# ...
unvisited_imports = Enum.reject(import_iris, &MapSet.member?(new_visited, &1))
```

**What this provides:**
- Prevents infinite loops
- Avoids duplicate loading

**What this lacks:**
- No explicit error when cycle is detected
- No visibility into circular dependency paths
- Silent skip behavior that masks ontology design problems
- No differentiation between "already loaded" vs "circular dependency"

## Key Design Decisions

### 1. Path Tracking vs Visited Set

**Problem:** We need to distinguish between two scenarios:

**Scenario A (Valid - Diamond Pattern):**
```
    A
   / \
  B   C
   \ /
    D
```
D is reached via two paths but is not a cycle. Should succeed.

**Scenario B (Invalid - Cycle):**
```
A → B → C → A
```
A appears in its own import chain. Should fail with diagnostic trace.

**Solution:** Track both:
- **Visited Set (MapSet):** Global tracking across all branches (prevents duplicate work)
- **Import Path (List):** Current import chain from root to current node (detects cycles)

### 2. Function Signature Changes

Update `load_recursively/7` to add path tracking:

**Before:**
```elixir
defp load_recursively(ontology, resolver, visited, depth, max_depth, acc, root_iri \\ nil)
```

**After:**
```elixir
defp load_recursively(ontology, resolver, visited, depth, max_depth, acc, root_iri \\ nil, path \\ [])
```

**Propagate through:**
- `load_imports/6` → `load_imports/7`
- `resolve_and_load_import/6` → `resolve_and_load_import/7`

### 3. Error Structure

Define new error type for circular dependencies:

```elixir
@type cycle_trace :: %{
  cycle_detected_at: String.t(),
  import_path: [String.t()],
  cycle_length: non_neg_integer(),
  human_readable: String.t()
}

{:error, {:circular_dependency, cycle_trace()}}
```

**Example error:**
```elixir
{:error, {:circular_dependency, %{
  cycle_detected_at: "http://example.org/A#",
  import_path: [
    "http://example.org/A#",
    "http://example.org/B#",
    "http://example.org/C#",
    "http://example.org/A#"
  ],
  cycle_length: 3,
  human_readable: "http://example.org/A# → http://example.org/B# → http://example.org/C# → [CYCLE START] http://example.org/A#"
}}}
```

### 4. Detection Logic Placement

**Where:** In `load_recursively/8`, before adding IRI to visited set (before line 117)

**Logic:**
```elixir
if iri in path do
  {:error, {:circular_dependency, build_cycle_trace(path, iri)}}
else
  new_path = path ++ [iri]
  new_visited = MapSet.put(visited, iri)
  # ... continue normal processing
end
```

**Rationale:** Check happens early, before any side effects (file loading, graph parsing)

### 5. Backwards Compatibility

**Existing behavior for non-cyclic ontologies:** Unchanged
- Same successful results
- Same performance characteristics
- All existing tests should pass without modification

**New behavior:** Explicit errors for cycles (currently fail silently or cause undefined behavior)

## Implementation Plan

### Subtask 1.1.3.1 - Detect Circular Dependencies

**File:** lib/onto_view/ontology/import_resolver.ex

**Changes:**

1. Add `path` parameter to function signatures:
   ```elixir
   defp load_recursively(ontology, resolver, visited, depth, max_depth, acc, root_iri \\ nil, path \\ [])
   defp load_imports(import_iris, resolver, visited, depth, max_depth, acc, path)
   defp resolve_and_load_import(import_iri, resolver, visited, depth, max_depth, acc, path)
   ```

2. Initialize path at root call (around line 85):
   ```elixir
   load_recursively(ontology, iri_resolver, visited, 0, max_depth, acc, nil, [])
   ```

3. Add cycle detection in `load_recursively` (before line 117):
   ```elixir
   iri = ontology.iri

   # Check for cycle
   if iri in path do
     {:error, {:circular_dependency, build_cycle_trace(path, iri)}}
   else
     new_path = path ++ [iri]
     new_visited = MapSet.put(visited, iri)
     # ... rest of existing logic
   end
   ```

4. Thread `new_path` through all recursive calls

### Subtask 1.1.3.2 - Abort Load on Cycle Detection

**Implementation:** Error propagation (leverage existing `with` and `case` statements)

**Verify:**
- No partial state returned when cycle detected
- Error bubbles up to `load_with_imports/2` public API
- No ontologies loaded after cycle detection

### Subtask 1.1.3.3 - Emit Diagnostic Dependency Trace

**Add private functions:**

```elixir
@spec build_cycle_trace([String.t()], String.t()) :: cycle_trace()
defp build_cycle_trace(path, iri) do
  full_path = path ++ [iri]
  cycle_start_index = Enum.find_index(path, &(&1 == iri))

  %{
    cycle_detected_at: iri,
    import_path: full_path,
    cycle_length: length(path) - cycle_start_index,
    human_readable: format_cycle_trace(full_path, cycle_start_index)
  }
end

@spec format_cycle_trace([String.t()], non_neg_integer()) :: String.t()
defp format_cycle_trace(path, cycle_start) do
  path
  |> Enum.with_index()
  |> Enum.map(fn {iri, idx} ->
    marker = if idx == cycle_start, do: "[CYCLE START] ", else: ""
    arrow = if idx > 0, do: " → ", else: ""
    "#{arrow}#{marker}#{iri}"
  end)
  |> Enum.join("")
end
```

**Add logging:**
```elixir
require Logger

if iri in path do
  trace = build_cycle_trace(path, iri)
  Logger.error("Circular dependency detected: #{trace.human_readable}")
  {:error, {:circular_dependency, trace}}
end
```

## Test Strategy

### Test Fixtures

**Directory:** test/support/fixtures/ontologies/cycles/

**Fixture 1: Direct Cycle (A → B → A)**

File: `cycle_a.ttl`
```turtle
@prefix : <http://example.org/cycle_a#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .

<http://example.org/cycle_a#> a owl:Ontology ;
    owl:imports <http://example.org/cycle_b#> .

:ClassA a owl:Class .
```

File: `cycle_b.ttl`
```turtle
@prefix : <http://example.org/cycle_b#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .

<http://example.org/cycle_b#> a owl:Ontology ;
    owl:imports <http://example.org/cycle_a#> .

:ClassB a owl:Class .
```

**Fixture 2: Indirect Cycle (A → B → C → A)**

Files: `indirect_a.ttl`, `indirect_b.ttl`, `indirect_c.ttl`

**Fixture 3: Self-Import (A → A)**

File: `self_import.ttl`
```turtle
@prefix : <http://example.org/self#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .

<http://example.org/self#> a owl:Ontology ;
    owl:imports <http://example.org/self#> .

:SelfClass a owl:Class .
```

**Fixture 4: Diamond Pattern (NOT a cycle - should succeed)**

```
diamond_root.ttl imports diamond_left.ttl and diamond_right.ttl
Both diamond_left.ttl and diamond_right.ttl import diamond_base.ttl
```

### Test Cases

**File:** test/onto_view/ontology/import_resolver_test.exs

**New describe block:**

```elixir
describe "cycle detection (Task 1.1.3)" do
  @cycles_dir Path.join(@fixtures_dir, "cycles")

  # 1.1.3.1 - Detect circular dependencies
  test "detects direct circular dependency (A → B → A)" do
    path = Path.join(@cycles_dir, "cycle_a.ttl")

    assert {:error, {:circular_dependency, trace}} =
      ImportResolver.load_with_imports(path)

    assert trace.cycle_detected_at == "http://example.org/cycle_a#"
    assert "http://example.org/cycle_a#" in trace.import_path
    assert "http://example.org/cycle_b#" in trace.import_path
    assert trace.cycle_length == 2
  end

  test "detects indirect circular dependency (A → B → C → A)" do
    path = Path.join(@cycles_dir, "indirect_a.ttl")

    assert {:error, {:circular_dependency, trace}} =
      ImportResolver.load_with_imports(path)

    assert trace.cycle_length == 3
    assert length(trace.import_path) == 4  # A, B, C, A
  end

  test "detects self-import (A → A)" do
    path = Path.join(@cycles_dir, "self_import.ttl")

    assert {:error, {:circular_dependency, trace}} =
      ImportResolver.load_with_imports(path)

    assert trace.cycle_length == 1
  end

  # 1.1.3.2 - Abort load on cycle detection
  test "aborts immediately on cycle detection" do
    path = Path.join(@cycles_dir, "cycle_a.ttl")

    assert {:error, {:circular_dependency, _}} =
      ImportResolver.load_with_imports(path)
  end

  test "does not confuse diamond pattern with cycle" do
    path = Path.join(@cycles_dir, "diamond_root.ttl")

    # Diamond: root → left → base, root → right → base
    # Base appears in two paths but isn't a cycle
    assert {:ok, result} = ImportResolver.load_with_imports(path)

    # Should successfully load all 4 ontologies
    assert map_size(result.ontologies) == 4
  end

  # 1.1.3.3 - Emit diagnostic dependency trace
  test "provides human-readable cycle trace" do
    path = Path.join(@cycles_dir, "indirect_a.ttl")

    assert {:error, {:circular_dependency, trace}} =
      ImportResolver.load_with_imports(path)

    assert is_binary(trace.human_readable)
    assert trace.human_readable =~ "[CYCLE START]"
    assert trace.human_readable =~ "→"
  end

  test "cycle trace shows exact import chain" do
    path = Path.join(@cycles_dir, "cycle_a.ttl")

    assert {:error, {:circular_dependency, trace}} =
      ImportResolver.load_with_imports(path)

    # Verify the path shows: A → B → A
    assert trace.import_path == [
      "http://example.org/cycle_a#",
      "http://example.org/cycle_b#",
      "http://example.org/cycle_a#"
    ]
  end
end
```

**Coverage target:** >95% for cycle detection code

## Performance Considerations

### Time Complexity

**Current:** O(n) where n = total number of ontologies
**New:** O(n × d) where d = average import depth

**Analysis:**
- Path membership check: O(d) per ontology
- Typical d = 3-5, so 3-5x overhead
- For 100 ontologies at depth 5: 500 operations (negligible)

**Optimization opportunity (if needed):**
- Use MapSet for path (O(1) lookup) instead of list
- Trade-off: Lose ordering, need separate structure for trace
- Recommendation: Start with list (simpler), optimize if benchmarks show issues

### Space Complexity

**Path storage:** O(d) per recursion stack frame
**Typical d = 5:** ~5 IRIs × ~100 bytes = 500 bytes per frame
**Impact:** Negligible

## Integration Notes

### Minimal Changes to Existing Code

The visited set logic (line 132) can remain unchanged:

```elixir
unvisited_imports =
  import_iris
  |> Enum.reject(&MapSet.member?(new_visited, &1))
```

This still prevents duplicate work across branches. The new cycle detection happens BEFORE this filter, distinguishing:
- "Already loaded in different branch" → skip (silent, OK)
- "In current import path" → error (cycle, NOT OK)

### Documentation Updates

**Update module docs:**
- Add cycle detection behavior to `@moduledoc`
- Document cycle error in `load_with_imports/2`
- Add `@type cycle_trace` specification

## Risk Analysis

### Risks and Mitigations

**Risk 1: Path tracking performance impact**
- Impact: Adding path parameter and list concatenation
- Mitigation: Negligible - typical depth is 3-5 levels
- Alternative: Reversed list with prepend (cheaper)

**Risk 2: Breaking existing tests**
- Impact: Function signature changes
- Mitigation: Only internal functions changed, public API unchanged
- Verification: All existing 31 tests should pass

**Risk 3: Edge case with max_depth**
- Impact: Cycle detection vs depth limit interaction
- Mitigation: Cycle check happens first, takes precedence
- Test: Verify cycle detected before max_depth error

## Success Criteria

- [ ] All 3 subtasks implemented
- [ ] 13 new tests passing
- [ ] All existing 31 tests still passing
- [ ] Coverage >95% for new code
- [ ] Code formatted with `mix format`
- [ ] Documentation updated
- [ ] Feature plan complete
- [ ] Summary report written
- [ ] Planning document updated

## Next Steps

1. Implement Subtask 1.1.3.1 - Cycle detection logic
2. Implement Subtask 1.1.3.3 - Diagnostic trace functions
3. Create test fixtures
4. Write comprehensive test suite
5. Run tests and verify coverage
6. Update planning document
7. Write summary report
8. Request commit and merge approval
