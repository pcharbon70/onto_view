# CLAUDE.md

This file provides guidance when working with code in this repository.

## Project Overview

This is a **Phoenix LiveView-based ontology documentation system** for OWL/RDF ontologies expressed in Turtle. The project ingests interrelated ontologies, builds a canonical semantic model, and exposes them through:

- A textual, accordion-based documentation UI
- An interactive graph visualization synchronized in real-time

**Target users:** Domain scientists and software developers exploring complex ontologies (e.g., Elixir core ontologies).

## Development Stack

- **Backend:** Elixir + Phoenix + LiveView
- **Ontology Core:** OWL + RDF + Turtle parsing
- **Graph Engine:** JavaScript hooks with force-directed layout (D3/Cytoscape)
- **Deployment Target:** Fly.io / containerized Phoenix release
- **Elixir Version:** 1.17.3 (OTP 27.0 as per CI)

## Build & Test Commands

Since the implementation hasn't started yet, these commands will be relevant once the Phoenix project is bootstrapped:

```bash
# Install dependencies
mix deps.get

# Format code
mix format

# Run all tests
mix test

# Run tests with coverage
MIX_ENV=test mix test --cover

# Compile with warnings as errors
MIX_ENV=test mix compile --warnings-as-errors

# Start Phoenix server (once implemented)
mix phx.server  # Access at http://localhost:4000/docs

# Validate ontology TTL files (once script exists)
./scripts/validate_ttl.sh
```

## Five-Phase Architecture

Development follows a strict phased approach documented in `notes/planning/`:

1. **Phase 1** (`phase-01.md`) — Ontology Ingestion & Canonical Model
   - RDF/Turtle parsing with recursive `owl:imports` resolution
   - Triple normalization and OWL entity extraction
   - Class hierarchy and property domain/range modeling
   - Canonical query API exposing `list_classes/0`, `get_class/1`, `list_properties/0`, etc.

2. **Phase 2** (`phase-02.md`) — Phoenix LiveView Textual Documentation UI
   - LiveView routing (`/docs`, `/docs/classes/:id`, `/docs/properties/:id`, `/docs/individuals/:id`)
   - Hierarchical accordion explorer with expand/collapse
   - Live semantic search and filtering
   - Full class, property, and individual documentation views

3. **Phase 3** (`phase-03.md`) — Interactive Graph Visualization
   - Graph projection of classes and relations
   - Force-directed layout with pan/zoom
   - Bidirectional synchronization between graph and textual UI
   - Graph filtering and focus modes

4. **Phase 4** (`phase-04.md`) — UX, Property Docs & Accessibility
   - Enhanced property and individual documentation
   - Navigation, breadcrumbs, and UI state persistence
   - Keyboard navigation and ARIA support
   - WCAG 2.1 AA compliance

5. **Phase 5** (`phase-05.md`) — Export, CI/CD & Deployment
   - TTL and JSON export APIs
   - Versioning and release metadata
   - CI pipeline with ontology & UI validation
   - Read-only production Phoenix deployment

**Critical:** Work must align with the correct phase. Do not implement Phase 3-5 features while Phase 1 blockers are unresolved.

## Task Numbering System

All tasks follow the format: `Phase.Section.Task.Subtask`

- Example: Task `2.3.1` = Phase 2, Section 3 (Live Search), Task 1 (Full-Text Search Index)
- Subtasks: `2.3.1.1`, `2.3.1.2`, `2.3.1.3`
- Integration tests: `X.99.Y` (e.g., `1.99.1` for Phase 1 integration tests)

## GitHub Workflow

### Branching Strategy
- `main` — stable production branch
- `develop` — active integration branch
- `feature/<phase>-<name>` — all feature work
  - Example: `feature/phase-2-live-search`
  - Example: `feature/phase-1.3.1-class-extraction`

### Labels
- Phase: `phase:1-ontology-core`, `phase:2-textual-ui`, `phase:3-graph-visualization`, `phase:4-ux-accessibility`, `phase:5-export-deployment`
- Section: `section:1.1-imports`, `section:2.3-search`, `section:3.1-graph-projection`, etc.
- Type: `type:feature`, `type:bug`, `type:refactor`, `type:documentation`, `type:testing`, `type:accessibility`
- Ontology: `ontology:parsing`, `ontology:graph`, `ontology:export`, `ontology:canonical-query`

### Issue Templates
Use `.github/ISSUE_TEMPLATE/feature_task.md` for tasks. Title format: `Task X.X.X — <short description>`

### Milestones
Map to phases:
- Phase 1 – Ontology Ingestion & Canonical Model
- Phase 2 – LiveView Textual Documentation UI
- Phase 3 – Interactive Graph Visualization
- Phase 4 – UX, Property Docs & Accessibility
- Phase 5 – Export, CI/CD & Deployment

## Code Style

### Elixir/Phoenix
- Use `mix format` for all code
- Prefer pure functions over stateful operations
- Use pattern matching over conditionals
- No business logic in LiveView templates
- All contributions require unit tests

### JavaScript (Graph)
- No direct DOM mutation outside Phoenix hooks
- Graph must fully rehydrate on LiveView patch
- Avoid global state

## Testing Requirements

Every contribution must include:
- Unit tests for each task/subtask
- Integration tests at the end of each phase (section X.99)
- Ontology validation tests (for Phase 1)
- LiveView interaction tests (for Phases 2-4)
- Graph behavior tests (for Phase 3)

CI enforces test passage before merge.

## Ontology Contribution Rules

When working with `.ttl` ontology files:
- Must validate with TTL parser
- Must resolve all `owl:imports` correctly
- Must include `rdfs:label` and `rdfs:comment`
- Must specify proper domain/range for properties
- Must not break Phase 1 ingestion tests

## Accessibility Standards

All UI work must:
- Preserve keyboard navigation
- Use ARIA roles for interactive components
- Maintain WCAG 2.1 AA contrast ratios
- Avoid color-only semantic indicators
- Remain usable without graph enabled

## CI Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):
1. Installs Elixir 1.17.3 + OTP 27.0
2. Caches Mix dependencies
3. Runs `mix format --check-formatted`
4. Compiles with `--warnings-as-errors`
5. Runs `mix test`
6. Validates TTL files (once script exists)
7. Validates documentation structure

Failed checks block merging.

## Import Scripts

- `scripts/import_all_phases.py` — Bulk import GitHub issues from phase CSV files
- `scripts/bootstrap-labels.sh` — Create GitHub labels for phase/section/type organization
- `scripts/phase-{1-5}-issues.csv` — Pre-generated issue definitions for each phase

Edit `REPO` variable in `import_all_phases.py` before running.

## Key Architectural Decisions

1. **Canonical RDF Store** — Single normalized triple store independent of source formatting
2. **Recursive Import Resolution** — Full `owl:imports` chain with cycle detection
3. **IRI ↔ URL Encoding** — URL-safe encoding for IRI-based deep links
4. **Bidirectional Sync** — Graph selection updates text view; text selection updates graph
5. **Read-Only Deployment** — Production system is for exploration only, not editing

## Documentation Structure

- `README.md` — Project overview with architecture diagrams
- `notes/planning/overview.md` — Master roadmap and phase index
- `notes/planning/phase-{01-05}.md` — Complete task specifications per phase
- `CONTRIBUTING.md` — Contribution guidelines and workflow
- `CODE_OF_CONDUCT.md` — Community standards
- `SECURITY.md` — Security policies
- `RELEASING.md` — Release process
- `docs/github-project-guide.md` — GitHub Project setup instructions

## Common Patterns (Once Implementation Begins)

### Query API Pattern
All UI layers consume ontology data through the canonical query API (Phase 1):
```elixir
OntologyModel.list_classes()
OntologyModel.get_class(iri)
OntologyModel.get_inbound_relations(iri)
OntologyModel.get_outbound_relations(iri)
```

### LiveView Routing Pattern
Deep-linkable ontology entity routes:
```elixir
/docs                          # Landing page
/docs/classes/:encoded_iri     # Class detail view
/docs/properties/:encoded_iri  # Property detail view
/docs/individuals/:encoded_iri # Individual detail view
```

### Graph Synchronization Pattern
Phoenix hooks handle bidirectional communication:
- User clicks graph node → hook sends event to LiveView → updates text panel
- User clicks text link → LiveView updates assigns → hook updates graph highlight

## Getting Help

- GitHub Discussions for architecture questions
- GitHub Issues for bugs or feature proposals
- Label ontology tickets with `ontology`
- Label UI tickets with `liveview` or `graph`

## Project Status

This project is in the planning phase. All five phases are fully specified with numbered tasks and test scaffolds. Implementation has not yet begun.
