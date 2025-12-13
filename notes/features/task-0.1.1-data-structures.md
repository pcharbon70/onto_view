# Task 0.1.1 — Data Structure Definitions for OntologyHub

## Overview

This document provides a comprehensive implementation plan for **Task 0.1.1: Data Structure Definitions** from Phase 0 (Multi-Ontology Hub Architecture & Version Management).

**Task Components:**
- 0.1.1.1 Define `OntologySet` struct with comprehensive @type specs
- 0.1.1.2 Define `SetConfiguration` struct for config metadata
- 0.1.1.3 Define `State` struct for GenServer internal state
- 0.1.1.4 Create `OntologyHub` module skeleton with type definitions

**Context:** Phase 0 transforms OntoView from a single-ontology system into a multi-ontology hub capable of managing multiple independent ontology sets (e.g., Elixir, Ecto, Phoenix) with versioning, lazy loading, and LRU/LFU caching.

**Pattern Reference:** This implementation follows the nested struct pattern established in Phase 1's `ImportResolver` module (see `ImportNode`, `OntologyMetadata`, `ImportChain`, `LoadedOntologies` structs).

## Problem Statement

### Current Architecture Limitations

The existing Phase 1 implementation loads a single ontology graph with its imports. This design cannot:
- Host multiple independent ontology sets simultaneously
- Support version-based routing (e.g., `/sets/elixir/v1.17/docs` vs `/sets/elixir/v1.18/docs`)
- Implement lazy loading and caching of ontology sets
- Track access patterns for cache eviction
- Provide set-level metadata without loading full triple stores

### Phase 0 Requirements

Phase 0 introduces a **multi-ontology hub** with the following capabilities:

1. **Multiple Ontology Sets**: Manage independent sets (Elixir, Ecto, Phoenix, etc.)
2. **Versioning**: Each set can have multiple versions (v1.17, v1.18, latest, etc.)
3. **Lazy Loading**: Only load sets when requested, not at startup
4. **Intelligent Caching**: LRU/LFU eviction with configurable cache size
5. **Metadata Separation**: Lightweight configuration vs heavyweight loaded sets
6. **Provenance Tracking**: Full integration with Phase 1's triple store

### Key Design Principle

**Separation of Concerns**: Lightweight `SetConfiguration` (metadata) vs heavyweight `OntologySet` (fully loaded with triples).

This enables:
- Fast startup (only config loads, not ontologies)
- Efficient memory usage (cache only active sets)
- Quick set browsing UI (show all sets without loading)
- Smart caching decisions (based on metadata)

## Implementation Status

### ✅ Completed

- [x] Planning document created
- [x] Architecture design finalized

### 🚧 In Progress

- [ ] Implement VersionConfiguration struct
- [ ] Implement SetConfiguration struct
- [ ] Implement OntologySet struct
- [ ] Implement State struct
- [ ] Implement OntologyHub GenServer skeleton

### ⏳ Pending

- [ ] Write comprehensive tests
- [ ] Integration with Application supervision tree
- [ ] Configuration examples

## What Works

- Comprehensive planning document with detailed specifications
- Clear architecture based on Phase 1 patterns

## What's Next

1. Create module directory structure
2. Implement VersionConfiguration (no dependencies)
3. Implement SetConfiguration (depends on VersionConfiguration)
4. Implement OntologySet (depends on Phase 1 structs)
5. Implement State (depends on all above)
6. Create OntologyHub GenServer skeleton
7. Write tests

## How to Run

Not yet implemented - this is the planning phase.

Once implemented:
```bash
# Start IEx with the application
iex -S mix

# OntologyHub will start automatically via supervision tree
# Check it's running:
GenServer.whereis(OntoView.OntologyHub)
```

---

For detailed implementation specifications, see the full planning document above.
