#!/usr/bin/env bash
# Bootstrap GitHub labels for the Ontology Documentation Platform
# Requires: GitHub CLI (gh) and authenticated session.
# Usage: ./bootstrap-labels.sh <owner/repo>

set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: $0 <owner/repo>"
  exit 1
fi

create_label() {
  local name="$1"
  local color="$2"
  local description="${3:-}"

  echo "Creating label: $name"

  gh label create "$name" \
    --color "$color" \
    ${description:+--description "$description"} \
    --repo "$REPO" 2>/dev/null || echo "Label '$name' already exists, skipping."
}

# =========================================================
# PHASE LABELS
# =========================================================

create_label "phase:1-ontology-core" "0b7285" "Phase 1 – Ontology ingestion & canonical model"
create_label "phase:2-textual-ui" "1864ab" "Phase 2 – LiveView textual documentation UI"
create_label "phase:3-graph-visualization" "364fc7" "Phase 3 – Interactive graph visualization"
create_label "phase:4-ux-accessibility" "5f3dc4" "Phase 4 – UX, property docs & accessibility"
create_label "phase:5-export-deployment" "862e9c" "Phase 5 – Export, CI/CD & deployment"

# =========================================================
# TYPE LABELS
# =========================================================

create_label "type:feature" "2b8a3e" "New feature or enhancement"
create_label "type:bug" "e03131" "Bug or defect"
create_label "type:refactor" "f08c00" "Refactoring or internal improvement"
create_label "type:documentation" "1c7ed6" "Documentation"
create_label "type:testing" "099268" "Testing & validation"
create_label "type:accessibility" "6741d9" "Accessibility & WCAG"

# =========================================================
# ONTOLOGY LABELS
# =========================================================

create_label "ontology:parsing" "0ca678" "RDF/OWL/Turtle parsing"
create_label "ontology:graph" "0b7285" "Graph projection & visualization"
create_label "ontology:export" "f59f00" "Ontology export"
create_label "ontology:canonical-query" "087f5b" "Canonical ontology query API"

# =========================================================
# PHASE 1 — SECTIONS
# =========================================================

create_label "section:1.1-imports" "495057" "Ontology loading & owl:imports"
create_label "section:1.2-triples" "495057" "RDF triple normalization"
create_label "section:1.3-entities" "495057" "OWL entity extraction"
create_label "section:1.4-relations" "495057" "Class hierarchy & relations"
create_label "section:1.5-api" "495057" "Canonical query API"
create_label "section:1.99-integration" "495057" "Phase 1 integration testing"

# =========================================================
# PHASE 2 — SECTIONS
# =========================================================

create_label "section:2.1-routing" "495057" "LiveView routing & mounting"
create_label "section:2.2-accordion" "495057" "Sidebar accordion explorer"
create_label "section:2.3-search" "495057" "Search & filtering"
create_label "section:2.4-detail" "495057" "Class documentation detail view"
create_label "section:2.5-entities" "495057" "Property & individual views"
create_label "section:2.99-integration" "495057" "Phase 2 integration testing"

# =========================================================
# PHASE 3 — SECTIONS
# =========================================================

create_label "section:3.1-graph-projection" "495057" "Graph data projection"
create_label "section:3.2-rendering" "495057" "Graph rendering & layout"
create_label "section:3.3-sync" "495057" "Graph ↔ UI synchronization"
create_label "section:3.4-filtering" "495057" "Graph filtering & focus"
create_label "section:3.99-integration" "495057" "Phase 3 integration testing"

# =========================================================
# PHASE 4 — SECTIONS
# =========================================================

create_label "section:4.1-properties" "495057" "Object & data property docs"
create_label "section:4.2-datatypes" "495057" "Datatype & constraints"
create_label "section:4.3-individuals" "495057" "Individual documentation"
create_label "section:4.4-ux" "495057" "UX & navigation"
create_label "section:4.5-accessibility" "495057" "Accessibility & WCAG"
create_label "section:4.99-integration" "495057" "Phase 4 integration testing"

# =========================================================
# PHASE 5 — SECTIONS
# =========================================================

create_label "section:5.1-export" "495057" "Ontology export"
create_label "section:5.2-versioning" "495057" "Versioning & releases"
create_label "section:5.3-ci" "495057" "CI & validation"
create_label "section:5.4-deployment" "495057" "Production deployment"
create_label "section:5.5-maintenance" "495057" "Long-term maintenance"
create_label "section:5.99-integration" "495057" "Phase 5 integration testing"

echo ""
echo "✅ ✅ ✅ ALL LABELS SUCCESSFULLY BOOTSTRAPPED FOR $REPO"
