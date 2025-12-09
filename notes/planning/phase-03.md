# 📄 phase-3.md

## Interactive Graph Visualization Engine

------------------------------------------------------------------------

## 🎯 Phase 3 Objective

Phase 3 delivers the **visual ontology exploration system**. Its purpose
is to project the canonical ontology graph into an interactive visual
representation, synchronized with LiveView state, enabling users to
visually explore subclass hierarchies and semantic relationships in real
time.

------------------------------------------------------------------------

## 🧩 Section 3.1 --- Graph Data Projection Engine

This section transforms the canonical ontology model into **graph-ready
node and edge projections** suitable for real-time visualization.

------------------------------------------------------------------------

### ✅ Task 3.1.1 --- Class Node Projection

-   [ ] 3.1.1.1 Project each class as a graph node\
-   [ ] 3.1.1.2 Assign stable node identifiers\
-   [ ] 3.1.1.3 Attach label and ontology-origin metadata

------------------------------------------------------------------------

### ✅ Task 3.1.2 --- Subclass Edge Projection

-   [ ] 3.1.2.1 Project `rdfs:subClassOf` as directed edges\
-   [ ] 3.1.2.2 Prevent edge duplication\
-   [ ] 3.1.2.3 Preserve inheritance depth metadata

------------------------------------------------------------------------

### ✅ Task 3.1.3 --- Object Property Edge Projection

-   [ ] 3.1.3.1 Project domain → range edges\
-   [ ] 3.1.3.2 Label edges with property names\
-   [ ] 3.1.3.3 Support multi-domain and multi-range properties

------------------------------------------------------------------------

### ✅ Task 3.1.99 --- Unit Tests: Graph Projection

-   [ ] 3.1.99.1 All classes become nodes\
-   [ ] 3.1.99.2 All subclass relationships become edges\
-   [ ] 3.1.99.3 Property edges resolve correctly

------------------------------------------------------------------------

## 🧩 Section 3.2 --- Graph Rendering & Layout Engine

This section renders the **interactive force-directed ontology graph**
within the browser using LiveView + JS hooks.

------------------------------------------------------------------------

### ✅ Task 3.2.1 --- Graph Rendering Hook

-   [ ] 3.2.1.1 Initialize graph via JS hook\
-   [ ] 3.2.1.2 Mount SVG or Canvas renderer\
-   [ ] 3.2.1.3 Support resizing and redraw

------------------------------------------------------------------------

### ✅ Task 3.2.2 --- Physics & Layout Configuration

-   [ ] 3.2.2.1 Configure force-directed layout\
-   [ ] 3.2.2.2 Prevent label overlap\
-   [ ] 3.2.2.3 Apply ontology-origin color encoding

------------------------------------------------------------------------

### ✅ Task 3.2.3 --- Viewport Controls

-   [ ] 3.2.3.1 Pan behavior\
-   [ ] 3.2.3.2 Zoom behavior\
-   [ ] 3.2.3.3 Reset view positioning

------------------------------------------------------------------------

### ✅ Task 3.2.99 --- Unit Tests: Graph Rendering

-   [ ] 3.2.99.1 Graph mounts correctly\
-   [ ] 3.2.99.2 Zoom and pan work correctly\
-   [ ] 3.2.99.3 Layout stabilizes correctly

------------------------------------------------------------------------

## 🧩 Section 3.3 --- Live Synchronization with Documentation UI

This section ensures full **bidirectional synchronization** between
graph state and textual documentation views.

------------------------------------------------------------------------

### ✅ Task 3.3.1 --- Sidebar → Graph Synchronization

-   [ ] 3.3.1.1 Selecting a class highlights its node\
-   [ ] 3.3.1.2 Auto-zoom to selected node

------------------------------------------------------------------------

### ✅ Task 3.3.2 --- Graph → Documentation Synchronization

-   [ ] 3.3.2.1 Clicking a node opens class detail view\
-   [ ] 3.3.2.2 Trigger LiveView navigation event

------------------------------------------------------------------------

### ✅ Task 3.3.99 --- Unit Tests: Sync Behavior

-   [ ] 3.3.99.1 Sidebar selection updates graph\
-   [ ] 3.3.99.2 Graph selection updates documentation

------------------------------------------------------------------------

## 🧩 Section 3.4 --- Graph Filtering & Focus Engine

This section introduces **semantic graph filtering** to control visual
complexity.

------------------------------------------------------------------------

### ✅ Task 3.4.1 --- Search-Based Graph Filtering

-   [ ] 3.4.1.1 Filter nodes by text query\
-   [ ] 3.4.1.2 Dim non-matching nodes\
-   [ ] 3.4.1.3 Preserve layout stability during filter

------------------------------------------------------------------------

### ✅ Task 3.4.2 --- Ontology-Origin View Layers

-   [ ] 3.4.2.1 Toggle visibility per ontology\
-   [ ] 3.4.2.2 Color-code by ontology

------------------------------------------------------------------------

### ✅ Task 3.4.3 --- Neighborhood Focus Mode

-   [ ] 3.4.3.1 Show only K-hop neighbors\
-   [ ] 3.4.3.2 Fade distant graph regions

------------------------------------------------------------------------

### ✅ Task 3.4.99 --- Unit Tests: Graph Filtering

-   [ ] 3.4.99.1 Search filtering works\
-   [ ] 3.4.99.2 Ontology layer filtering works\
-   [ ] 3.4.99.3 Focus mode limits visible graph

------------------------------------------------------------------------

## 🔗 Section 3.99 --- Phase 3 Integration Testing

This section validates the **complete real-time visual ontology
exploration workflow**.

------------------------------------------------------------------------

### ✅ Task 3.99.1 --- Visual Navigation Validation

-   [ ] 3.99.1.1 Navigate from graph to class view\
-   [ ] 3.99.1.2 Navigate from class view to graph

------------------------------------------------------------------------

### ✅ Task 3.99.2 --- Filtering & Layout Stability Validation

-   [ ] 3.99.2.1 Apply filtering without layout collapse\
-   [ ] 3.99.2.2 Reset filters without graph loss

