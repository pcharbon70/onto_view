# 📄 phase-2.md

## Phoenix LiveView Textual Documentation UI

------------------------------------------------------------------------

## 🎯 Phase 2 Objective

Phase 2 delivers the **core user-facing ontology documentation
interface** using Phoenix LiveView. Its purpose is to expose the
canonical ontology model to users through a responsive, real-time,
text-based UI that supports browsing, searching, filtering, and
relationship navigation across all OWL entities.

------------------------------------------------------------------------

## 🧩 Section 2.1 --- LiveView Application Shell & Routing

This section defines the **structural foundation** of the LiveView
application, including route layout, mounting strategy, and deep-linking
rules for ontology entities.

------------------------------------------------------------------------

### ✅ Task 2.1.1 --- Phoenix LiveView Mounting Structure

-   [ ] 2.1.1.1 Create `OntologyLive` root LiveView\
-   [ ] 2.1.1.2 Configure LiveView layout templates\
-   [ ] 2.1.1.3 Implement shared assigns for ontology state

------------------------------------------------------------------------

### ✅ Task 2.1.2 --- Documentation Routing Model

-   [ ] 2.1.2.1 Implement `/docs` ontology landing route\
-   [ ] 2.1.2.2 Implement `/docs/classes/:id`\
-   [ ] 2.1.2.3 Implement `/docs/properties/:id`\
-   [ ] 2.1.2.4 Implement `/docs/individuals/:id`

------------------------------------------------------------------------

### ✅ Task 2.1.3 --- IRI ↔ URL Encoding Layer

-   [ ] 2.1.3.1 Encode IRIs into URL-safe IDs\
-   [ ] 2.1.3.2 Decode URLs into canonical IRIs\
-   [ ] 2.1.3.3 Validate malformed identifiers

------------------------------------------------------------------------

### ✅ Task 2.1.99 --- Unit Tests: Routing & Mounting

-   [ ] 2.1.99.1 Root documentation route mounts correctly\
-   [ ] 2.1.99.2 Class deep-links resolve correctly\
-   [ ] 2.1.99.3 Property deep-links resolve correctly\
-   [ ] 2.1.99.4 Invalid routes return structured errors

------------------------------------------------------------------------

## 🧩 Section 2.2 --- Sidebar Accordion Class Explorer

This section implements the **primary human navigation system** for
ontology browsing using a hierarchical accordion UI.

------------------------------------------------------------------------

### ✅ Task 2.2.1 --- Hierarchical Class Tree Builder

-   [ ] 2.2.1.1 Load subclass graph into tree structure\
-   [ ] 2.2.1.2 Preserve multiple inheritance branches\
-   [ ] 2.2.1.3 Detect and mark root classes

------------------------------------------------------------------------

### ✅ Task 2.2.2 --- Accordion Rendering Engine

-   [ ] 2.2.2.1 Expand/collapse UI behavior\
-   [ ] 2.2.2.2 Recursive nested accordion rendering\
-   [ ] 2.2.2.3 Lazy expansion for large branches

------------------------------------------------------------------------

### ✅ Task 2.2.3 --- Alphabetical Fallback View

-   [ ] 2.2.3.1 Alphabetical class index generation\
-   [ ] 2.2.3.2 Toggle between hierarchy and alphabetical views

------------------------------------------------------------------------

### ✅ Task 2.2.99 --- Unit Tests: Accordion Explorer

-   [ ] 2.2.99.1 Class hierarchy renders correctly\
-   [ ] 2.2.99.2 Nested accordion expansion works\
-   [ ] 2.2.99.3 Alphabetical fallback loads correctly

------------------------------------------------------------------------

## 🧩 Section 2.3 --- Live Search & Filtering Engine

This section introduces **real-time semantic filtering** for large
ontologies to enable instant discovery of classes, properties, and
individuals.

------------------------------------------------------------------------

### ✅ Task 2.3.1 --- Full-Text Search Index

-   [ ] 2.3.1.1 Index class names\
-   [ ] 2.3.1.2 Index labels\
-   [ ] 2.3.1.3 Index comments and definitions

------------------------------------------------------------------------

### ✅ Task 2.3.2 --- Live Search Input Handling

-   [ ] 2.3.2.1 Debounce user keystrokes\
-   [ ] 2.3.2.2 Server-side search evaluation\
-   [ ] 2.3.2.3 Live result updates via assigns

------------------------------------------------------------------------

### ✅ Task 2.3.3 --- Ontology-Origin Filters

-   [ ] 2.3.3.1 Filter by ontology source\
-   [ ] 2.3.3.2 Multi-ontology intersection filtering

------------------------------------------------------------------------

### ✅ Task 2.3.99 --- Unit Tests: Search & Filtering

-   [ ] 2.3.99.1 Partial string matches work\
-   [ ] 2.3.99.2 Label-based searching works\
-   [ ] 2.3.99.3 Ontology-origin filtering works

------------------------------------------------------------------------

## 🧩 Section 2.4 --- Class Documentation Detail View

This section renders the **full OWL documentation representation for a
selected class**, including hierarchy placement, annotations, and
semantic relationships.

------------------------------------------------------------------------

### ✅ Task 2.4.1 --- Core Class Identity Rendering

-   [ ] 2.4.1.1 Render class label\
-   [ ] 2.4.1.2 Render canonical IRI\
-   [ ] 2.4.1.3 Render ontology prefix\
-   [ ] 2.4.1.4 Render class type indicators

------------------------------------------------------------------------

### ✅ Task 2.4.2 --- Annotation & Description Panel

-   [ ] 2.4.2.1 Render `rdfs:comment`\
-   [ ] 2.4.2.2 Render `skos:definition`\
-   [ ] 2.4.2.3 Render multilingual annotations

------------------------------------------------------------------------

### ✅ Task 2.4.3 --- Class Hierarchy View

-   [ ] 2.4.3.1 Render direct superclasses\
-   [ ] 2.4.3.2 Render direct subclasses\
-   [ ] 2.4.3.3 Enable hyperlink traversal

------------------------------------------------------------------------

### ✅ Task 2.4.4 --- Property Relationship Panels

-   [ ] 2.4.4.1 Render outbound object properties\
-   [ ] 2.4.4.2 Render inbound object properties\
-   [ ] 2.4.4.3 Render attached data properties

------------------------------------------------------------------------

### ✅ Task 2.4.5 --- Individual Instance Panel

-   [ ] 2.4.5.1 Render named individuals\
-   [ ] 2.4.5.2 Link individuals to class detail view

------------------------------------------------------------------------

### ✅ Task 2.4.99 --- Unit Tests: Class Detail View

-   [ ] 2.4.99.1 All core metadata renders correctly\
-   [ ] 2.4.99.2 Hierarchy links resolve correctly\
-   [ ] 2.4.99.3 Inbound/outbound properties resolve correctly\
-   [ ] 2.4.99.4 Individuals render correctly

------------------------------------------------------------------------

## 🧩 Section 2.5 --- Property & Individual Textual Views

This section introduces **standalone textual documentation views** for
object properties, data properties, and named individuals.

------------------------------------------------------------------------

### ✅ Task 2.5.1 --- Property Documentation View

-   [ ] 2.5.1.1 Render property identity panel\
-   [ ] 2.5.1.2 Render domain and range\
-   [ ] 2.5.1.3 Render property characteristics

------------------------------------------------------------------------

### ✅ Task 2.5.2 --- Individual Documentation View

-   [ ] 2.5.2.1 Render individual identity\
-   [ ] 2.5.2.2 Render class membership\
-   [ ] 2.5.2.3 Render attached data values

------------------------------------------------------------------------

### ✅ Task 2.5.99 --- Unit Tests: Property & Individual Views

-   [ ] 2.5.99.1 Property domain/range renders correctly\
-   [ ] 2.5.99.2 Individual class membership renders correctly

------------------------------------------------------------------------

## 🔗 Section 2.99 --- Phase 2 Integration Testing

This section validates the **full end-to-end user navigation flow** of
the textual ontology documentation system.

------------------------------------------------------------------------

### ✅ Task 2.99.1 --- Hierarchical Navigation Validation

-   [ ] 2.99.1.1 Navigate from root class to leaf class\
-   [ ] 2.99.1.2 Navigate from subclass to superclass

------------------------------------------------------------------------

### ✅ Task 2.99.2 --- Hyperlink Traversal Validation

-   [ ] 2.99.2.1 Traverse outbound property links\
-   [ ] 2.99.2.2 Traverse inbound property links

------------------------------------------------------------------------

### ✅ Task 2.99.3 --- Search & Deep-Link Validation

-   [ ] 2.99.3.1 Locate entities via search\
-   [ ] 2.99.3.2 Open documentation via direct URL

