# Task 1.1.1 — Load Root Ontology Files

## Overview

This document provides a comprehensive implementation plan for **Task 1.1.1: Load Root Ontology Files** from Phase 1 of the Ontology Documentation Platform.

**Task Components:**
- 1.1.1.1 Implement `.ttl` file reader
- 1.1.1.2 Validate file existence and readability
- 1.1.1.3 Register file metadata (path, base IRI, prefix map)

**Context:** This is the very first implementation task for a NEW project with no existing Elixir code. This task establishes the foundation for all subsequent ontology processing.

## Research Summary

### Elixir RDF Library Ecosystem

After thorough research, **RDF.ex** is the recommended library for this project:

**Key Features:**
- Full RDF 1.1 specification compliance
- Native Turtle format support via `RDF.Turtle` module
- Built-in support for OWL, RDFS, OWL, SKOS, and XSD vocabularies
- Comprehensive error handling with `{:ok, data}` / `{:error, reason}` tuples
- File streaming support for large ontologies
- MIT Licensed, actively maintained by Marcel Otto

**API Functions:**
- `RDF.Turtle.read_file/2` - Read Turtle from file path
- `RDF.Turtle.read_string/2` - Parse Turtle from string
- Bang variants (`read_file!/2`, `read_string!/2`) for exception-based error handling

### Project Structure Decision: Mix vs Phoenix

**Decision: Start with Mix, add Phoenix later**

**Rationale:**
1. Phase 1 is purely backend ontology processing with no UI requirements
2. Phoenix adds unnecessary overhead for the initial parsing layer
3. Following Elixir best practices: build the core domain logic first, then add the web layer
4. Phoenix will be added in Phase 2 when LiveView UI is needed

**Structure Approach:**
- Use a standard Mix project with context-based organization
- Create an `OntoView.Ontology` context for all ontology-related logic
- Separate concerns: file loading, parsing, validation, storage
- Prepare for umbrella app conversion if complexity grows

## Current Status

**What Works:**
- ✅ Planning document completed
- ✅ Feature branch created: `feature/phase-1.1.1-ttl-file-loader`

**What's Next:**
- 🔄 Bootstrap Mix project
- 🔄 Implement loader module
- 🔄 Create test suite

**How to Run:**
- Project not yet bootstrapped

## Implementation Plan

### Step 1: Project Bootstrap

```bash
# Create new Mix project
mix new onto_view --sup
cd onto_view
```

**Why `--sup` flag?**
- Creates an OTP application with supervision tree
- Essential for managing stateful processes (future triple store, cache)
- Allows graceful startup/shutdown of ontology loading pipeline

### Step 2: Add Dependencies

Add to `mix.exs`:

```elixir
defp deps do
  [
    # RDF and semantic web
    {:rdf, "~> 2.1"},

    # Testing and development
    {:ex_doc, "~> 0.31", only: :dev, runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

    # File system utilities
    {:jason, "~> 1.4"}  # For future JSON exports
  ]
end
```

### Step 3: Project Directory Structure

```
onto_view/
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   └── runtime.exs
├── lib/
│   ├── onto_view.ex
│   └── onto_view/
│       ├── ontology/
│       │   ├── loader.ex           # Task 1.1.1
│       │   ├── parser.ex           # Task 1.2.x
│       │   ├── import_resolver.ex  # Task 1.1.2
│       │   ├── triple_store.ex     # Task 1.2.3
│       │   ├── entity_extractor.ex # Task 1.3.x
│       │   └── query_api.ex        # Task 1.7.x
│       └── ontology.ex
├── test/
│   ├── test_helper.exs
│   ├── support/
│   │   └── fixtures/
│   └── onto_view/
│       └── ontology/
│           └── loader_test.exs
├── priv/
│   └── ontologies/
└── mix.exs
```

### Step 4: Implementation Details

See the full implementation design in the sections below for each subtask.

## Success Criteria

### Functional Requirements

- [ ] Can load valid Turtle files from filesystem
- [ ] Returns structured metadata (path, IRI, prefixes, graph)
- [ ] Validates file existence and readability
- [ ] Extracts base IRI from owl:Ontology or generates default
- [ ] Extracts all prefix mappings from Turtle declarations
- [ ] Handles errors gracefully with descriptive messages
- [ ] Supports gzipped files
- [ ] Provides both regular and bang variants

### Non-Functional Requirements

- [ ] 95%+ test coverage
- [ ] Zero compiler warnings
- [ ] Passes `mix format --check-formatted`
- [ ] Passes `mix credo --strict`
- [ ] All tests pass in CI environment
- [ ] Documentation complete with examples
- [ ] Handles files up to 100MB (with streaming)

## Notes

This implementation follows the planning created by the feature-planner agent with consultation from the elixir-expert agent.

---

**Document Version:** 1.0
**Created:** 2025-12-10
**Status:** 🔄 In Progress
