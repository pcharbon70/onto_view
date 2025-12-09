# Ontology Documentation Platform

This project is a **Phoenix LiveView--based ontology documentation
system** for OWL/RDF ontologies expressed in Turtle.\
It ingests one or more interrelated ontologies, builds a canonical
semantic model, and exposes them through both:

-   A **textual, accordion-based documentation UI**, and\
-   An **interactive graph visualization**, synchronized in real time.

The system is designed for **domain scientists and software developers**
who need to explore complex ontologies such as the Elixir core
ontologies.

------------------------------------------------------------------------

## Combined Architecture Overview

The diagram below shows the **end-to-end architecture**, from ontology
ingestion to production deployment, including all five phases and their
main responsibilities.

``` mermaid
flowchart LR
    %% Inputs
    A[OWL/Turtle Ontology Files<br/>elixir-core, elixir-otp, elixir-structure, elixir-evolution, elixir-shapes]

    %% Phase 1: Core Ontology Engine
    subgraph P1[Phase 1 - Ontology Ingestion & Canonical Model]
        P1a[RDF/Turtle Parser]
        P1b[Import Resolver<br/>(owl:imports)]
        P1c[Canonical RDF Store]
        P1d[OWL Entity Extractor<br/>(Classes, Properties, Individuals)]
        P1e[Class Hierarchy & Relations]
        P1f[Canonical Ontology Query API]
        P1a --> P1b --> P1c --> P1d --> P1e --> P1f
    end

    %% Phase 2: Textual UI
    subgraph P2[Phase 2 - LiveView Textual Documentation UI]
        P2a[LiveView Shell & Routing]
        P2b[Accordion Class Explorer]
        P2c[Search & Filtering Engine]
        P2d[Class/Property/Individual Detail Views]
    end

    %% Phase 3: Graph Visualization
    subgraph P3[Phase 3 - Interactive Graph Visualization]
        P3a[Graph Projection Engine<br/>(Nodes & Edges)]
        P3b[JS Graph Renderer<br/>(Force-directed)]
        P3c[Graph–Text Sync<br/>(Click ⇄ Select)]
        P3d[Graph Filters & Focus Modes]
    end

    %% Phase 4: UX & Accessibility
    subgraph P4[Phase 4 - UX, Property Docs & Accessibility]
        P4a[Enhanced Property & Individual Docs]
        P4b[Navigation & Breadcrumbs]
        P4c[Keyboard Navigation]
        P4d[ARIA & Screen Reader Support]
        P4e[WCAG 2.1 AA Compliance]
    end

    %% Phase 5: Export & Deployment
    subgraph P5[Phase 5 - Export, CI/CD & Deployment]
        P5a[TTL & JSON Export APIs]
        P5b[Versioning & Release Metadata]
        P5c[CI Pipeline<br/>(Tests + Ontology Validation)]
        P5d[Phoenix Prod Release<br/>Read-only UI]
        P5e[Monitoring & Logging]
    end

    %% User
    U[Domain Scientist / Developer]

    %% Flows
    A --> P1a
    P1f --> P2a
    P1f --> P3a
    P1f --> P5a
    P2a --> P4b
    P2b --> P4b
    P2d --> P4a
    P2a --> U
    P3b --> U
    P4e --> U
    P5d --> U
```

------------------------------------------------------------------------

## Runtime Data Flow (Mermaid)

This diagram focuses on the **live runtime behavior** of the system once
deployed, showing how data flows during typical user interactions.

``` mermaid
sequenceDiagram
    participant User as User Browser
    participant LV as Phoenix LiveView
    participant API as Canonical Ontology API
    participant Graph as Graph JS Engine
    participant Store as Canonical RDF Store
    participant Export as Export Endpoints

    User->>LV: Open /docs
    LV->>API: list_classes()
    API->>Store: Query all classes
    Store-->>API: Class list
    API-->>LV: Class list
    LV-->>User: Render accordion UI

    User->>LV: Click class
    LV->>API: get_class(iri)
    API->>Store: Query class details
    Store-->>API: Class metadata
    API-->>LV: Class detail model
    LV-->>User: Render class detail view

    User->>Graph: Select node
    Graph->>LV: Node selected event
    LV->>API: get_class(iri)
    API->>Store: Query class details
    Store-->>API: Class metadata
    API-->>LV: Class detail model
    LV-->>User: Sync detail view

    User->>LV: Download ontology
    LV->>Export: GET /export/ttl
    Export->>Store: Read canonical graph
    Store-->>Export: Full ontology graph
    Export-->>User: TTL or JSON file
```

------------------------------------------------------------------------

## Key Features

-   **Ontology-Aware Parsing & Canonical Model**
    -   Recursive `owl:imports` resolution
    -   RDF triple normalization and indexing
    -   OWL class, property, and individual extraction
    -   Class hierarchy and property relation modeling
-   **Rich Developer-Focused Documentation UI**
    -   Accordion-based hierarchical class explorer
    -   Live search and ontology-origin filtering
    -   Deep links for classes, properties, and individuals
-   **Interactive Graph Exploration**
    -   Force-directed graph view of classes and relationships
    -   Click-through from graph to detail pages
    -   Semantic filters and neighborhood focus
-   **Accessibility & UX**
    -   WCAG 2.1 AA--oriented design
    -   Full keyboard navigation
    -   ARIA roles and screen reader support
-   **Export & Production**
    -   TTL and JSON exports for reuse
    -   CI pipeline for ontology and UI validation
    -   Hardened Phoenix production deployment (read-only)

------------------------------------------------------------------------

## Planning Documents

Detailed implementation phases are specified in the following markdown
files:

-   `phase-1.md` --- Ontology Ingestion, Parsing & Canonical Model\
-   `phase-2.md` --- Phoenix LiveView Textual Documentation UI\
-   `phase-3.md` --- Interactive Graph Visualization Engine\
-   `phase-4.md` --- Property Documentation, UX Enhancements &
    Accessibility\
-   `phase-5.md` --- Ontology Export, CI/CD & Production Deployment

An index of all phases and diagrams is available in:

-   `overview.md` --- Master Overview & Roadmap

------------------------------------------------------------------------

## Getting Started (High-Level)

1.  **Set up the Elixir/Phoenix project**
    -   Create a new Phoenix application with LiveView enabled
    -   Configure dependencies for RDF/OWL handling
2.  **Implement Phase 1**
    -   Build the ingestion pipeline and canonical ontology query API
    -   Add unit tests for ontology parsing and relations
3.  **Layer on Phase 2 & Phase 3**
    -   Implement LiveView-based textual navigation
    -   Add the JS-based graph visualization and synchronization
4.  **Refine with Phase 4 & Phase 5**
    -   Improve UX, accessibility, and property documentation depth
    -   Configure CI, export endpoints, and production deployment

From there, you can iteratively refine the ontologies and the UI to best
serve your domain scientists and developers.

------------------------------------------------------------------------

*This README is part of the Ontology Documentation Platform planning and
implementation suite.*

