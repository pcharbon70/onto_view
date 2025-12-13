# 📄 phase-00.md

## Multi-Ontology Hub Architecture & Version Management

------------------------------------------------------------------------

## 🎯 Phase 0 Objective

Phase 0 establishes the **multi-ontology hub infrastructure** that enables OntoView to host, manage, and switch between multiple independent ontology sets, each with versioned releases. Its purpose is to transform the system from a single-ontology documentation tool into a hub capable of managing multiple domains (e.g., Elixir, Ecto, Phoenix, Medical ontologies) with version control and intelligent caching.

This foundational layer sits between the application infrastructure and Phase 1's ontology core, providing:
- **OntologyHub GenServer** for managing multiple sets with LRU/LFU caching
- **Set+version routing** pattern: `/sets/:set_id/:version/docs`
- **Configuration system** for declaring available ontology sets
- **Session-based set selection** for improved UX
- **Integration hooks** for Phase 2+ (LiveView, Graph, Export)

Phase 0 enables use cases like:
- Hosting Elixir v1.17 and v1.18 simultaneously for version comparison
- Switching between Elixir, Ecto, and Phoenix ontologies
- Medical researchers viewing FHIR R4 while also accessing SNOMED CT
- Developers comparing ontology evolution across releases

------------------------------------------------------------------------

## 🧩 Section 0.1 — Core Hub Infrastructure

This section creates the foundational data structures and GenServer skeleton for the OntologyHub. It defines type-safe structs for loaded ontology sets, configuration metadata, and GenServer state. The configuration loading system parses runtime.exs to discover available sets without loading them into memory (lazy loading strategy).

Key Design: Separate lightweight `SetConfiguration` (metadata) from heavyweight `OntologySet` (fully loaded with triples) to enable efficient caching and lazy loading.

------------------------------------------------------------------------

### ✅ Task 0.1.1 — Data Structure Definitions ✅ COMPLETED (2025-12-13)

- [x] 0.1.1.1 Define `OntologySet` struct with comprehensive @type specs\
- [x] 0.1.1.2 Define `SetConfiguration` struct for config metadata\
- [x] 0.1.1.3 Define `State` struct for GenServer internal state\
- [x] 0.1.1.4 Create `OntologyHub` module skeleton with type definitions

**Implementation:**
- Module: `lib/onto_view/ontology_hub/ontology_set.ex`
- Module: `lib/onto_view/ontology_hub/set_configuration.ex`
- Module: `lib/onto_view/ontology_hub/state.ex` (private)
- Module: `lib/onto_view/ontology_hub.ex`

**Pattern Reference:** Follow `ImportResolver` nested struct pattern from Phase 1

------------------------------------------------------------------------

### ✅ Task 0.1.2 — Configuration Loading System ✅ COMPLETED (2025-12-13)

- [x] 0.1.2.1 Implement `load_set_configurations/0` to read from Application config\
- [x] 0.1.2.2 Implement `parse_set_configuration/1` to parse each set\
- [x] 0.1.2.3 Implement `parse_version_config/1` to parse version metadata\
- [x] 0.1.2.4 Add configuration validation with error handling

**Implementation:**
- Private functions in `lib/onto_view/ontology_hub.ex`
- Config source: `Application.get_env(:onto_view, :ontology_sets, [])`
- **Note**: Implemented as part of Task 0.1.1 (see summary for details)

------------------------------------------------------------------------

### ✅ Task 0.1.3 — GenServer Lifecycle Management ✅ COMPLETED (2025-12-13)

- [x] 0.1.3.1 Implement `init/1` callback with config loading\
- [x] 0.1.3.2 Implement auto-load scheduling (1 second delay)\
- [x] 0.1.3.3 Implement `handle_info(:auto_load, state)` callback\
- [x] 0.1.3.4 Add graceful shutdown with `terminate/2`

**Implementation:**
- GenServer callbacks in `lib/onto_view/ontology_hub.ex`
- Auto-load only default versions of sets with `auto_load: true`
- **Enhancement**: Added `State.record_load/1` in auto-load handler
- **Tests**: Added comprehensive auto-load tests (0.1.99.3)

------------------------------------------------------------------------

### ✅ Task 0.1.99 — Unit Tests: Core Infrastructure

- [ ] 0.1.99.1 GenServer starts successfully with various configs\
- [ ] 0.1.99.2 Configuration loads and parses correctly\
- [ ] 0.1.99.3 Auto-load executes after scheduled delay\
- [ ] 0.1.99.4 Invalid configuration handled gracefully

**Tests:** `test/onto_view/ontology_hub_test.exs`
**Coverage Target:** 90%+ for GenServer lifecycle

------------------------------------------------------------------------

## 🧩 Section 0.2 — Set Loading & Query API

This section implements the loading pipeline that chains Phase 1 modules (ImportResolver → TripleStore) to transform Turtle files into queryable OntologySet structs. The query API provides synchronous, cached access with lazy loading—only requested sets are loaded on first access.

Key Design: Loading is expensive (file I/O, parsing, indexing), so it's deferred until `get_set/3` is called. Cache provides O(log n) lookup for subsequent accesses.

------------------------------------------------------------------------

### ✅ Task 0.2.1 — Set Loading Pipeline ✅ COMPLETED (2025-12-13)

- [x] 0.2.1.1 Implement `load_set_from_config/3` orchestrating the pipeline\
- [x] 0.2.1.2 Implement `load_ontology_files/1` calling ImportResolver\
- [x] 0.2.1.3 Implement `build_triple_store/1` calling TripleStore\
- [x] 0.2.1.4 Implement `compute_stats/2` for metadata

**Implementation:**
- Private pipeline functions in `lib/onto_view/ontology_hub.ex`
- Integration: `ImportResolver.load_with_imports/2`, `TripleStore.from_loaded_ontologies/1`
- Error handling: Wrap Phase 1 errors with context
- **Note**: Implemented as part of Task 0.1.1 (see summary for details)

------------------------------------------------------------------------

### ✅ Task 0.2.2 — Public Query API

- [ ] 0.2.2.1 Implement `get_set/3` with lazy loading and cache hit/miss\
- [ ] 0.2.2.2 Implement `get_default_set/2` for convenience access\
- [ ] 0.2.2.3 Implement `list_sets/0` returning summary metadata\
- [ ] 0.2.2.4 Implement `list_versions/1` for a specific set

**Implementation:**
- Public functions in `lib/onto_view/ontology_hub.ex`
- `handle_call` callbacks for synchronous query API
- Comprehensive @doc with examples, @spec for all functions

------------------------------------------------------------------------

### ✅ Task 0.2.3 — Cache Management Operations

- [ ] 0.2.3.1 Implement `reload_set/3` for hot-reloading (dev use case)\
- [ ] 0.2.3.2 Implement `unload_set/2` to free memory\
- [ ] 0.2.3.3 Implement `get_stats/0` for cache observability\
- [ ] 0.2.3.4 Implement `configure_cache/2` for runtime tuning

**Implementation:**
- Public functions in `lib/onto_view/ontology_hub.ex`
- Stats include: loaded_count, cache_hit_rate, eviction_count

------------------------------------------------------------------------

### ✅ Task 0.2.4 — IRI Resolution & Redirection

- [ ] 0.2.4.1 Implement `resolve_iri/1` to search all loaded sets for an IRI\
- [ ] 0.2.4.2 Return set_id, version, and entity_type for found IRIs\
- [ ] 0.2.4.3 Handle version selection for IRIs present in multiple sets\
- [ ] 0.2.4.4 Build IRI → (set_id, version) index for O(1) lookups\
- [ ] 0.2.4.5 Support cache invalidation when sets are loaded/unloaded

**Implementation:**
- Function: `OntologyHub.resolve_iri/1` in `lib/onto_view/ontology_hub.ex`
- Use TripleStore subject indexes to search by IRI
- Return format: `%{set_id: string, version: string, entity_type: :class | :property | :individual, iri: string}`
- Cache IRI mappings in State struct for performance

**Use Case:** Enables Linked Data dereferenceable IRIs where external
ontology IRIs can redirect to OntoView documentation pages following
W3C best practices for Semantic Web publishing.

------------------------------------------------------------------------

### ✅ Task 0.2.5 — Content Negotiation Endpoint

- [ ] 0.2.5.1 Implement `/resolve` route accepting IRI query parameter\
- [ ] 0.2.5.2 Support content negotiation via Accept headers\
- [ ] 0.2.5.3 Return 303 See Other redirects for successful resolutions\
- [ ] 0.2.5.4 Handle text/html → documentation view redirect\
- [ ] 0.2.5.5 Handle text/turtle → TTL export redirect\
- [ ] 0.2.5.6 Handle application/json → JSON metadata response

**Implementation:**
- Route: `GET /resolve?iri=<url-encoded-iri>` in `lib/onto_view_web/router.ex`
- Controller: `lib/onto_view_web/controllers/resolve_controller.ex`
- Call `OntologyHub.resolve_iri/1` for IRI lookup
- Redirect to appropriate view based on Accept header and entity type

**Example Flow:**
```
GET /resolve?iri=http://example.org/MyClass
Accept: text/html
→ 303 See Other
Location: /sets/elixir/v1.17/docs/classes/<encoded-iri>
```

------------------------------------------------------------------------

### ✅ Task 0.2.99 — Unit Tests: Loading & Querying

- [ ] 0.2.99.1 Load valid set successfully via get_set/3\
- [ ] 0.2.99.2 Handle load failures gracefully (invalid TTL, missing file)\
- [ ] 0.2.99.3 list_sets/0 returns accurate metadata\
- [ ] 0.2.99.4 list_versions/1 shows loaded status correctly\
- [ ] 0.2.99.5 reload_set/3 updates cached data\
- [ ] 0.2.99.6 resolve_iri/1 finds IRIs in loaded sets\
- [ ] 0.2.99.7 resolve_iri/1 returns nil for unknown IRIs\
- [ ] 0.2.99.8 resolve_iri/1 selects latest version for multi-version IRIs\
- [ ] 0.2.99.9 /resolve endpoint returns 303 redirects with correct headers\
- [ ] 0.2.99.10 Content negotiation routes to correct target (HTML/TTL/JSON)

**Tests:**
- `test/onto_view/ontology_hub_test.exs`
- `test/onto_view_web/controllers/resolve_controller_test.exs`

**Coverage Target:** 90%+ for loading, query, and resolution functions

------------------------------------------------------------------------

## 🧩 Section 0.3 — Cache Management & Eviction

This section implements LRU (Least Recently Used) and LFU (Least Frequently Used) cache eviction strategies with comprehensive metrics. The cache enforces a configurable size limit (default: 5 sets) to prevent memory exhaustion while maintaining high hit rates for active sets.

Key Design: Eviction is synchronous during load but rare in production. Metrics enable observability for production tuning.

------------------------------------------------------------------------

### ✅ Task 0.3.1 — LRU Eviction Strategy

- [ ] 0.3.1.1 Implement `evict_lru/1` finding oldest last_accessed set\
- [ ] 0.3.1.2 Track `last_accessed` timestamp on every cache hit\
- [ ] 0.3.1.3 Update `access_log` for temporal tracking\
- [ ] 0.3.1.4 Enforce cache limit in `add_to_cache/3` before insertion

**Implementation:**
- Private functions in `lib/onto_view/ontology_hub.ex`
- Use `DateTime.utc_now/0` for timestamps, `Enum.min_by/2` for finding LRU

------------------------------------------------------------------------

### ✅ Task 0.3.2 — LFU Eviction Strategy

- [ ] 0.3.2.1 Implement `evict_lfu/1` finding lowest access_count set\
- [ ] 0.3.2.2 Track `access_count` incrementing on every cache hit\
- [ ] 0.3.2.3 Initialize access_count to 1 on first load

**Implementation:**
- Private functions in `lib/onto_view/ontology_hub.ex`
- Use `Enum.min_by/2` on access_count

------------------------------------------------------------------------

### ✅ Task 0.3.3 — Cache Metrics Tracking

- [ ] 0.3.3.1 Increment cache_hit_count on cache hit\
- [ ] 0.3.3.2 Increment load_count on successful load\
- [ ] 0.3.3.3 Increment eviction_count on eviction\
- [ ] 0.3.3.4 Compute cache_hit_rate in get_stats/0

**Implementation:**
- Metrics fields in State struct
- Computation: `hit_rate = hits / (hits + misses)`

------------------------------------------------------------------------

### ✅ Task 0.3.99 — Unit Tests: Cache Management

- [ ] 0.3.99.1 LRU eviction works correctly (time-based)\
- [ ] 0.3.99.2 LFU eviction works correctly (frequency-based)\
- [ ] 0.3.99.3 Cache metrics are accurate\
- [ ] 0.3.99.4 Cache limit is enforced (never exceeds max)\
- [ ] 0.3.99.5 Concurrent access is safe (100+ parallel requests)

**Tests:** `test/onto_view/ontology_hub_test.exs`
**Coverage Target:** 90%+ for cache management
**Note:** Test 0.3.99.5 uses `async: false` due to GenServer

------------------------------------------------------------------------

## 🧩 Section 0.4 — Routing & UI Integration

This section bridges the OntologyHub to the Phoenix web layer, establishing the `/sets/:set_id/:version/*` routing pattern and providing UI scaffolding for set selection. The SetResolver plug extracts set context and loads the ontology into `conn.assigns` for downstream consumption by LiveViews.

Key Design: SetResolver plug centralizes set loading logic, making it available to all routes via assigns. This eliminates repetitive mount logic in every LiveView.

------------------------------------------------------------------------

### ✅ Task 0.4.1 — Phoenix Application Bootstrap

**Note:** This project currently has no Phoenix dependencies. Must bootstrap Phoenix first.

- [ ] 0.4.1.1 Add Phoenix dependencies to mix.exs\
- [ ] 0.4.1.2 Generate Phoenix application structure (endpoint, router, views)\
- [ ] 0.4.1.3 Configure Phoenix in config/config.exs and config/dev.exs\
- [ ] 0.4.1.4 Add OntologyHub to application supervision tree\
- [ ] 0.4.1.5 Create basic Phoenix layout templates

**Implementation:**
- Update: `mix.exs` (add phoenix, phoenix_html, phoenix_live_view)
- Create: `lib/onto_view_web/endpoint.ex`, `lib/onto_view_web/router.ex`
- Create: `lib/onto_view_web.ex` (Phoenix context)
- Update: `lib/onto_view/application.ex` (add Phoenix.Endpoint, OntologyHub to children)
- Create: `lib/onto_view_web/components/layouts.ex`, `lib/onto_view_web/components/layouts/root.html.heex`

------------------------------------------------------------------------

### ✅ Task 0.4.2 — SetResolver Plug

- [ ] 0.4.2.1 Create SetResolver plug extracting set_id and version from path params\
- [ ] 0.4.2.2 Call OntologyHub.get_set/2 to load ontology set\
- [ ] 0.4.2.3 Assign loaded set to conn.assigns (ontology_set, triple_store, set_id, version)\
- [ ] 0.4.2.4 Handle missing sets with graceful redirect to /sets

**Implementation:**
- Module: `lib/onto_view_web/plugs/set_resolver.ex`
- Pattern: Return `conn` unchanged if no set_id in path (e.g., landing page)
- Error handling: Redirect to `/sets` with flash error message

------------------------------------------------------------------------

### ✅ Task 0.4.3 — Route Structure Definition

- [ ] 0.4.3.1 Define landing page and set browser routes\
- [ ] 0.4.3.2 Define set+version scoped documentation routes (placeholder LiveViews)\
- [ ] 0.4.3.3 Define IRI resolution endpoint for content negotiation\
- [ ] 0.4.3.4 Add SetResolver plug to browser pipeline

**Implementation:**
- Update: `lib/onto_view_web/router.ex`
- Routes:
  - `GET /` → Landing page
  - `GET /sets` → Set browser (list all)
  - `GET /sets/:set_id` → Version selector (list versions)
  - `GET /resolve` → IRI resolution endpoint (Task 0.2.5)
  - `live /sets/:set_id/:version/docs` → Docs landing (placeholder for Phase 2)
- Pipeline: Add `plug OntoViewWeb.Plugs.SetResolver` to `:browser`

------------------------------------------------------------------------

### ✅ Task 0.4.4 — Set Selection UI Controllers

- [ ] 0.4.4.1 Create PageController with landing page action\
- [ ] 0.4.4.2 Create SetController with index action (list sets)\
- [ ] 0.4.4.3 Create SetController with show action (list versions for a set)\
- [ ] 0.4.4.4 Create placeholder DocsLive.Index LiveView

**Implementation:**
- Module: `lib/onto_view_web/controllers/page_controller.ex`
- Module: `lib/onto_view_web/controllers/set_controller.ex`
- Module: `lib/onto_view_web/live/docs_live/index.ex` (placeholder)
- Templates: `lib/onto_view_web/controllers/page_html/home.html.heex`, `set_html/index.html.heex`, `set_html/show.html.heex`

------------------------------------------------------------------------

### ✅ Task 0.4.5 — Session-Based Set Memory

- [ ] 0.4.5.1 Remember last-viewed set_id in session\
- [ ] 0.4.5.2 Redirect to last-viewed set on landing page (if available)

**Implementation:**
- Update: `lib/onto_view_web/controllers/page_controller.ex`
- Pattern: `put_session(conn, :last_set_id, set_id)` when viewing a set
- Landing page: Check session, redirect to last_set if present

------------------------------------------------------------------------

### ✅ Task 0.4.99 — Unit Tests: Routing Integration

- [ ] 0.4.99.1 Routes resolve correctly for valid set+version\
- [ ] 0.4.99.2 SetResolver plug loads correct ontology into assigns\
- [ ] 0.4.99.3 Invalid set redirects to /sets with error flash\
- [ ] 0.4.99.4 Session remembers last-viewed set\
- [ ] 0.4.99.5 /resolve endpoint redirects known IRIs correctly\
- [ ] 0.4.99.6 /resolve endpoint returns 404 for unknown IRIs\
- [ ] 0.4.99.7 Content negotiation headers route to correct endpoints

**Tests:**
- `test/onto_view_web/plugs/set_resolver_test.exs`
- `test/onto_view_web/controllers/set_controller_test.exs`
- `test/onto_view_web/controllers/page_controller_test.exs`
- `test/onto_view_web/controllers/resolve_controller_test.exs`
- `test/onto_view_web/live/docs_live_test.exs`

------------------------------------------------------------------------

## 🔗 Section 0.99 — Phase 0 Integration Testing

This section validates that the entire multi-ontology hub works end-to-end: configuration loads, sets load correctly, caching works under load, and routing integrates seamlessly with the web layer.

------------------------------------------------------------------------

### ✅ Task 0.99.1 — Multi-Set Loading Validation

- [ ] 0.99.1.1 Load 3+ different sets concurrently (elixir, ecto, phoenix)\
- [ ] 0.99.1.2 Verify each set has independent triple stores\
- [ ] 0.99.1.3 Verify set isolation (changes in one don't affect others)

**Tests:** `test/integration/multi_set_test.exs`

------------------------------------------------------------------------

### ✅ Task 0.99.2 — Cache Behavior Under Load

- [ ] 0.99.2.1 Simulate 100+ concurrent requests to same set (cache hit rate > 90%)\
- [ ] 0.99.2.2 Trigger cache eviction by loading max_sets + 1\
- [ ] 0.99.2.3 Verify evicted set can be reloaded lazily

**Tests:** `test/integration/cache_performance_test.exs`

------------------------------------------------------------------------

### ✅ Task 0.99.3 — End-to-End Web Navigation

- [ ] 0.99.3.1 Navigate from landing → set browser → version selector → docs\
- [ ] 0.99.3.2 Verify SetResolver loads correct set at each step\
- [ ] 0.99.3.3 Verify session memory works across page reloads

**Tests:** `test/integration/web_navigation_test.exs`

------------------------------------------------------------------------

### ✅ Task 0.99.4 — Error Handling & Recovery

- [ ] 0.99.4.1 Invalid set_id returns 404 redirect\
- [ ] 0.99.4.2 Invalid version returns 404 redirect\
- [ ] 0.99.4.3 Corrupted TTL file doesn't crash GenServer\
- [ ] 0.99.4.4 GenServer remains operational after load failures

**Tests:** `test/integration/error_handling_test.exs`

------------------------------------------------------------------------

### ✅ Task 0.99.5 — IRI Resolution & Linked Data Workflow

- [ ] 0.99.5.1 Resolve IRI to documentation view via /resolve endpoint\
- [ ] 0.99.5.2 Validate content negotiation redirects to correct format\
- [ ] 0.99.5.3 Resolve IRIs across multiple loaded sets\
- [ ] 0.99.5.4 Handle IRIs present in multiple versions (selects latest stable)

**Tests:** `test/integration/iri_resolution_test.exs`

**Coverage:** End-to-end validation of Linked Data dereferenceable IRIs
following W3C best practices (HTTP 303 redirects, content negotiation).

------------------------------------------------------------------------
