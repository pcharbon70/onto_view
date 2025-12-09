# Ontology Documentation Platform

This project is a **Phoenix LiveView--based ontology documentation
system** for OWL/RDF ontologies expressed in Turtle.\
It ingests one or more interrelated ontologies, builds a canonical
semantic model, and exposes them through both:

- A **textual, accordion-based documentation UI**, and\
- An **interactive graph visualization**, synchronized in real time.

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
    A["OWL/Turtle Ontology Files
(elixir-core, elixir-otp, elixir-structure, elixir-evolution, elixir-shapes)"]

    subgraph P1["Phase 1 - Ontology Ingestion & Canonical Model"]
        P1a["RDF/Turtle Parser"]
        P1b["Import Resolver (owl:imports)"]
        P1c["Canonical RDF Store"]
        P1d["OWL Entity Extractor"]
        P1e["Class Hierarchy & Relations"]
        P1f["Canonical Ontology Query API"]
        P1a --> P1b --> P1c --> P1d --> P1e --> P1f
    end

    subgraph P2["Phase 2 - LiveView Textual Documentation UI"]
        P2a["LiveView Shell & Routing"]
        P2b["Accordion Class Explorer"]
        P2c["Search & Filtering Engine"]
        P2d["Class, Property & Individual Views"]
    end

    subgraph P3["Phase 3 - Interactive Graph Visualization"]
        P3a["Graph Projection Engine"]
        P3b["JS Graph Renderer"]
        P3c["Graph-Text Synchronization"]
        P3d["Graph Filters & Focus Modes"]
    end

    subgraph P4["Phase 4 - UX, Property Docs & Accessibility"]
        P4a["Enhanced Property & Individual Docs"]
        P4b["Navigation & Breadcrumbs"]
        P4c["Keyboard Navigation"]
        P4d["ARIA & Screen Reader Support"]
        P4e["WCAG 2.1 AA Compliance"]
    end

    subgraph P5["Phase 5 - Export, CI/CD & Deployment"]
        P5a["TTL & JSON Export APIs"]
        P5b["Versioning & Release Metadata"]
        P5c["CI Pipeline"]
        P5d["Phoenix Production Release (Read-only)"]
        P5e["Monitoring & Logging"]
    end

    U["Domain Scientist / Developer"]

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

## Runtime Data Flow

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

## Planning Documents

- `phase-1.md`
- `phase-2.md`
- `phase-3.md`
- `phase-4.md`
- `phase-5.md`
- `overview.md`
