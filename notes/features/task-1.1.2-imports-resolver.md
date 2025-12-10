# Task 1.1.2 — Resolve `owl:imports` Recursively

## Overview

This task extends the existing `OntoView.Ontology.Loader` to support recursive loading of imported ontologies while preserving provenance information.

**Subtasks:**
- 1.1.2.1 Parse `owl:imports` triples
- 1.1.2.2 Load all imported ontologies
- 1.1.2.3 Build recursive import chain
- 1.1.2.4 Preserve ontology-of-origin for each triple

## Current Status

**What Works:**
- ✅ Feature planning document completed
- ✅ Feature branch created: `feature/phase-1.1.2-imports-resolver`

**What's Next:**
- 🔄 Implement import extraction
- 🔄 Implement IRI resolution
- 🔄 Implement recursive loading
- 🔄 Implement provenance tracking

**How to Run:**
- Implementation not yet started

## Key Design Decisions

### 1. Provenance Storage
Using RDF.Dataset with named graphs where each ontology's triples are stored in a graph named by the ontology IRI.

### 2. IRI Resolution
Three-strategy approach:
1. File URI (file:///path/to/file.ttl)
2. Explicit mapping via configuration
3. Convention-based search in base directory

### 3. Data Structures
- Import chain: Tree structure tracking dependencies
- Loaded ontologies: Map of IRI → metadata
- Dataset: RDF.Dataset with named graphs for provenance

## Implementation Plan

See the comprehensive plan created by the feature-planner agent above for full details on:
- Architecture & design decisions
- Implementation details for each subtask
- Test strategy with fixtures
- Integration points with other tasks

---

**Document Version:** 1.0
**Created:** 2025-12-10
**Status:** 🔄 In Progress
