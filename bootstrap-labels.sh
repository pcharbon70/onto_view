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
  local description="$3"

  echo "Creating label: $name"
  gh label create "$name" \
    --color "$color" \
    --description "$description" \
    --repo "$REPO" 2>/dev/null || echo "Label $name already exists, skipping."
}

# Phase labels
create_label "phase:1-ontology-core" "0b7285" "Phase 1 – Ontology ingestion, RDF normalization, canonical model"
create_label "phase:2-textual-ui" "1864ab" "Phase 2 – Phoenix LiveView textual documentation UI"
create_label "phase:3-graph-visualization""364fc7" "Phase 3 – Interactive graph visualization"
create_label "phase:4-ux-accessibility" "5f3dc4" "Phase 4 – UX, property documentation & accessibility"
create_label "phase:5-export-deployment" "862e9c" "Phase 5 – Export, CI/CD & deployment"

# Type labels
create_label "type:feature" "2b8a3e" "New feature or enhancement"
create_label "type:bug" "e03131" "Bug or defect"
create_label "type:refactor" "f08c00" "Refactoring or internal improvement"
create_label "type:documentation" "1c7ed6" "Docs and content changes"
create_label "type:testing" "099268" "Tests and test infrastructure"
create_label "type:accessibility" "6741d9" "Accessibility (a11y) and WCAG-related work"

# Ontology-specific labels
create_label "ontology:parsing" "0ca678" "RDF/OWL/Turtle parsing and ingestion"
create_label "ontology:graph" "0b7285" "Graph projection and visualization"
create_label "ontology:export" "f59f00" "Ontology export (TTL/JSON)"
create_label "ontology:canonical-query" "087f5b" "Canonical ontology query API"

# Example section labels (add more as needed)
create_label "section:1.1-imports" "495057" "Phase 1 – Ontology loading & import resolution"
create_label "section:1.2-triples" "495057" "Phase 1 – RDF triple normalization"
create_label "section:2.1-routing" "495057" "Phase 2 – LiveView routing & mounting"
create_label "section:2.2-accordion" "495057" "Phase 2 – Accordion explorer"
create_label "section:2.3-search" "495057" "Phase 2 – Live search & filtering"
create_label "section:3.1-graph-projection""495057" "Phase 3 – Graph projection engine"
create_label "section:4.5-accessibility" "495057" "Phase 4 – Accessibility & WCAG compliance"
create_label "section:5.1-export" "495057" "Phase 5 – Export & distribution"

echo "Done. Labels bootstrapped for $REPO."
