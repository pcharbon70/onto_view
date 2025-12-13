# Phase 0: Multi-Ontology Hub Architecture with Versioning

**Document Version:** 1.0
**Date:** 2025-12-13
**Status:** Research / Design Specification
**Author:** Architecture Design

---

## Executive Summary

This document specifies **Phase 0**, a foundational layer that transforms OntoView from a single-ontology documentation system into a **multi-ontology hub** capable of hosting and switching between multiple ontology sets, each with versioned releases.

**Key Features:**
- Multiple independent ontology sets (e.g., "elixir", "ecto", "phoenix")
- Version management per set (e.g., v1.17, v3.11, v1.7)
- LRU-cached in-memory storage for performance
- User session-based selection and navigation
- Backward-compatible route structure

**Example Routes:**
- `/sets/elixir/v1.17/docs` - Elixir Core v1.17 documentation
- `/sets/ecto/v3.11/docs/classes/Repo` - Ecto v3.11 Repo class
- `/sets/phoenix/v1.7/docs` - Phoenix v1.7 documentation

**Architecture Position:**
```
Phase 0 (Hub Layer) → Phase 1 (Ontology Core) → Phase 2 (UI) → Phase 3 (Graph)
```

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Architecture Overview](#2-architecture-overview)
3. [Core Data Structures](#3-core-data-structures)
4. [OntologyHub GenServer](#4-ontologyhub-genserver)
5. [Configuration System](#5-configuration-system)
6. [Routing & URL Structure](#6-routing--url-structure)
7. [Version Management](#7-version-management)
8. [Cache Management](#8-cache-management)
9. [Lifecycle & Loading](#9-lifecycle--loading)
10. [Testing Strategy](#10-testing-strategy)
11. [Migration Path](#11-migration-path)
12. [Task Breakdown](#12-task-breakdown)
13. [Integration with Existing Phases](#13-integration-with-existing-phases)
14. [Future Enhancements](#14-future-enhancements)

---

## 1. Problem Statement

### Current Architecture Limitations

**Single Ontology Set:**
```elixir
# Current: One global ontology for entire application
defmodule OntoView.Ontology do
  defstruct loaded_ontologies: nil,  # ONE LoadedOntologies
            triple_store: nil         # ONE TripleStore
end
```

**Issues:**
1. Cannot host multiple unrelated ontology systems (e.g., Elixir + Medical ontologies)
2. No version management (cannot show Elixir 1.17 vs 1.18 differences)
3. Users cannot switch between ontology sets
4. No isolation between different ontology domains

### Requirements

**Must Support:**
1. Multiple independent ontology sets (e.g., "elixir", "ecto", "phoenix", "fhir")
2. Multiple versions per set (e.g., elixir v1.17, v1.18, v1.19)
3. Human-readable set identifiers (not UUIDs)
4. Semantic versioning in URLs
5. Efficient memory management (LRU cache)
6. Session-based set/version selection
7. Backward compatibility with Phase 1-5 implementations

**Example Use Cases:**
- Developer exploring Elixir 1.17 ontology while comparing to 1.18
- Switching from Elixir documentation to Ecto documentation
- Medical researcher viewing FHIR R4 ontology, then switching to SNOMED CT
- Same user viewing different versions side-by-side (future: comparison view)

---

## 2. Architecture Overview

### 2.1. System Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 2-5: UI, Graph, Export                                │
│ - LiveView pages consume OntologyHub API                    │
│ - Routes include /sets/:set_id/:version/...                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 0: OntologyHub (NEW)                                  │
│ - GenServer managing multiple ontology sets                 │
│ - Version registry and resolution                           │
│ - LRU cache with configurable limits                        │
│ - Lifecycle management (auto-load, lazy-load, eviction)     │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Ontology Core (UNCHANGED)                          │
│ - ImportResolver.load_with_imports/2                        │
│ - TripleStore.from_loaded_ontologies/1                      │
│ - Entity extraction (Section 1.3+)                          │
└─────────────────────────────────────────────────────────────┘
```

### 2.2. Key Concepts

**Ontology Set:**
- A collection of related ontologies imported as one unit
- Example: "elixir" set includes Module, Function, Clause ontologies via hub.ttl
- Identified by human-readable slug (e.g., "elixir", "ecto", "phoenix")

**Version:**
- A specific release of an ontology set
- Follows semantic versioning (e.g., "v1.17.3", "v3.11.0")
- Each version is independently loaded and cached
- Versions are immutable once loaded

**Set + Version Compound Key:**
- Primary key: `{set_id, version}`
- Example: `{"elixir", "v1.17"}` uniquely identifies Elixir Core v1.17

**Hub:**
- Central registry and cache manager
- Tracks available sets and versions
- Manages memory limits via LRU eviction
- Provides query API for UI layers

---

## 3. Core Data Structures

### 3.1. OntologySet

**Definition:**
```elixir
defmodule OntoView.OntologyHub.OntologySet do
  @moduledoc """
  Represents a loaded ontology set with all its metadata, triples,
  and extracted entities.

  Each set is uniquely identified by {set_id, version}.
  """

  @type set_id :: String.t()  # Human-readable: "elixir", "ecto", "phoenix"
  @type version :: String.t()  # Semantic version: "v1.17.3", "v3.11.0"

  @type t :: %__MODULE__{
    # Identity
    id: set_id(),
    version: version(),
    name: String.t(),              # Display name: "Elixir Core Ontologies"
    description: String.t(),        # Full description

    # Source
    root_path: Path.t(),            # Path to root .ttl file
    base_dir: Path.t(),             # Base directory for imports

    # Loaded Data (from Phase 1)
    loaded_ontologies: LoadedOntologies.t(),
    triple_store: TripleStore.t(),

    # Statistics (computed on load)
    stats: %{
      ontology_count: non_neg_integer(),
      triple_count: non_neg_integer(),
      class_count: non_neg_integer(),      # Future: Section 1.3
      property_count: non_neg_integer(),   # Future: Section 1.3
      individual_count: non_neg_integer()  # Future: Section 1.3
    },

    # Metadata
    tags: [String.t()],             # ["programming", "elixir"]
    authors: [String.t()],          # ["Elixir Team"]
    license: String.t() | nil,      # "Apache-2.0"
    homepage: String.t() | nil,     # "https://elixir-lang.org"

    # Cache Management
    loaded_at: DateTime.t(),
    last_accessed: DateTime.t(),
    access_count: non_neg_integer(),

    # Version Metadata
    release_date: Date.t() | nil,
    changelog_url: String.t() | nil,
    is_latest: boolean(),
    is_stable: boolean(),
    is_deprecated: boolean()
  }

  defstruct [
    :id, :version, :name, :description,
    :root_path, :base_dir,
    :loaded_ontologies, :triple_store,
    :stats, :tags, :authors, :license, :homepage,
    :loaded_at, :last_accessed,
    access_count: 0,
    :release_date, :changelog_url,
    is_latest: false,
    is_stable: true,
    is_deprecated: false
  ]
end
```

### 3.2. SetConfiguration

**Definition:**
```elixir
defmodule OntoView.OntologyHub.SetConfiguration do
  @moduledoc """
  Configuration for an available ontology set, read from config files.

  Defines metadata about a set and its versions without loading the
  actual ontology data (which is expensive).
  """

  @type t :: %__MODULE__{
    id: String.t(),               # "elixir"
    name: String.t(),             # "Elixir Core Ontologies"
    description: String.t(),

    versions: [version_config()],
    default_version: String.t(),  # "v1.17" or "latest"

    tags: [String.t()],
    auto_load: boolean(),         # Load on startup?

    authors: [String.t()],
    license: String.t() | nil,
    homepage: String.t() | nil
  }

  @type version_config :: %{
    version: String.t(),          # "v1.17.3"
    root_path: Path.t(),          # "ontologies/elixir/v1.17/hub.ttl"
    base_dir: Path.t() | nil,     # Optional base directory override
    release_date: Date.t() | nil,
    changelog_url: String.t() | nil,
    is_latest: boolean(),
    is_stable: boolean(),
    is_deprecated: boolean(),
    notes: String.t() | nil       # "Beta release", "LTS version", etc.
  }

  defstruct [
    :id, :name, :description,
    :versions, :default_version,
    :tags, :auto_load,
    :authors, :license, :homepage
  ]
end
```

### 3.3. HubState (GenServer State)

**Definition:**
```elixir
defmodule OntoView.OntologyHub.State do
  @moduledoc false

  @type set_version_key :: {set_id :: String.t(), version :: String.t()}

  @type t :: %__MODULE__{
    # Loaded sets (in-memory cache)
    loaded_sets: %{set_version_key() => OntologySet.t()},

    # Available sets (from config)
    available_sets: %{set_id :: String.t() => SetConfiguration.t()},

    # Cache policy
    max_loaded_sets: pos_integer(),      # Default: 5
    eviction_strategy: :lru | :lfu,      # Default: :lru

    # Metrics
    access_log: [{set_version_key(), DateTime.t()}],  # For LRU
    load_count: non_neg_integer(),
    eviction_count: non_neg_integer(),
    cache_hit_count: non_neg_integer(),
    cache_miss_count: non_neg_integer()
  }

  defstruct [
    loaded_sets: %{},
    available_sets: %{},
    max_loaded_sets: 5,
    eviction_strategy: :lru,
    access_log: [],
    load_count: 0,
    eviction_count: 0,
    cache_hit_count: 0,
    cache_miss_count: 0
  ]
end
```

---

## 4. OntologyHub GenServer

### 4.1. Module Structure

**File:** `lib/onto_view/ontology_hub.ex`

```elixir
defmodule OntoView.OntologyHub do
  @moduledoc """
  Central hub for managing multiple ontology sets with versioning.

  The OntologyHub is a GenServer that:
  - Maintains a registry of available ontology sets and versions
  - Manages an LRU cache of loaded ontology sets
  - Provides a query API for retrieving ontology data
  - Handles lifecycle events (auto-load, lazy-load, eviction)

  ## Architecture

  The hub sits above the Phase 1 ontology core and below the Phase 2+
  UI layers, providing a multiplexing layer for multiple ontology sets.

  ## Usage

      # Get a specific set+version
      {:ok, elixir_v117} = OntologyHub.get_set("elixir", "v1.17")

      # List available sets
      sets = OntologyHub.list_sets()

      # List versions for a set
      versions = OntologyHub.list_versions("elixir")

      # Reload a set (e.g., after ontology file update)
      {:ok, reloaded} = OntologyHub.reload_set("elixir", "v1.17")

  ## Configuration

  See `config/runtime.exs` for ontology set configuration.

  Part of Phase 0 — Multi-Ontology Hub Architecture
  """

  use GenServer
  require Logger

  alias OntoView.OntologyHub.{OntologySet, SetConfiguration, State}
  alias OntoView.Ontology.{ImportResolver, TripleStore}

  @type set_id :: String.t()
  @type version :: String.t()
  @type set_version_key :: {set_id(), version()}

  # Client API

  @doc """
  Starts the OntologyHub GenServer.

  Automatically loads sets configured with `auto_load: true`.

  ## Options

  - `:name` - GenServer name (default: `__MODULE__`)
  - `:max_loaded_sets` - Maximum sets to keep in cache (default: 5)
  - `:eviction_strategy` - Cache eviction strategy: `:lru` or `:lfu` (default: `:lru`)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Retrieves a specific ontology set by ID and version.

  If the set is not loaded, it will be loaded from disk (lazy loading).
  If the cache is full, the least recently used set will be evicted.

  ## Parameters

  - `set_id` - Set identifier (e.g., "elixir", "ecto")
  - `version` - Version string (e.g., "v1.17", "v3.11")
  - `opts` - Options:
    - `:timeout` - GenServer call timeout (default: 30_000ms for loading)

  ## Returns

  - `{:ok, ontology_set}` - Successfully retrieved (from cache or loaded)
  - `{:error, :not_configured}` - Set+version not in configuration
  - `{:error, :load_failed, reason}` - Failed to load from disk

  ## Examples

      iex> {:ok, elixir} = OntologyHub.get_set("elixir", "v1.17")
      iex> elixir.id
      "elixir"
      iex> elixir.version
      "v1.17"
      iex> elixir.triple_store.count > 0
      true
  """
  @spec get_set(set_id(), version(), keyword()) ::
    {:ok, OntologySet.t()} | {:error, term()}
  def get_set(set_id, version, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    GenServer.call(__MODULE__, {:get_set, set_id, version}, timeout)
  end

  @doc """
  Retrieves a set using the default version for that set.

  Convenience function that looks up the configured default version.

  ## Examples

      # If elixir's default_version is "v1.17"
      iex> {:ok, elixir} = OntologyHub.get_default_set("elixir")
      iex> elixir.version
      "v1.17"
  """
  @spec get_default_set(set_id(), keyword()) ::
    {:ok, OntologySet.t()} | {:error, term()}
  def get_default_set(set_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_default_set, set_id}, Keyword.get(opts, :timeout, 30_000))
  end

  @doc """
  Lists all available ontology sets (without loading them).

  Returns metadata about configured sets, regardless of whether
  they're currently loaded in memory.

  ## Returns

  List of set summaries with structure:
  ```elixir
  %{
    id: "elixir",
    name: "Elixir Core Ontologies",
    description: "...",
    versions: ["v1.17", "v1.18"],
    default_version: "v1.17",
    loaded_versions: ["v1.17"],  # Currently in cache
    tags: ["programming", "elixir"]
  }
  ```

  ## Examples

      iex> sets = OntologyHub.list_sets()
      iex> Enum.find(sets, & &1.id == "elixir")
      %{id: "elixir", name: "Elixir Core Ontologies", ...}
  """
  @spec list_sets() :: [map()]
  def list_sets do
    GenServer.call(__MODULE__, :list_sets)
  end

  @doc """
  Lists all versions available for a specific set.

  ## Returns

  List of version metadata:
  ```elixir
  %{
    version: "v1.17",
    loaded: true,
    is_latest: true,
    is_stable: true,
    release_date: ~D[2023-06-01]
  }
  ```
  """
  @spec list_versions(set_id()) :: {:ok, [map()]} | {:error, :not_found}
  def list_versions(set_id) do
    GenServer.call(__MODULE__, {:list_versions, set_id})
  end

  @doc """
  Reloads a set from disk, replacing the cached version.

  Useful for development or after updating ontology files.

  ## Parameters

  - `set_id` - Set identifier
  - `version` - Version to reload
  - `opts` - Options (same as `get_set/3`)

  ## Returns

  - `{:ok, ontology_set}` - Reloaded successfully
  - `{:error, reason}` - Failed to reload
  """
  @spec reload_set(set_id(), version(), keyword()) ::
    {:ok, OntologySet.t()} | {:error, term()}
  def reload_set(set_id, version, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    GenServer.call(__MODULE__, {:reload_set, set_id, version}, timeout)
  end

  @doc """
  Unloads a set from the cache (frees memory).

  The set can be loaded again later via `get_set/3`.

  ## Examples

      iex> OntologyHub.unload_set("elixir", "v1.17")
      :ok
  """
  @spec unload_set(set_id(), version()) :: :ok
  def unload_set(set_id, version) do
    GenServer.call(__MODULE__, {:unload_set, set_id, version})
  end

  @doc """
  Returns cache statistics and metrics.

  ## Returns

  ```elixir
  %{
    loaded_count: 3,           # Currently loaded sets
    available_count: 10,       # Total available sets
    max_loaded_sets: 5,
    cache_hit_rate: 0.85,
    total_accesses: 100,
    eviction_count: 5
  }
  ```
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Updates cache configuration at runtime.

  ## Parameters

  - `max_loaded_sets` - New cache size limit
  - `eviction_strategy` - `:lru` or `:lfu`

  ## Examples

      iex> OntologyHub.configure_cache(10, :lru)
      :ok
  """
  @spec configure_cache(pos_integer(), :lru | :lfu) :: :ok
  def configure_cache(max_loaded_sets, eviction_strategy)
      when max_loaded_sets > 0 and eviction_strategy in [:lru, :lfu] do
    GenServer.call(__MODULE__, {:configure_cache, max_loaded_sets, eviction_strategy})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Load configuration
    available_sets = load_set_configurations()

    max_loaded_sets = Keyword.get(opts, :max_loaded_sets, 5)
    eviction_strategy = Keyword.get(opts, :eviction_strategy, :lru)

    state = %State{
      available_sets: available_sets,
      max_loaded_sets: max_loaded_sets,
      eviction_strategy: eviction_strategy
    }

    Logger.info("OntologyHub started with #{map_size(available_sets)} configured sets")

    # Auto-load sets in background
    schedule_auto_load()

    {:ok, state}
  end

  @impl true
  def handle_call({:get_set, set_id, version}, _from, state) do
    key = {set_id, version}

    case Map.get(state.loaded_sets, key) do
      nil ->
        # Cache miss - load from disk
        case load_set_from_config(set_id, version, state) do
          {:ok, ontology_set, new_state} ->
            Logger.info("Loaded ontology set: #{set_id} #{version}")
            {:reply, {:ok, ontology_set}, new_state}

          {:error, reason} ->
            Logger.error("Failed to load #{set_id} #{version}: #{inspect(reason)}")
            {:reply, {:error, :load_failed, reason}, state}
        end

      ontology_set ->
        # Cache hit - update access time
        ontology_set = %{ontology_set |
          last_accessed: DateTime.utc_now(),
          access_count: ontology_set.access_count + 1
        }
        state = put_in(state.loaded_sets[key], ontology_set)
        state = %{state |
          cache_hit_count: state.cache_hit_count + 1,
          access_log: [{key, DateTime.utc_now()} | state.access_log]
        }

        {:reply, {:ok, ontology_set}, state}
    end
  end

  @impl true
  def handle_call({:get_default_set, set_id}, from, state) do
    case Map.get(state.available_sets, set_id) do
      nil ->
        {:reply, {:error, :not_configured}, state}

      set_config ->
        version = set_config.default_version
        handle_call({:get_set, set_id, version}, from, state)
    end
  end

  @impl true
  def handle_call(:list_sets, _from, state) do
    sets =
      state.available_sets
      |> Enum.map(fn {set_id, config} ->
        loaded_versions =
          state.loaded_sets
          |> Enum.filter(fn {{sid, _v}, _set} -> sid == set_id end)
          |> Enum.map(fn {{_sid, v}, _set} -> v end)

        %{
          id: config.id,
          name: config.name,
          description: config.description,
          versions: Enum.map(config.versions, & &1.version),
          default_version: config.default_version,
          loaded_versions: loaded_versions,
          tags: config.tags,
          auto_load: config.auto_load
        }
      end)
      |> Enum.sort_by(& &1.id)

    {:reply, sets, state}
  end

  @impl true
  def handle_call({:list_versions, set_id}, _from, state) do
    case Map.get(state.available_sets, set_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      set_config ->
        versions = Enum.map(set_config.versions, fn version_config ->
          loaded = Map.has_key?(state.loaded_sets, {set_id, version_config.version})

          Map.merge(version_config, %{loaded: loaded})
        end)

        {:reply, {:ok, versions}, state}
    end
  end

  @impl true
  def handle_call({:reload_set, set_id, version}, _from, state) do
    key = {set_id, version}

    # Remove from cache if present
    state = %{state | loaded_sets: Map.delete(state.loaded_sets, key)}

    # Load fresh from disk
    case load_set_from_config(set_id, version, state) do
      {:ok, ontology_set, new_state} ->
        Logger.info("Reloaded ontology set: #{set_id} #{version}")
        {:reply, {:ok, ontology_set}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unload_set, set_id, version}, _from, state) do
    key = {set_id, version}
    state = %{state | loaded_sets: Map.delete(state.loaded_sets, key)}

    Logger.info("Unloaded ontology set: #{set_id} #{version}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    total_accesses = state.cache_hit_count + state.cache_miss_count
    cache_hit_rate = if total_accesses > 0 do
      state.cache_hit_count / total_accesses
    else
      0.0
    end

    stats = %{
      loaded_count: map_size(state.loaded_sets),
      available_count: Enum.sum(Enum.map(state.available_sets, fn {_id, config} ->
        length(config.versions)
      end)),
      max_loaded_sets: state.max_loaded_sets,
      cache_hit_rate: Float.round(cache_hit_rate, 2),
      total_accesses: total_accesses,
      eviction_count: state.eviction_count,
      load_count: state.load_count
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:configure_cache, max_loaded_sets, eviction_strategy}, _from, state) do
    state = %{state |
      max_loaded_sets: max_loaded_sets,
      eviction_strategy: eviction_strategy
    }

    # Evict excess sets if new limit is lower
    state = enforce_cache_limit(state)

    Logger.info("Cache configured: max=#{max_loaded_sets}, strategy=#{eviction_strategy}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:auto_load, state) do
    auto_load_sets =
      state.available_sets
      |> Enum.filter(fn {_id, config} -> config.auto_load end)
      |> Enum.flat_map(fn {set_id, config} ->
        # Auto-load only the default version
        [{set_id, config.default_version}]
      end)

    state = Enum.reduce(auto_load_sets, state, fn {set_id, version}, acc_state ->
      case load_set_from_config(set_id, version, acc_state) do
        {:ok, _ontology_set, new_state} ->
          Logger.info("Auto-loaded: #{set_id} #{version}")
          new_state

        {:error, reason} ->
          Logger.warning("Auto-load failed for #{set_id} #{version}: #{inspect(reason)}")
          acc_state
      end
    end)

    {:noreply, state}
  end

  # Private Functions

  defp schedule_auto_load do
    # Load sets 1 second after startup to avoid blocking init
    Process.send_after(self(), :auto_load, 1_000)
  end

  defp load_set_configurations do
    :onto_view
    |> Application.get_env(:ontology_sets, [])
    |> Enum.map(&parse_set_configuration/1)
    |> Map.new(fn config -> {config.id, config} end)
  end

  defp parse_set_configuration(config_map) do
    %SetConfiguration{
      id: config_map.id,
      name: config_map.name,
      description: config_map.description,
      versions: Enum.map(config_map.versions, &parse_version_config/1),
      default_version: config_map.default_version,
      tags: Map.get(config_map, :tags, []),
      auto_load: Map.get(config_map, :auto_load, false),
      authors: Map.get(config_map, :authors, []),
      license: Map.get(config_map, :license),
      homepage: Map.get(config_map, :homepage)
    }
  end

  defp parse_version_config(version_map) do
    %{
      version: version_map.version,
      root_path: version_map.root_path,
      base_dir: Map.get(version_map, :base_dir),
      release_date: Map.get(version_map, :release_date),
      changelog_url: Map.get(version_map, :changelog_url),
      is_latest: Map.get(version_map, :is_latest, false),
      is_stable: Map.get(version_map, :is_stable, true),
      is_deprecated: Map.get(version_map, :is_deprecated, false),
      notes: Map.get(version_map, :notes)
    }
  end

  defp load_set_from_config(set_id, version, state) do
    with {:ok, set_config} <- get_set_config(set_id, state),
         {:ok, version_config} <- get_version_config(set_config, version),
         {:ok, loaded_ontologies} <- load_ontology_files(version_config),
         {:ok, triple_store} <- build_triple_store(loaded_ontologies) do

      ontology_set = %OntologySet{
        id: set_id,
        version: version,
        name: set_config.name,
        description: set_config.description,
        root_path: version_config.root_path,
        base_dir: version_config.base_dir || Path.dirname(version_config.root_path),
        loaded_ontologies: loaded_ontologies,
        triple_store: triple_store,
        stats: compute_stats(loaded_ontologies, triple_store),
        tags: set_config.tags,
        authors: set_config.authors,
        license: set_config.license,
        homepage: set_config.homepage,
        loaded_at: DateTime.utc_now(),
        last_accessed: DateTime.utc_now(),
        access_count: 1,
        release_date: version_config.release_date,
        changelog_url: version_config.changelog_url,
        is_latest: version_config.is_latest,
        is_stable: version_config.is_stable,
        is_deprecated: version_config.is_deprecated
      }

      # Add to cache with eviction if needed
      key = {set_id, version}
      new_state = add_to_cache(key, ontology_set, state)

      {:ok, ontology_set, new_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_set_config(set_id, state) do
    case Map.get(state.available_sets, set_id) do
      nil -> {:error, :not_configured}
      config -> {:ok, config}
    end
  end

  defp get_version_config(set_config, version) do
    case Enum.find(set_config.versions, &(&1.version == version)) do
      nil -> {:error, :version_not_found}
      version_config -> {:ok, version_config}
    end
  end

  defp load_ontology_files(version_config) do
    opts = if version_config.base_dir do
      [base_dir: version_config.base_dir]
    else
      []
    end

    case ImportResolver.load_with_imports(version_config.root_path, opts) do
      {:ok, loaded_ontologies} -> {:ok, loaded_ontologies}
      {:error, reason} -> {:error, {:import_resolver_error, reason}}
    end
  end

  defp build_triple_store(loaded_ontologies) do
    triple_store = TripleStore.from_loaded_ontologies(loaded_ontologies)
    {:ok, triple_store}
  rescue
    e -> {:error, {:triple_store_error, e}}
  end

  defp compute_stats(loaded_ontologies, triple_store) do
    %{
      ontology_count: map_size(loaded_ontologies.ontologies),
      triple_count: triple_store.count,
      class_count: 0,      # TODO: Compute from Section 1.3
      property_count: 0,   # TODO: Compute from Section 1.3
      individual_count: 0  # TODO: Compute from Section 1.3
    }
  end

  defp add_to_cache(key, ontology_set, state) do
    # Check if cache is full
    state = if map_size(state.loaded_sets) >= state.max_loaded_sets do
      evict_one_set(state)
    else
      state
    end

    # Add new set
    state = put_in(state.loaded_sets[key], ontology_set)
    state = %{state |
      load_count: state.load_count + 1,
      cache_miss_count: state.cache_miss_count + 1,
      access_log: [{key, DateTime.utc_now()} | state.access_log]
    }

    state
  end

  defp evict_one_set(state) do
    case state.eviction_strategy do
      :lru -> evict_lru(state)
      :lfu -> evict_lfu(state)
    end
  end

  defp evict_lru(state) do
    # Find least recently accessed set
    {evict_key, _ontology_set} =
      Enum.min_by(state.loaded_sets, fn {_key, set} ->
        DateTime.to_unix(set.last_accessed)
      end)

    Logger.info("Evicting LRU set: #{inspect(evict_key)}")

    %{state |
      loaded_sets: Map.delete(state.loaded_sets, evict_key),
      eviction_count: state.eviction_count + 1
    }
  end

  defp evict_lfu(state) do
    # Find least frequently accessed set
    {evict_key, _ontology_set} =
      Enum.min_by(state.loaded_sets, fn {_key, set} ->
        set.access_count
      end)

    Logger.info("Evicting LFU set: #{inspect(evict_key)}")

    %{state |
      loaded_sets: Map.delete(state.loaded_sets, evict_key),
      eviction_count: state.eviction_count + 1
    }
  end

  defp enforce_cache_limit(state) do
    excess = map_size(state.loaded_sets) - state.max_loaded_sets

    if excess > 0 do
      Enum.reduce(1..excess, state, fn _i, acc_state ->
        evict_one_set(acc_state)
      end)
    else
      state
    end
  end
end
```

---

## 5. Configuration System

### 5.1. Configuration File Structure

**File:** `config/runtime.exs` (or environment-specific configs)

```elixir
import Config

# Multi-Ontology Hub Configuration
config :onto_view, :ontology_sets, [
  # Elixir Core Ontologies
  %{
    id: "elixir",
    name: "Elixir Core Ontologies",
    description: """
    Semantic model of the Elixir programming language including modules,
    functions, clauses, parameters, guards, types, and macros.
    """,
    tags: ["programming", "elixir", "functional"],
    authors: ["Elixir Team", "OntoView Contributors"],
    license: "Apache-2.0",
    homepage: "https://elixir-lang.org",
    auto_load: true,  # Load on startup
    default_version: "v1.17",
    versions: [
      %{
        version: "v1.17",
        root_path: "ontologies/elixir/v1.17/hub.ttl",
        base_dir: "ontologies/elixir/v1.17",
        release_date: ~D[2023-06-12],
        changelog_url: "https://github.com/elixir-lang/elixir/releases/tag/v1.17.0",
        is_latest: false,
        is_stable: true,
        is_deprecated: false,
        notes: "LTS release"
      },
      %{
        version: "v1.18",
        root_path: "ontologies/elixir/v1.18/hub.ttl",
        base_dir: "ontologies/elixir/v1.18",
        release_date: ~D[2024-11-20],
        changelog_url: "https://github.com/elixir-lang/elixir/releases/tag/v1.18.0",
        is_latest: true,
        is_stable: true,
        is_deprecated: false,
        notes: "Current stable release"
      }
    ]
  },

  # Ecto Ontology
  %{
    id: "ecto",
    name: "Ecto Database Library Ontology",
    description: """
    Semantic model of Ecto's database abstraction layer including schemas,
    queries, changesets, and repositories.
    """,
    tags: ["database", "elixir", "ecto"],
    authors: ["Ecto Team"],
    license: "Apache-2.0",
    homepage: "https://hexdocs.pm/ecto",
    auto_load: false,  # Load on demand
    default_version: "v3.11",
    versions: [
      %{
        version: "v3.11",
        root_path: "ontologies/ecto/v3.11/ecto.ttl",
        release_date: ~D[2023-11-15],
        is_latest: true,
        is_stable: true,
        is_deprecated: false
      }
    ]
  },

  # Phoenix Framework Ontology
  %{
    id: "phoenix",
    name: "Phoenix Web Framework Ontology",
    description: """
    Semantic model of the Phoenix web framework including controllers,
    views, LiveView, channels, and routing.
    """,
    tags: ["web", "framework", "elixir", "phoenix"],
    authors: ["Phoenix Team"],
    license: "MIT",
    homepage: "https://phoenixframework.org",
    auto_load: false,
    default_version: "v1.7",
    versions: [
      %{
        version: "v1.7",
        root_path: "ontologies/phoenix/v1.7/phoenix.ttl",
        release_date: ~D[2023-03-01],
        is_latest: true,
        is_stable: true,
        is_deprecated: false
      }
    ]
  },

  # Medical: HL7 FHIR R4
  %{
    id: "fhir",
    name: "HL7 FHIR R4",
    description: """
    Fast Healthcare Interoperability Resources (FHIR) Release 4.
    Comprehensive healthcare data exchange standard.
    """,
    tags: ["medical", "healthcare", "interoperability"],
    authors: ["HL7 International"],
    license: "CC0-1.0",
    homepage: "https://www.hl7.org/fhir/",
    auto_load: false,
    default_version: "v4.0.1",
    versions: [
      %{
        version: "v4.0.1",
        root_path: "ontologies/fhir/v4.0.1/fhir.ttl",
        release_date: ~D[2019-11-01],
        is_latest: true,
        is_stable: true,
        is_deprecated: false,
        notes: "Normative release"
      }
    ]
  }
]

# OntologyHub GenServer Configuration
config :onto_view, OntoView.OntologyHub,
  max_loaded_sets: 5,      # Maximum sets in memory
  eviction_strategy: :lru  # LRU or LFU

# Environment-specific overrides
if config_env() == :dev do
  config :onto_view, :ontology_sets,
    # In dev, auto-load only elixir for fast startup
    Enum.map(Application.get_env(:onto_view, :ontology_sets), fn set ->
      %{set | auto_load: set.id == "elixir"}
    end)

  config :onto_view, OntoView.OntologyHub,
    max_loaded_sets: 10  # More cache in dev for hot-reloading
end

if config_env() == :test do
  config :onto_view, :ontology_sets, [
    # Test fixtures
    %{
      id: "test-simple",
      name: "Test Simple Ontology",
      description: "Simple test ontology",
      tags: ["test"],
      auto_load: false,
      default_version: "v1.0",
      versions: [
        %{
          version: "v1.0",
          root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
          is_latest: true,
          is_stable: true,
          is_deprecated: false
        }
      ]
    }
  ]

  config :onto_view, OntoView.OntologyHub,
    max_loaded_sets: 3  # Small cache for fast tests
end
```

### 5.2. Directory Structure

```
ontologies/
├── elixir/
│   ├── v1.17/
│   │   ├── hub.ttl              # Import hub for v1.17
│   │   ├── module.ttl
│   │   ├── function.ttl
│   │   ├── clause.ttl
│   │   └── ...
│   └── v1.18/
│       ├── hub.ttl              # Import hub for v1.18
│       └── ...
├── ecto/
│   └── v3.11/
│       ├── ecto.ttl
│       ├── schema.ttl
│       └── ...
├── phoenix/
│   └── v1.7/
│       ├── phoenix.ttl
│       └── ...
└── fhir/
    └── v4.0.1/
        └── fhir.ttl
```

---

## 6. Routing & URL Structure

### 6.1. Route Hierarchy

**Pattern:** `/sets/:set_id/:version/...`

```elixir
# lib/onto_view_web/router.ex

defmodule OntoViewWeb.Router do
  use OntoViewWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OntoViewWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug OntoViewWeb.Plugs.SetResolver  # Custom plug (see below)
  end

  scope "/", OntoViewWeb do
    pipe_through :browser

    # Landing page - show available sets
    get "/", PageController, :index

    # Set browser/selector
    get "/sets", SetController, :index
    get "/sets/:set_id", SetController, :show  # Show versions for a set

    # Redirect /sets/:set_id to default version
    get "/sets/:set_id/docs", SetController, :redirect_to_default_version

    # Documentation UI (set+version scoped) - Phase 2
    live "/sets/:set_id/:version/docs", DocsLive.Index
    live "/sets/:set_id/:version/docs/classes/:id", DocsLive.ClassDetail
    live "/sets/:set_id/:version/docs/properties/:id", DocsLive.PropertyDetail
    live "/sets/:set_id/:version/docs/individuals/:id", DocsLive.IndividualDetail

    # Search (set+version scoped)
    live "/sets/:set_id/:version/search", SearchLive.Index

    # Graph visualization (set+version scoped) - Phase 3
    live "/sets/:set_id/:version/graph", GraphLive.Index

    # Export API (set+version scoped) - Phase 5
    get "/sets/:set_id/:version/export/ttl", ExportController, :ttl
    get "/sets/:set_id/:version/export/json", ExportController, :json

    # Global search across all sets (optional)
    get "/search", SearchController, :global

    # Version comparison (future enhancement)
    get "/sets/:set_id/compare/:v1/:v2", CompareController, :index
  end
end
```

### 6.2. SetResolver Plug

**File:** `lib/onto_view_web/plugs/set_resolver.ex`

```elixir
defmodule OntoViewWeb.Plugs.SetResolver do
  @moduledoc """
  Resolves set_id and version from request path and loads the
  ontology set into conn.assigns for downstream use.

  This plug runs early in the pipeline to make ontology data
  available to controllers and LiveViews.
  """

  import Plug.Conn
  require Logger

  alias OntoView.OntologyHub

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, set_id} <- extract_set_id(conn),
         {:ok, version} <- extract_version(conn),
         {:ok, ontology_set} <- OntologyHub.get_set(set_id, version) do

      conn
      |> assign(:set_id, set_id)
      |> assign(:version, version)
      |> assign(:ontology_set, ontology_set)
      |> assign(:triple_store, ontology_set.triple_store)
      |> assign(:loaded_ontologies, ontology_set.loaded_ontologies)
    else
      :no_set_in_path ->
        # Not a set-scoped route (e.g., landing page)
        conn

      {:error, reason} ->
        Logger.warning("Set resolution failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Ontology set not found")
        |> Phoenix.Controller.redirect(to: "/sets")
        |> halt()
    end
  end

  defp extract_set_id(conn) do
    case conn.path_params do
      %{"set_id" => set_id} -> {:ok, set_id}
      _ -> :no_set_in_path
    end
  end

  defp extract_version(conn) do
    case conn.path_params do
      %{"version" => version} -> {:ok, version}
      _ -> :no_set_in_path
    end
  end
end
```

### 6.3. URL Examples

```
# Landing page
GET /
→ Shows grid of available ontology sets

# Set browser
GET /sets
→ Lists all configured sets with versions

# Set detail (shows versions)
GET /sets/elixir
→ Shows Elixir set with v1.17, v1.18 versions

# Redirect to default version
GET /sets/elixir/docs
→ 302 redirect to /sets/elixir/v1.17/docs

# Documentation home
GET /sets/elixir/v1.17/docs
→ Elixir v1.17 documentation landing page

# Class detail
GET /sets/elixir/v1.17/docs/classes/Module
→ Module class in Elixir v1.17

# Property detail
GET /sets/ecto/v3.11/docs/properties/hasSchema
→ hasSchema property in Ecto v3.11

# Search
GET /sets/phoenix/v1.7/search?q=controller
→ Search within Phoenix v1.7

# Graph
GET /sets/elixir/v1.17/graph
→ Graph visualization of Elixir v1.17

# Export
GET /sets/elixir/v1.17/export/ttl
→ Download Elixir v1.17 as Turtle

# Global search
GET /search?q=User
→ Search across all loaded sets

# Version comparison (future)
GET /sets/elixir/compare/v1.17/v1.18
→ Compare v1.17 and v1.18
```

---

## 7. Version Management

### 7.1. Version Naming Convention

**Semantic Versioning:**
- Format: `v{major}.{minor}.{patch}` (e.g., `v1.17.3`)
- Major: Breaking changes to ontology structure
- Minor: New classes/properties added
- Patch: Bug fixes, documentation updates

**Special Versions:**
- `latest` - Alias for most recent stable version
- `stable` - Alias for LTS/recommended version
- `dev` - Development/unreleased version

**Version Resolution:**
```elixir
# In SetController or LiveView mount
defp resolve_version("latest", set_id) do
  case OntologyHub.list_versions(set_id) do
    {:ok, versions} ->
      latest = Enum.find(versions, & &1.is_latest) || List.first(versions)
      {:ok, latest.version}

    {:error, reason} ->
      {:error, reason}
  end
end

defp resolve_version(version, _set_id), do: {:ok, version}
```

### 7.2. Version Metadata

**Stored in OntologySet:**
```elixir
%OntologySet{
  version: "v1.17.3",
  release_date: ~D[2023-06-12],
  changelog_url: "https://github.com/elixir-lang/elixir/releases/tag/v1.17.3",
  is_latest: false,
  is_stable: true,
  is_deprecated: false
}
```

**Version Badge Component (UI):**
```heex
<div class="version-badge">
  <span class="version"><%= @version %></span>

  <%= if @is_latest do %>
    <span class="badge badge-latest">Latest</span>
  <% end %>

  <%= if @is_stable do %>
    <span class="badge badge-stable">Stable</span>
  <% end %>

  <%= if @is_deprecated do %>
    <span class="badge badge-deprecated">Deprecated</span>
  <% end %>
end
```

### 7.3. Version Comparison (Future)

**API (for future Phase 6):**
```elixir
defmodule OntoView.OntologyHub.VersionComparator do
  @moduledoc """
  Compares two versions of the same ontology set to identify:
  - New classes/properties/individuals
  - Removed entities
  - Modified annotations
  - Relationship changes
  """

  @spec compare(set_id(), version_a(), version_b()) ::
    {:ok, comparison_result()} | {:error, term()}
  def compare(set_id, version_a, version_b)

  @type comparison_result :: %{
    added_classes: [iri()],
    removed_classes: [iri()],
    added_properties: [iri()],
    removed_properties: [iri()],
    modified_annotations: [%{iri: iri(), changes: map()}]
  }
end
```

---

## 8. Cache Management

### 8.1. LRU Eviction Strategy

**Implementation:**
```elixir
defp evict_lru(state) do
  # Find set with oldest last_accessed timestamp
  {evict_key, _ontology_set} =
    Enum.min_by(state.loaded_sets, fn {_key, set} ->
      DateTime.to_unix(set.last_accessed)
    end)

  Logger.info("Evicting LRU set: #{inspect(evict_key)}")

  %{state |
    loaded_sets: Map.delete(state.loaded_sets, evict_key),
    eviction_count: state.eviction_count + 1
  }
end
```

**Access Tracking:**
```elixir
# On every get_set call
ontology_set = %{ontology_set |
  last_accessed: DateTime.utc_now(),
  access_count: ontology_set.access_count + 1
}
```

### 8.2. LFU Eviction Strategy

**Implementation:**
```elixir
defp evict_lfu(state) do
  # Find set with lowest access_count
  {evict_key, _ontology_set} =
    Enum.min_by(state.loaded_sets, fn {_key, set} ->
      set.access_count
    end)

  Logger.info("Evicting LFU set: #{inspect(evict_key)}")

  %{state |
    loaded_sets: Map.delete(state.loaded_sets, evict_key),
    eviction_count: state.eviction_count + 1
  }
end
```

### 8.3. Cache Metrics

**Tracked Metrics:**
```elixir
%State{
  load_count: 15,           # Total loads (including evicted)
  eviction_count: 5,        # Total evictions
  cache_hit_count: 100,     # Hits (found in cache)
  cache_miss_count: 15,     # Misses (loaded from disk)
}

# Computed:
cache_hit_rate = cache_hit_count / (cache_hit_count + cache_miss_count)
# 100 / (100 + 15) = 0.87 (87%)
```

**Observability (Future: Telemetry):**
```elixir
:telemetry.execute(
  [:onto_view, :hub, :cache_hit],
  %{count: 1},
  %{set_id: set_id, version: version}
)

:telemetry.execute(
  [:onto_view, :hub, :eviction],
  %{count: 1},
  %{evicted_set: set_id, evicted_version: version}
)
```

---

## 9. Lifecycle & Loading

### 9.1. Startup Sequence

```
Application.start
    ↓
OntologyHub GenServer starts
    ↓
Load set configurations from config
    ↓
Schedule :auto_load message (1s delay)
    ↓
GenServer ready
    ↓
(1s later) :auto_load message received
    ↓
Load all sets with auto_load: true
    ↓
  (For each auto-load set)
    ↓
  Load default version
    ↓
  Add to cache
    ↓
Log "Auto-loaded: elixir v1.17"
```

### 9.2. Load Strategies

**Auto-Load (Startup):**
```elixir
# config.exs
%{
  id: "elixir",
  auto_load: true,  # ← Load on startup
  default_version: "v1.17"
}

# Loaded 1 second after GenServer starts
# Only default_version is loaded
```

**Lazy-Load (On Demand):**
```elixir
# config.exs
%{
  id: "fhir",
  auto_load: false,  # ← Load on first access
  default_version: "v4.0.1"
}

# Loaded when first requested via get_set("fhir", "v4.0.1")
```

**Hot-Reload (Development):**
```elixir
# In development, after editing ontology files:
iex> OntologyHub.reload_set("elixir", "v1.17")
{:ok, %OntologySet{...}}

# Evicts cached version and loads fresh from disk
```

### 9.3. Graceful Degradation

**If Load Fails:**
```elixir
# In auto_load handler
case load_set_from_config(set_id, version, state) do
  {:ok, _ontology_set, new_state} ->
    Logger.info("Auto-loaded: #{set_id} #{version}")
    new_state

  {:error, reason} ->
    # Log warning but continue with other sets
    Logger.warning("Auto-load failed for #{set_id} #{version}: #{inspect(reason)}")
    state  # Return unchanged state
end
```

**UI Feedback:**
```heex
<!-- In set selector -->
<%= for set <- @available_sets do %>
  <div class="set-card">
    <h3><%= set.name %></h3>

    <%= if set.loaded do %>
      <span class="badge-loaded">Ready</span>
    <% else %>
      <span class="badge-not-loaded">Load on access</span>
    <% end %>
  </div>
<% end %>
```

---

## 10. Testing Strategy

### 10.1. Unit Tests

**File:** `test/onto_view/ontology_hub_test.exs`

```elixir
defmodule OntoView.OntologyHubTest do
  use OntoView.DataCase, async: false  # GenServer requires sequential tests

  alias OntoView.OntologyHub
  alias OntoView.OntologyHub.OntologySet

  setup do
    # Start supervised GenServer with test config
    start_supervised!({OntologyHub, [
      max_loaded_sets: 3,
      eviction_strategy: :lru
    ]})

    :ok
  end

  describe "get_set/3" do
    test "loads and caches a valid set" do
      assert {:ok, set} = OntologyHub.get_set("test-simple", "v1.0")

      assert %OntologySet{} = set
      assert set.id == "test-simple"
      assert set.version == "v1.0"
      assert set.triple_store.count > 0

      # Second call should hit cache
      assert {:ok, ^set} = OntologyHub.get_set("test-simple", "v1.0")
    end

    test "returns error for non-existent set" do
      assert {:error, :not_configured} =
        OntologyHub.get_set("nonexistent", "v1.0")
    end

    test "returns error for non-existent version" do
      assert {:error, :load_failed, {:version_not_found, _}} =
        OntologyHub.get_set("test-simple", "v99.0")
    end
  end

  describe "list_sets/0" do
    test "returns all configured sets" do
      sets = OntologyHub.list_sets()

      assert is_list(sets)
      assert length(sets) > 0

      test_set = Enum.find(sets, & &1.id == "test-simple")
      assert test_set.name == "Test Simple Ontology"
      assert test_set.versions == ["v1.0"]
    end
  end

  describe "list_versions/1" do
    test "returns versions for a set" do
      assert {:ok, versions} = OntologyHub.list_versions("test-simple")

      assert [%{version: "v1.0", loaded: false}] = versions
    end

    test "returns error for non-existent set" do
      assert {:error, :not_found} = OntologyHub.list_versions("nonexistent")
    end
  end

  describe "cache eviction" do
    test "evicts LRU set when cache is full" do
      # Configure small cache
      OntologyHub.configure_cache(2, :lru)

      # Load 3 sets (should evict oldest)
      {:ok, _} = OntologyHub.get_set("set1", "v1.0")
      :timer.sleep(10)  # Ensure different timestamps

      {:ok, _} = OntologyHub.get_set("set2", "v1.0")
      :timer.sleep(10)

      {:ok, _} = OntologyHub.get_set("set3", "v1.0")

      # set1 should be evicted
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 2
      assert stats.eviction_count == 1
    end

    test "evicts LFU set when using LFU strategy" do
      OntologyHub.configure_cache(2, :lfu)

      {:ok, _} = OntologyHub.get_set("set1", "v1.0")
      {:ok, _} = OntologyHub.get_set("set1", "v1.0")  # Access twice

      {:ok, _} = OntologyHub.get_set("set2", "v1.0")

      {:ok, _} = OntologyHub.get_set("set3", "v1.0")  # Should evict set2 (LFU)

      stats = OntologyHub.get_stats()
      assert stats.eviction_count == 1
    end
  end

  describe "reload_set/3" do
    test "reloads a set from disk" do
      {:ok, original} = OntologyHub.get_set("test-simple", "v1.0")
      loaded_at = original.loaded_at

      :timer.sleep(100)

      {:ok, reloaded} = OntologyHub.reload_set("test-simple", "v1.0")

      assert DateTime.compare(reloaded.loaded_at, loaded_at) == :gt
    end
  end

  describe "unload_set/2" do
    test "removes set from cache" do
      {:ok, _} = OntologyHub.get_set("test-simple", "v1.0")

      stats_before = OntologyHub.get_stats()
      assert stats_before.loaded_count == 1

      :ok = OntologyHub.unload_set("test-simple", "v1.0")

      stats_after = OntologyHub.get_stats()
      assert stats_after.loaded_count == 0
    end
  end

  describe "get_stats/0" do
    test "returns cache statistics" do
      {:ok, _} = OntologyHub.get_set("test-simple", "v1.0")
      {:ok, _} = OntologyHub.get_set("test-simple", "v1.0")  # Cache hit

      stats = OntologyHub.get_stats()

      assert stats.loaded_count == 1
      assert stats.cache_hit_count >= 1
      assert stats.total_accesses >= 2
      assert stats.cache_hit_rate > 0.0
    end
  end
end
```

### 10.2. Integration Tests

**File:** `test/onto_view_web/live/docs_live_test.exs`

```elixir
defmodule OntoViewWeb.DocsLiveTest do
  use OntoViewWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount with set+version" do
    test "loads ontology set and displays documentation", %{conn: conn} do
      {:ok, view, html} = live(conn, "/sets/test-simple/v1.0/docs")

      # Should have loaded the set
      assert has_element?(view, "[data-set-id='test-simple']")
      assert has_element?(view, "[data-version='v1.0']")

      # Should display classes from the set
      assert html =~ "Module"
    end

    test "redirects on invalid set", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sets"}}} =
        live(conn, "/sets/nonexistent/v1.0/docs")
    end
  end

  describe "set switcher" do
    test "switches between sets", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sets/elixir/v1.17/docs")

      # Switch to ecto
      view
      |> element("form.set-switcher")
      |> render_change(%{"set_id" => "ecto"})

      # Should navigate to ecto default version
      assert_redirected(view, "/sets/ecto/v3.11/docs")
    end
  end
end
```

### 10.3. Performance Tests

**File:** `test/performance/hub_performance_test.exs`

```elixir
defmodule OntoView.HubPerformanceTest do
  use ExUnit.Case, async: false

  alias OntoView.OntologyHub

  @tag :performance
  test "concurrent access to same set" do
    # Warm up cache
    {:ok, _} = OntologyHub.get_set("test-simple", "v1.0")

    # Spawn 100 concurrent processes
    tasks = for _ <- 1..100 do
      Task.async(fn ->
        {time_us, {:ok, _set}} = :timer.tc(fn ->
          OntologyHub.get_set("test-simple", "v1.0")
        end)
        time_us
      end)
    end

    times = Task.await_many(tasks)

    avg_time = Enum.sum(times) / length(times)
    max_time = Enum.max(times)

    # All accesses should be fast (cache hits)
    assert avg_time < 1_000  # < 1ms average
    assert max_time < 10_000 # < 10ms max

    # Should have 100% cache hit rate
    stats = OntologyHub.get_stats()
    assert stats.cache_hit_rate == 1.0
  end

  @tag :performance
  test "load time for medium ontology" do
    # Clear cache
    OntologyHub.unload_set("test-medium", "v1.0")

    {time_us, {:ok, set}} = :timer.tc(fn ->
      OntologyHub.get_set("test-medium", "v1.0")
    end)

    time_ms = time_us / 1_000

    IO.puts("Load time: #{time_ms}ms for #{set.stats.triple_count} triples")

    # Should load < 5s for 100K triples
    assert time_ms < 5_000
  end
end
```

---

## 11. Migration Path

### 11.1. Phase 1 Compatibility

**No Changes Required to Phase 1:**

The `Ontology`, `Loader`, `ImportResolver`, and `TripleStore` modules remain unchanged. OntologyHub wraps them.

**Before (Phase 1):**
```elixir
# Direct usage
{:ok, loaded} = ImportResolver.load_with_imports("ontologies/hub.ttl")
triple_store = TripleStore.from_loaded_ontologies(loaded)
```

**After (Phase 0+1):**
```elixir
# Via hub
{:ok, set} = OntologyHub.get_set("elixir", "v1.17")
triple_store = set.triple_store
```

### 11.2. Phase 2 UI Changes

**Current Plan (Single Set):**
```elixir
# Route: /docs
def mount(_params, _session, socket) do
  # Global singleton ontology
  ontology = Application.get_env(:onto_view, :ontology)
  triple_store = ontology.triple_store
  # ...
end
```

**New Plan (Multi-Set Hub):**
```elixir
# Route: /sets/:set_id/:version/docs
def mount(%{"set_id" => set_id, "version" => version}, _session, socket) do
  # Loaded by SetResolver plug
  triple_store = socket.assigns.triple_store
  ontology_set = socket.assigns.ontology_set
  # ...
end
```

**Changes Required:**
1. Add `set_id` and `version` to route patterns
2. Use `socket.assigns.triple_store` instead of global singleton
3. Add set switcher component to UI
4. Update breadcrumbs to show set+version context

### 11.3. Backward Compatibility (Optional)

**Support old `/docs` routes:**

```elixir
# In router.ex
scope "/", OntoViewWeb do
  # Old routes redirect to default set
  get "/docs", Redirects, :docs_to_default_set
  get "/docs/classes/:id", Redirects, :class_to_default_set
end

# lib/onto_view_web/controllers/redirects.ex
defmodule OntoViewWeb.Redirects do
  use OntoViewWeb, :controller

  def docs_to_default_set(conn, _params) do
    default_set = Application.get_env(:onto_view, :default_ontology_set, "elixir")

    {:ok, set_config} = OntologyHub.get_default_set(default_set)
    version = set_config.version

    redirect(conn, to: "/sets/#{default_set}/#{version}/docs")
  end

  def class_to_default_set(conn, %{"id" => class_id}) do
    default_set = Application.get_env(:onto_view, :default_ontology_set, "elixir")
    {:ok, set_config} = OntologyHub.get_default_set(default_set)
    version = set_config.version

    redirect(conn, to: "/sets/#{default_set}/#{version}/docs/classes/#{class_id}")
  end
end
```

---

## 12. Task Breakdown

### Section 0.1 — Core Hub Infrastructure

#### Task 0.1.1 — OntologySet Data Structure
- [ ] 0.1.1.1: Define `OntologySet` struct with type specs
- [ ] 0.1.1.2: Define `SetConfiguration` struct
- [ ] 0.1.1.3: Define `State` struct (GenServer state)
- [ ] 0.1.1.4: Add `OntologyHub` module skeleton

**Deliverables:** Data structure modules with comprehensive @type specs

#### Task 0.1.2 — Configuration Loading
- [ ] 0.1.2.1: Implement `load_set_configurations/0`
- [ ] 0.1.2.2: Implement `parse_set_configuration/1`
- [ ] 0.1.2.3: Implement `parse_version_config/1`
- [ ] 0.1.2.4: Add config validation

**Deliverables:** Configuration parsing with error handling

#### Task 0.1.3 — GenServer Lifecycle
- [ ] 0.1.3.1: Implement `init/1` callback
- [ ] 0.1.3.2: Implement auto-load scheduling
- [ ] 0.1.3.3: Implement `handle_info(:auto_load, state)`
- [ ] 0.1.3.4: Add graceful shutdown handling

**Deliverables:** Functional GenServer with startup/shutdown

#### Task 0.1.99 — Unit Tests: Core Infrastructure
- [ ] 0.1.99.1: GenServer starts successfully
- [ ] 0.1.99.2: Configuration loads correctly
- [ ] 0.1.99.3: Auto-load executes on schedule
- [ ] 0.1.99.4: Invalid config handled gracefully

**Deliverables:** Test coverage for startup and configuration

---

### Section 0.2 — Set Loading & Querying

#### Task 0.2.1 — Set Loading Logic
- [ ] 0.2.1.1: Implement `load_set_from_config/3`
- [ ] 0.2.1.2: Implement `load_ontology_files/1`
- [ ] 0.2.1.3: Implement `build_triple_store/1`
- [ ] 0.2.1.4: Implement `compute_stats/2`

**Deliverables:** Complete set loading pipeline

#### Task 0.2.2 — Query API
- [ ] 0.2.2.1: Implement `get_set/3` (with lazy loading)
- [ ] 0.2.2.2: Implement `get_default_set/2`
- [ ] 0.2.2.3: Implement `list_sets/0`
- [ ] 0.2.2.4: Implement `list_versions/1`

**Deliverables:** Public query API

#### Task 0.2.3 — Cache Operations
- [ ] 0.2.3.1: Implement `reload_set/3`
- [ ] 0.2.3.2: Implement `unload_set/2`
- [ ] 0.2.3.3: Implement `get_stats/0`
- [ ] 0.2.3.4: Implement `configure_cache/2`

**Deliverables:** Cache management functions

#### Task 0.2.99 — Unit Tests: Loading & Querying
- [ ] 0.2.99.1: Load valid set successfully
- [ ] 0.2.99.2: Handle load failures gracefully
- [ ] 0.2.99.3: List sets returns correct data
- [ ] 0.2.99.4: List versions works for all sets
- [ ] 0.2.99.5: Reload updates cached data

**Deliverables:** Test coverage for all query operations

---

### Section 0.3 — Cache Management & Eviction

#### Task 0.3.1 — LRU Eviction
- [ ] 0.3.1.1: Implement `evict_lru/1`
- [ ] 0.3.1.2: Track `last_accessed` on every access
- [ ] 0.3.1.3: Update `access_log` on access
- [ ] 0.3.1.4: Enforce cache limit before adding

**Deliverables:** Working LRU cache eviction

#### Task 0.3.2 — LFU Eviction
- [ ] 0.3.2.1: Implement `evict_lfu/1`
- [ ] 0.3.2.2: Track `access_count` on every access
- [ ] 0.3.2.3: Find least frequently used set

**Deliverables:** Working LFU cache eviction

#### Task 0.3.3 — Cache Metrics
- [ ] 0.3.3.1: Track cache hits/misses
- [ ] 0.3.3.2: Track load count
- [ ] 0.3.3.3: Track eviction count
- [ ] 0.3.3.4: Compute cache hit rate

**Deliverables:** Comprehensive cache metrics

#### Task 0.3.99 — Unit Tests: Cache Management
- [ ] 0.3.99.1: LRU eviction works correctly
- [ ] 0.3.99.2: LFU eviction works correctly
- [ ] 0.3.99.3: Cache metrics are accurate
- [ ] 0.3.99.4: Cache limit enforced correctly
- [ ] 0.3.99.5: Concurrent access is safe

**Deliverables:** Test coverage for cache behavior

---

### Section 0.4 — Routing & UI Integration

#### Task 0.4.1 — SetResolver Plug
- [ ] 0.4.1.1: Create `SetResolver` plug
- [ ] 0.4.1.2: Extract set_id and version from path
- [ ] 0.4.1.3: Load ontology set into assigns
- [ ] 0.4.1.4: Handle missing sets gracefully

**Deliverables:** Plug that loads sets into conn.assigns

#### Task 0.4.2 — Route Structure
- [ ] 0.4.2.1: Define `/sets/:set_id/:version/*` routes
- [ ] 0.4.2.2: Add set browser routes
- [ ] 0.4.2.3: Add backward compatibility redirects (optional)
- [ ] 0.4.2.4: Update route helpers

**Deliverables:** Router configuration with set+version routing

#### Task 0.4.3 — Set Selection UI
- [ ] 0.4.3.1: Create landing page with set grid
- [ ] 0.4.3.2: Create set detail page (versions list)
- [ ] 0.4.3.3: Create set switcher component
- [ ] 0.4.3.4: Add version badge component

**Deliverables:** UI for browsing and selecting sets

#### Task 0.4.99 — Integration Tests: Routing
- [ ] 0.4.99.1: Routes resolve correctly
- [ ] 0.4.99.2: SetResolver loads correct set
- [ ] 0.4.99.3: Invalid routes redirect gracefully
- [ ] 0.4.99.4: LiveView mount receives set assigns

**Deliverables:** End-to-end routing tests

---

### Section 0.99 — Phase 0 Integration Testing

#### Task 0.99.1 — Multi-Set Workflow
- [ ] 0.99.1.1: Load multiple sets concurrently
- [ ] 0.99.1.2: Switch between sets in UI
- [ ] 0.99.1.3: Access different versions of same set
- [ ] 0.99.1.4: Verify isolation between sets

**Deliverables:** Full workflow integration tests

#### Task 0.99.2 — Performance Validation
- [ ] 0.99.2.1: Measure load time for typical sets
- [ ] 0.99.2.2: Measure cache hit rate after warmup
- [ ] 0.99.2.3: Test concurrent access (100+ requests)
- [ ] 0.99.2.4: Verify memory usage with max cache

**Deliverables:** Performance benchmarks and validation

#### Task 0.99.3 — Error Handling
- [ ] 0.99.3.1: Graceful degradation on load failure
- [ ] 0.99.3.2: Cache eviction under memory pressure
- [ ] 0.99.3.3: Invalid configuration detection
- [ ] 0.99.3.4: Corrupted ontology file handling

**Deliverables:** Comprehensive error scenario tests

---

## 13. Integration with Existing Phases

### 13.1. Phase 1 (Ontology Core)

**Changes:** None required

**Usage:** OntologyHub calls Phase 1 modules:
```elixir
# OntologyHub wraps Phase 1
loaded_ontologies = ImportResolver.load_with_imports(root_path, opts)
triple_store = TripleStore.from_loaded_ontologies(loaded_ontologies)
```

**Benefit:** Phase 1 remains a clean, reusable core

---

### 13.2. Phase 2 (LiveView UI)

**Changes:** Update route structure and mount logic

**Before:**
```elixir
# router.ex
live "/docs", DocsLive.Index

# docs_live.ex
def mount(_params, _session, socket) do
  ontology = Application.get_env(:onto_view, :ontology)
  # ...
end
```

**After:**
```elixir
# router.ex
live "/sets/:set_id/:version/docs", DocsLive.Index

# docs_live.ex
def mount(_params, _session, socket) do
  # Loaded by SetResolver plug
  ontology_set = socket.assigns.ontology_set
  triple_store = socket.assigns.triple_store
  # ...
end
```

**New Components:**
- Set switcher dropdown
- Version badge
- Set context breadcrumb

---

### 13.3. Phase 3 (Graph Visualization)

**Changes:** Routes become set+version scoped

```elixir
# Before
live "/graph", GraphLive.Index

# After
live "/sets/:set_id/:version/graph", GraphLive.Index
```

**Benefit:** Each set can have different graph layouts/configurations

---

### 13.4. Phase 4 (UX & Accessibility)

**Changes:** Session persistence for selected set

```elixir
# Remember user's selected set+version
put_session(conn, :selected_set, set_id)
put_session(conn, :selected_version, version)

# On next visit
get_session(conn, :selected_set) || "elixir"
```

**New Feature:** User preferences for default set

---

### 13.5. Phase 5 (Export & CI/CD)

**Changes:** Export becomes set+version scoped

```elixir
# Before
GET /export/ttl

# After
GET /sets/:set_id/:version/export/ttl
```

**Benefit:** Export specific versions, not just "current" ontology

---

## 14. Future Enhancements

### 14.1. Version Comparison (Phase 6?)

**Feature:** Side-by-side comparison of two versions

```elixir
GET /sets/elixir/compare/v1.17/v1.18

# Shows:
# - New classes in v1.18
# - Removed classes from v1.17
# - Modified annotations
# - New properties
```

**Implementation:**
```elixir
defmodule OntoView.OntologyHub.VersionComparator do
  def compare(set_id, v1, v2) do
    {:ok, set1} = OntologyHub.get_set(set_id, v1)
    {:ok, set2} = OntologyHub.get_set(set_id, v2)

    diff_classes(set1.triple_store, set2.triple_store)
    diff_properties(set1.triple_store, set2.triple_store)
    # ...
  end
end
```

---

### 14.2. Cross-Set Search

**Feature:** Search across all loaded sets

```elixir
GET /search?q=User

# Returns results from:
# - elixir v1.17 (if loaded)
# - ecto v3.11 (if loaded)
# - phoenix v1.7 (if loaded)
```

**Implementation:**
```elixir
defmodule OntoView.Search.CrossSet do
  def search_all(query) do
    OntologyHub.list_sets()
    |> Enum.filter(& &1.loaded_versions != [])
    |> Enum.flat_map(fn set ->
      search_in_set(set.id, query)
    end)
  end
end
```

---

### 14.3. Authentication & User Preferences

**Feature:** Remember user's favorite sets

```elixir
# Schema
create table(:user_preferences) do
  add :user_id, references(:users)
  add :default_set, :string
  add :default_version, :string
  add :favorite_sets, {:array, :string}
  add :recent_sets, {:array, :map}  # [{set_id, version, accessed_at}]
end
```

---

### 14.4. Remote Set Loading

**Feature:** Load sets from HTTP URLs or S3

```elixir
%{
  id: "remote-fhir",
  name: "FHIR from HL7 Server",
  versions: [
    %{
      version: "v4.0.1",
      root_url: "https://hl7.org/fhir/r4/ontology.ttl",  # ← HTTP
      is_latest: true
    }
  ]
}
```

---

### 14.5. Telemetry & Observability

**Feature:** Production metrics via Telemetry

```elixir
# lib/onto_view/application.ex
:telemetry.attach_many(
  "onto_view-hub-metrics",
  [
    [:onto_view, :hub, :cache_hit],
    [:onto_view, :hub, :cache_miss],
    [:onto_view, :hub, :eviction],
    [:onto_view, :hub, :load]
  ],
  &OntoView.Telemetry.handle_event/4,
  nil
)
```

**Dashboard:** Grafana/LiveDashboard showing:
- Cache hit rate over time
- Load times per set
- Eviction frequency
- Active users per set

---

## Appendix A: Example Configuration (Full)

**File:** `config/runtime.exs`

```elixir
import Config

config :onto_view, :ontology_sets, [
  %{
    id: "elixir",
    name: "Elixir Core Ontologies",
    description: """
    Complete semantic model of the Elixir programming language including:
    - Module system and namespacing
    - Function definitions and signatures
    - Clause pattern matching
    - Guard expressions
    - Type specifications and behaviors
    - Macro definitions and expansion
    """,
    tags: ["programming", "elixir", "functional", "beam"],
    authors: ["Elixir Core Team", "OntoView Contributors"],
    license: "Apache-2.0",
    homepage: "https://elixir-lang.org",
    auto_load: true,
    default_version: "v1.17",
    versions: [
      %{
        version: "v1.16",
        root_path: "ontologies/elixir/v1.16/hub.ttl",
        base_dir: "ontologies/elixir/v1.16",
        release_date: ~D[2023-01-22],
        changelog_url: "https://github.com/elixir-lang/elixir/releases/tag/v1.16.0",
        is_latest: false,
        is_stable: true,
        is_deprecated: false,
        notes: "Previous stable release"
      },
      %{
        version: "v1.17",
        root_path: "ontologies/elixir/v1.17/hub.ttl",
        base_dir: "ontologies/elixir/v1.17",
        release_date: ~D[2023-06-12],
        changelog_url: "https://github.com/elixir-lang/elixir/releases/tag/v1.17.0",
        is_latest: false,
        is_stable: true,
        is_deprecated: false,
        notes: "LTS release with extended support"
      },
      %{
        version: "v1.18",
        root_path: "ontologies/elixir/v1.18/hub.ttl",
        base_dir: "ontologies/elixir/v1.18",
        release_date: ~D[2024-11-20],
        changelog_url: "https://github.com/elixir-lang/elixir/releases/tag/v1.18.0",
        is_latest: true,
        is_stable: true,
        is_deprecated: false,
        notes: "Current stable release with type system improvements"
      }
    ]
  },

  %{
    id: "ecto",
    name: "Ecto Database Library",
    description: """
    Ecto is a database wrapper and query generator for Elixir. This ontology
    models schemas, queries, changesets, repositories, and associations.
    """,
    tags: ["database", "elixir", "sql", "ecto"],
    authors: ["Ecto Team", "Dashbit"],
    license: "Apache-2.0",
    homepage: "https://hexdocs.pm/ecto",
    auto_load: false,
    default_version: "v3.11",
    versions: [
      %{
        version: "v3.11",
        root_path: "ontologies/ecto/v3.11/ecto.ttl",
        release_date: ~D[2023-11-15],
        is_latest: true,
        is_stable: true,
        is_deprecated: false
      }
    ]
  },

  %{
    id: "phoenix",
    name: "Phoenix Web Framework",
    description: """
    Phoenix is a web development framework written in Elixir. This ontology
    covers controllers, views, LiveView, channels, routing, and plugs.
    """,
    tags: ["web", "framework", "elixir", "phoenix", "liveview"],
    authors: ["Phoenix Team", "Fly.io"],
    license: "MIT",
    homepage: "https://phoenixframework.org",
    auto_load: false,
    default_version: "v1.7",
    versions: [
      %{
        version: "v1.7",
        root_path: "ontologies/phoenix/v1.7/phoenix.ttl",
        release_date: ~D[2023-03-01],
        changelog_url: "https://github.com/phoenixframework/phoenix/releases/tag/v1.7.0",
        is_latest: true,
        is_stable: true,
        is_deprecated: false,
        notes: "Major LiveView improvements"
      }
    ]
  }
]

config :onto_view, OntoView.OntologyHub,
  max_loaded_sets: 5,
  eviction_strategy: :lru

# Environment-specific overrides
if config_env() == :dev do
  config :onto_view, OntoView.OntologyHub,
    max_loaded_sets: 10  # More generous cache for development
end

if config_env() == :test do
  # Use test fixtures
  config :onto_view, :ontology_sets, [
    %{
      id: "test-simple",
      name: "Test Simple Ontology",
      description: "Simple test fixture",
      tags: ["test"],
      auto_load: false,
      default_version: "v1.0",
      versions: [
        %{
          version: "v1.0",
          root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
          is_latest: true,
          is_stable: true,
          is_deprecated: false
        }
      ]
    }
  ]
end
```

---

## Appendix B: File Checklist

### New Files to Create

```
lib/onto_view/
├── ontology_hub.ex                         # Main GenServer (600 lines)
└── ontology_hub/
    ├── ontology_set.ex                     # OntologySet struct (50 lines)
    └── set_configuration.ex                # SetConfiguration struct (40 lines)

lib/onto_view_web/
├── plugs/
│   └── set_resolver.ex                     # SetResolver plug (80 lines)
└── controllers/
    ├── set_controller.ex                   # Set browser UI (120 lines)
    └── redirects.ex                        # Backward compat (40 lines)

test/onto_view/
└── ontology_hub_test.exs                   # Unit tests (400 lines)

test/onto_view_web/
└── plugs/
    └── set_resolver_test.exs               # Plug tests (100 lines)

test/performance/
└── hub_performance_test.exs                # Performance tests (150 lines)

config/
└── runtime.exs                             # Configuration (updated)

ontologies/                                  # New directory structure
├── elixir/
│   ├── v1.16/
│   ├── v1.17/
│   └── v1.18/
├── ecto/
│   └── v3.11/
└── phoenix/
    └── v1.7/
```

**Total New Code:** ~1,580 lines
**Total Test Code:** ~650 lines

---

## Appendix C: Glossary

**Set ID:** Human-readable identifier for an ontology set (e.g., "elixir", "ecto")

**Version:** Semantic version string for a specific release (e.g., "v1.17.3")

**Set+Version Key:** Compound key `{set_id, version}` uniquely identifying a cached ontology

**OntologySet:** Loaded ontology with all triples, metadata, and statistics

**SetConfiguration:** Configuration metadata for an available set (not loaded)

**Auto-Load:** Sets marked to load on application startup

**Lazy-Load:** Sets loaded on first access (on-demand)

**LRU:** Least Recently Used cache eviction strategy

**LFU:** Least Frequently Used cache eviction strategy

**Cache Hit:** Requested set found in memory

**Cache Miss:** Requested set not in memory, must load from disk

**Eviction:** Removing a set from cache to free memory

**Hub:** Central GenServer managing multiple ontology sets

**Triple Store:** Indexed RDF triple storage from Phase 1

**Provenance:** Tracking which ontology graph a triple originated from

---

## Appendix D: Decision Log

### D.1. Why GenServer Instead of ETS?

**Decision:** Use GenServer with Map-based state

**Rationale:**
- Simpler state management and lifecycle control
- Easier to implement LRU/LFU eviction (needs ordered data)
- GenServer provides natural serialization for concurrent access
- Map lookup is O(log n), acceptable for 5-10 sets
- ETS would be overkill for small cache sizes

**Trade-off:** Lower throughput than ETS, but acceptable for expected load (< 1000 req/sec)

---

### D.2. Why Set+Version in URL Instead of Query Param?

**Decision:** `/sets/elixir/v1.17/docs` not `/docs?set=elixir&version=v1.17`

**Rationale:**
- **SEO:** Search engines index paths better than query params
- **Bookmarkability:** Cleaner URLs for sharing
- **REST Semantics:** Set+version are resource identifiers, not filters
- **LiveView Integration:** Path params work better with LiveView routing

---

### D.3. Why Semantic Versioning?

**Decision:** Use `v{major}.{minor}.{patch}` format

**Rationale:**
- **Familiarity:** Developers understand SemVer
- **Breaking Changes:** Major version signals incompatible changes
- **Sortability:** Lexical sort works if zero-padded (future enhancement)
- **Clarity:** Clear communication of release type

---

### D.4. Why LRU Default Instead of LFU?

**Decision:** Default eviction strategy is LRU

**Rationale:**
- **Recency Bias:** Recently accessed sets likely to be accessed again
- **Simplicity:** Easier to reason about than frequency
- **Industry Standard:** Most caches use LRU
- **Configurable:** Users can switch to LFU if needed

---

## Conclusion

Phase 0 provides a robust foundation for multi-ontology management with versioning. By implementing this layer before Phase 2 UI work, we enable:

1. **Multi-tenant capability** - Host unrelated ontology sets (Elixir, Medical, Social)
2. **Version comparison** - View different releases side-by-side
3. **Resource efficiency** - LRU cache prevents memory exhaustion
4. **Clean separation** - Hub layer wraps Phase 1 without modifying it
5. **Future-proof routing** - Set+version scoped URLs enable rich features

**Estimated Implementation Time:**
- Core Hub (Sections 0.1-0.3): 2-3 weeks
- Routing Integration (Section 0.4): 1 week
- Testing & Polish: 1 week
- **Total:** 4-5 weeks

**Next Steps:**
1. Review and approve this specification
2. Create Phase 0 issues in GitHub
3. Set up ontology directory structure (`ontologies/elixir/v1.17/...`)
4. Begin implementation with Section 0.1 (Core Hub Infrastructure)

---

**End of Phase 0 Specification**
