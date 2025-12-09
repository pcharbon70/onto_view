
# GitHub Project Setup — Ontology Documentation Platform

This document describes how to configure the GitHub Project, issues, labels, and milestones
for the Ontology Documentation Platform, based on the phased planning documents.

---

## 1. Create a GitHub Project (Beta)

1. Go to your GitHub organization or repository.
2. Click **Projects** → **New Project**.
3. Name it: **Ontology Documentation Platform**.
4. Choose **Board** layout.

We’ll configure:

- Columns (workflow states)
- Views (roadmaps/dashboards)
- Labels (phase/section/type)
- Milestones (per phase)

---

## 2. Columns (Workflow States)

Create the following columns:

- **Backlog**
- **Ready for Development**
- **In Progress**
- **In Review**
- **Testing**
- **Done**

These reflect workflow state, not phase.

---

## 3. Milestones (Per Phase)

Create milestones in the repo:

- **Phase 1 – Ontology Ingestion & Canonical Model**
- **Phase 2 – LiveView Textual Documentation UI**
- **Phase 3 – Interactive Graph Visualization**
- **Phase 4 – UX, Property Docs & Accessibility**
- **Phase 5 – Export, CI/CD & Deployment**

You can map these directly to `phase-1.md` … `phase-5.md`.

---

## 4. Labels

Run the provided script `scripts/bootstrap-labels.sh` (see below) to create labels automatically.

Label categories:

### Phase Labels

- `phase:1-ontology-core`
- `phase:2-textual-ui`
- `phase:3-graph-visualization`
- `phase:4-ux-accessibility`
- `phase:5-export-deployment`

### Section Labels (examples)

- `section:1.1-imports`
- `section:1.2-triples`
- `section:2.1-routing`
- `section:2.2-accordion`
- `section:2.3-search`
- `section:3.1-graph-projection`
- `section:4.5-accessibility`
- `section:5.1-export`
- etc.

You can add more section labels over time if needed.

### Type Labels

- `type:feature`
- `type:bug`
- `type:refactor`
- `type:documentation`
- `type:testing`
- `type:accessibility`

### Ontology-Specific Labels

- `ontology:parsing`
- `ontology:graph`
- `ontology:export`
- `ontology:canonical-query`

---

## 5. Issues = Tasks

Each **Task** in your planning (`Phase.Section.Task`) should be a GitHub Issue.

**Example**

- Title: `Task 2.3.1 — Full-text search over classes and labels`
- Labels:
  - `phase:2-textual-ui`
  - `section:2.3-search`
  - `type:feature`

Inside the issue body, model **subtasks** as Markdown checkboxes:

```md
### Subtasks
- [ ] 2.3.1.1 Index class names
- [ ] 2.3.1.2 Index labels
- [ ] 2.3.1.3 Index comments and definitions
```

---

## 6. Project Views

Create multiple **Views** in your Project:

### View: Phase Roadmap

- Group: **Milestone**
- Filter example: `is:open`
- Shows phase progress at a glance.

### View: Section Tracker

- Group: **Labels**
- Filter: `label:phase:2-textual-ui`

### View: Testing Dashboard

- Filter: `label:type:testing OR label:section:1.99 OR label:section:2.99 OR label:section:3.99 OR label:section:4.99 OR label:section:5.99`

### View: Accessibility Board

- Filter: `label:type:accessibility OR label:section:4.5`

### View: Developer Work Queue

- Group by **Assignee**
- Filter: `is:open`

---

## 7. Branch Naming Convention

Use the following pattern for branches:

- `feature/phase-2.3.1-search`
- `feature/phase-3.2.1-graph-hook`
- `fix/phase-4.5-accessibility-focus`
- `chore/phase-5.3-ci-pipeline`

This provides a direct mapping from Git branch → planning document → issue.

---

## 8. CI Enforcement

Hook your CI to:

- Require status checks to pass before merging
- Optionally, require:
  - At least one review
  - Linear history (squash & merge)

---

With these conventions, your GitHub Project will stay aligned with the detailed
`phase-*.md` planning documents and provide excellent visibility over the ontology platform work.

