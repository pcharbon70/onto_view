# Contributing Guide

## Ontology Documentation Platform

Thank you for your interest in contributing! This project is a **Phoenix
LiveView--based ontology documentation system** for OWL/RDF ontologies
expressed in Turtle. Contributions are welcome across parsing, UI,
visualization, accessibility, CI/CD, and documentation.

This guide explains **how to contribute safely, consistently, and in
alignment with the project's phased architecture**.

------------------------------------------------------------------------

## 🧭 Project Structure & Phases

Development follows five strict phases (see `overview.md` and
`phase-1.md` → `phase-5.md`):

1.  **Phase 1** --- Ontology ingestion, RDF normalization, OWL entity
    extraction\
2.  **Phase 2** --- LiveView textual documentation UI\
3.  **Phase 3** --- Interactive graph visualization\
4.  **Phase 4** --- UX, accessibility, property & individual docs\
5.  **Phase 5** --- Export, CI/CD, and production deployment

> ✅ Contributions must align with the correct phase. Please avoid
> introducing Phase 3--5 features while Phase 1 blockers are unresolved.

------------------------------------------------------------------------

## 🧑‍💻 Development Environment

### Required Tooling

-   **Elixir** (latest stable)
-   **Phoenix** (with LiveView)
-   **Node.js** (for graph JS hooks)
-   **Pandoc** (for documentation exports, optional)
-   **Graph visualization library** (D3/Cytoscape)

### Setup

``` bash
git clone <repo-url>
cd ontology-docs
mix deps.get
mix setup
mix phx.server
```

Open:

    http://localhost:4000/docs

------------------------------------------------------------------------

## 🌿 Branching Strategy

-   `main` → stable production branch
-   `develop` → active integration branch
-   `feature/<phase>-<name>` → all feature work
    -   Example: `feature/phase-2-live-search`

✅ Always branch from `develop`\
✅ Never commit directly to `main`

------------------------------------------------------------------------

## ✅ Contribution Types

You can contribute in the following areas:

-   **Ontology ingestion & parsing**
-   **OWL/RDF validation**
-   **Phoenix LiveView UI**
-   **Graph visualization**
-   **Accessibility (ARIA, keyboard nav)**
-   **CI/CD & deployment**
-   **Documentation & diagrams**
-   **Test suite expansion**

------------------------------------------------------------------------

## 🧪 Testing Requirements

All contributions **must include tests**.

### Required Test Layers

-   ✅ **Unit tests** (per task, per phase)
-   ✅ **Integration tests** (end of each phase)
-   ✅ **Ontology validation tests**
-   ✅ **LiveView UI tests**
-   ✅ **Graph behavior tests** (if applicable)

Run all tests with:

``` bash
mix test
```

CI **will reject PRs** if any test fails.

------------------------------------------------------------------------

## 🧬 Ontology Contribution Rules

If you contribute ontologies or modify Turtle files:

-   ✅ Must validate with a TTL parser
-   ✅ Must resolve all `owl:imports`
-   ✅ Must include:
    -   `rdfs:label`
    -   `rdfs:comment`
    -   Proper domain/range for properties
-   ✅ Must not break Phase 1 ingestion tests

------------------------------------------------------------------------

## 🎨 UI & Accessibility Standards

All UI contributions must:

-   ✅ Preserve keyboard navigation
-   ✅ Use ARIA roles for interactive components
-   ✅ Maintain contrast ratios (WCAG 2.1 AA)
-   ✅ Avoid color-only semantic indicators
-   ✅ Remain usable without the graph enabled

------------------------------------------------------------------------

## 🔍 Code Style Guidelines

### Elixir & Phoenix

-   Follow `mix format`
-   Prefer **pure functions**
-   Use **pattern matching over conditionals**
-   No business logic in LiveView templates

### JavaScript (Graph)

-   No direct DOM mutation outside hooks
-   Graph must fully rehydrate on LiveView patch
-   No global state

------------------------------------------------------------------------

## 📋 Pull Request Checklist

Before opening a PR, ensure:

-   [ ] Feature belongs to the correct phase
-   [ ] Unit tests added
-   [ ] Integration tests updated (if needed)
-   [ ] No breaking ontology changes
-   [ ] `mix test` passes
-   [ ] `mix format` applied
-   [ ] UI remains accessible without mouse
-   [ ] README/overview updated if architecture changed

------------------------------------------------------------------------

## 🧪 CI & Validation Rules

The CI pipeline enforces:

-   RDF/TTL syntax validation
-   Import closure validation
-   OWL class/property sanity checks
-   Full unit + integration test execution
-   Build artifact verification

Failed checks **block merging**.

------------------------------------------------------------------------

## 🚦 Review Process

1.  Open PR against `develop`
2.  Automated CI runs
3.  At least **one core maintainer review**
4.  Requested changes must be resolved
5.  Squash-merge into `develop`
6.  Periodic release merges into `main`

------------------------------------------------------------------------

## 🆘 Getting Help

-   Open a GitHub Discussion for architecture questions
-   Open an Issue for bugs or feature proposals
-   Label ontology-related tickets with `ontology`
-   Label UI tickets with `liveview` or `graph`

------------------------------------------------------------------------

## 🏁 License & Contribution Terms

By contributing, you agree that:

-   Your contributions may be redistributed under the project license
-   You affirm that you have the right to submit the code or ontology
    changes

------------------------------------------------------------------------

🙏 Thank you for contributing to the **Ontology Documentation
Platform**! Your work directly improves the scientific and developer
experience for ontology exploration.

