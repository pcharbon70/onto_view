defmodule OntoView.OntologyHub.State do
  @moduledoc false
  # Private module - GenServer implementation detail for OntologyHub

  alias OntoView.OntologyHub.{SetConfiguration, OntologySet}

  @typedoc """
  Cache eviction strategy.

  - `:lru` - Least Recently Used (evict oldest last_accessed)
  - `:lfu` - Least Frequently Used (evict lowest access_count)
  """
  @type cache_strategy :: :lru | :lfu

  @typedoc """
  Cache performance metrics.

  Fields:
  - `cache_hit_count`: Total cache hits (set found in loaded_sets)
  - `cache_miss_count`: Total cache misses (required load from disk)
  - `load_count`: Total sets loaded from disk
  - `eviction_count`: Total sets evicted from cache
  - `started_at`: GenServer start timestamp
  """
  @type cache_metrics :: %{
          cache_hit_count: non_neg_integer(),
          cache_miss_count: non_neg_integer(),
          load_count: non_neg_integer(),
          eviction_count: non_neg_integer(),
          started_at: DateTime.t()
        }

  @typedoc """
  IRI resolution index for O(1) IRI lookups.

  Maps IRI strings to their containing (set_id, version) tuples.
  Rebuilt when sets are loaded/unloaded.

  Example:
      %{
        "http://example.org/Module" => {"elixir", "v1.17"},
        "http://ecto-lang.org/Schema" => {"ecto", "v3.11"}
      }
  """
  @type iri_index :: %{String.t() => {SetConfiguration.set_id(), OntologySet.version()}}

  @type t :: %__MODULE__{
          # Configuration (loaded at startup)
          configurations: %{SetConfiguration.set_id() => SetConfiguration.t()},

          # Loaded Sets (lazy loaded, cached)
          loaded_sets: %{{SetConfiguration.set_id(), OntologySet.version()} => OntologySet.t()},

          # Cache Configuration
          cache_strategy: cache_strategy(),
          cache_limit: non_neg_integer(),

          # Performance Metrics
          metrics: cache_metrics(),

          # IRI Resolution (Task 0.2.4)
          iri_index: iri_index()
        }

  defstruct [
    configurations: %{},
    loaded_sets: %{},
    cache_strategy: :lru,
    cache_limit: 5,
    metrics: %{
      cache_hit_count: 0,
      cache_miss_count: 0,
      load_count: 0,
      eviction_count: 0,
      started_at: nil
    },
    iri_index: %{}
  ]

  @doc """
  Initializes GenServer state with configurations.

  Called during GenServer.init/1.

  ## Options

  - `:cache_strategy` - `:lru` or `:lfu` (default: `:lru`)
  - `:cache_limit` - Max loaded sets (default: 5)

  ## Examples

      iex> configs = [%SetConfiguration{set_id: "test", display: %{name: "Test"}, versions: [], default_version: "v1"}]
      iex> state = State.new(configs)
      iex> map_size(state.configurations)
      1
      iex> state.cache_strategy
      :lru
      iex> state.cache_limit
      5
  """
  @spec new([SetConfiguration.t()], keyword()) :: t()
  def new(configurations, opts \\ []) when is_list(configurations) do
    config_map =
      configurations
      |> Enum.map(fn config -> {config.set_id, config} end)
      |> Map.new()

    %__MODULE__{
      configurations: config_map,
      cache_strategy: Keyword.get(opts, :cache_strategy, :lru),
      cache_limit: Keyword.get(opts, :cache_limit, 5),
      metrics: %{
        cache_hit_count: 0,
        cache_miss_count: 0,
        load_count: 0,
        eviction_count: 0,
        started_at: DateTime.utc_now()
      }
    }
  end

  @doc """
  Records a cache hit and updates access metadata for a set.

  Updates the OntologySet's access tracking via OntologySet.record_access/1.

  ## Examples

      # See test/onto_view/ontology_hub/state_test.exs for working examples
  """
  @spec record_cache_hit(t(), SetConfiguration.set_id(), OntologySet.version()) :: t()
  def record_cache_hit(%__MODULE__{} = state, set_id, version) do
    key = {set_id, version}

    updated_set = OntologySet.record_access(state.loaded_sets[key])
    updated_loaded_sets = Map.put(state.loaded_sets, key, updated_set)
    updated_metrics = Map.update!(state.metrics, :cache_hit_count, &(&1 + 1))

    %{state | loaded_sets: updated_loaded_sets, metrics: updated_metrics}
  end

  @doc """
  Records a cache miss (will trigger load).

  ## Examples

      iex> state = %State{metrics: %{cache_hit_count: 10, cache_miss_count: 2, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}}
      iex> updated = State.record_cache_miss(state)
      iex> updated.metrics.cache_miss_count
      3
  """
  @spec record_cache_miss(t()) :: t()
  def record_cache_miss(%__MODULE__{} = state) do
    updated_metrics = Map.update!(state.metrics, :cache_miss_count, &(&1 + 1))
    %{state | metrics: updated_metrics}
  end

  @doc """
  Records a successful load operation.

  ## Examples

      iex> state = %State{metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 5, eviction_count: 0, started_at: DateTime.utc_now()}}
      iex> updated = State.record_load(state)
      iex> updated.metrics.load_count
      6
  """
  @spec record_load(t()) :: t()
  def record_load(%__MODULE__{} = state) do
    updated_metrics = Map.update!(state.metrics, :load_count, &(&1 + 1))
    %{state | metrics: updated_metrics}
  end

  @doc """
  Records a cache eviction.

  ## Examples

      iex> state = %State{metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 0, eviction_count: 3, started_at: DateTime.utc_now()}}
      iex> updated = State.record_eviction(state)
      iex> updated.metrics.eviction_count
      4
  """
  @spec record_eviction(t()) :: t()
  def record_eviction(%__MODULE__{} = state) do
    updated_metrics = Map.update!(state.metrics, :eviction_count, &(&1 + 1))
    %{state | metrics: updated_metrics}
  end

  @doc """
  Adds a newly loaded set to cache, evicting if necessary.

  If cache is at limit, evicts according to strategy before adding.
  Updates IRI index with all subjects from the new set.

  ## Examples

      iex> state = %State{cache_limit: 2, loaded_sets: %{}}
      iex> set = %OntologySet{set_id: "test", version: "v1"}
      iex> updated = State.add_loaded_set(state, set)
      iex> map_size(updated.loaded_sets)
      1
      iex> updated.loaded_sets[{"test", "v1"}].set_id
      "test"
  """
  @spec add_loaded_set(t(), OntologySet.t()) :: t()
  def add_loaded_set(%__MODULE__{} = state, %OntologySet{} = ontology_set) do
    key = {ontology_set.set_id, ontology_set.version}

    # Evict if at capacity and this is a new set
    state =
      if map_size(state.loaded_sets) >= state.cache_limit and
           not Map.has_key?(state.loaded_sets, key) do
        evict_one(state)
      else
        state
      end

    # Add the set and update IRI index
    updated_loaded_sets = Map.put(state.loaded_sets, key, ontology_set)
    updated_iri_index = add_iris_to_index(state.iri_index, ontology_set)
    %{state | loaded_sets: updated_loaded_sets, iri_index: updated_iri_index}
  end

  @doc """
  Removes a set from the cache.

  Also removes all IRIs from the IRI index that belong to this set.

  ## Examples

      iex> set = %OntologySet{set_id: "test", version: "v1"}
      iex> state = %State{loaded_sets: %{{"test", "v1"} => set}}
      iex> updated = State.remove_set(state, "test", "v1")
      iex> map_size(updated.loaded_sets)
      0
  """
  @spec remove_set(t(), SetConfiguration.set_id(), OntologySet.version()) :: t()
  def remove_set(%__MODULE__{} = state, set_id, version) do
    key = {set_id, version}
    updated_loaded_sets = Map.delete(state.loaded_sets, key)
    updated_iri_index = remove_iris_from_index(state.iri_index, set_id, version)
    %{state | loaded_sets: updated_loaded_sets, iri_index: updated_iri_index}
  end

  @doc """
  Computes cache hit rate (hits / total accesses).

  Returns 0.0 if no accesses yet.

  ## Examples

      iex> state = %State{metrics: %{cache_hit_count: 87, cache_miss_count: 13, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}}
      iex> State.cache_hit_rate(state)
      0.87

      iex> state = %State{metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}}
      iex> State.cache_hit_rate(state)
      0.0
  """
  @spec cache_hit_rate(t()) :: float()
  def cache_hit_rate(%__MODULE__{metrics: metrics}) do
    total = metrics.cache_hit_count + metrics.cache_miss_count

    if total == 0 do
      0.0
    else
      metrics.cache_hit_count / total
    end
  end

  @doc """
  Returns the number of currently loaded sets.

  ## Examples

      iex> state = %State{loaded_sets: %{{"a", "v1"} => %OntologySet{}, {"b", "v2"} => %OntologySet{}}}
      iex> State.loaded_count(state)
      2
  """
  @spec loaded_count(t()) :: non_neg_integer()
  def loaded_count(%__MODULE__{loaded_sets: loaded_sets}) do
    map_size(loaded_sets)
  end

  # Private Helpers

  # Evict one set according to cache strategy
  @spec evict_one(t()) :: t()
  defp evict_one(%__MODULE__{cache_strategy: :lru} = state) do
    evict_lru(state)
  end

  defp evict_one(%__MODULE__{cache_strategy: :lfu} = state) do
    evict_lfu(state)
  end

  # Evict least recently used (oldest last_accessed)
  @spec evict_lru(t()) :: t()
  defp evict_lru(%__MODULE__{} = state) do
    case find_lru_key(state.loaded_sets) do
      nil ->
        state

      key ->
        state
        |> remove_set(elem(key, 0), elem(key, 1))
        |> record_eviction()
    end
  end

  # Evict least frequently used (lowest access_count)
  @spec evict_lfu(t()) :: t()
  defp evict_lfu(%__MODULE__{} = state) do
    case find_lfu_key(state.loaded_sets) do
      nil ->
        state

      key ->
        state
        |> remove_set(elem(key, 0), elem(key, 1))
        |> record_eviction()
    end
  end

  @spec find_lru_key(%{{String.t(), String.t()} => OntologySet.t()}) ::
          {String.t(), String.t()} | nil
  defp find_lru_key(loaded_sets) do
    loaded_sets
    |> Enum.min_by(fn {_key, set} -> set.last_accessed end, fn -> nil end)
    |> case do
      nil -> nil
      {key, _set} -> key
    end
  end

  @spec find_lfu_key(%{{String.t(), String.t()} => OntologySet.t()}) ::
          {String.t(), String.t()} | nil
  defp find_lfu_key(loaded_sets) do
    loaded_sets
    |> Enum.min_by(fn {_key, set} -> set.access_count end, fn -> nil end)
    |> case do
      nil -> nil
      {key, _set} -> key
    end
  end

  # IRI Index Management (Task 0.2.4)

  @spec build_iri_index_for_set(OntologySet.t()) :: iri_index()
  defp build_iri_index_for_set(%OntologySet{triple_store: nil} = ontology_set) do
    # No triple store - return empty index
    %{}
  end

  defp build_iri_index_for_set(%OntologySet{} = ontology_set) do
    key = {ontology_set.set_id, ontology_set.version}

    # Get all IRI subjects from the triple store's subject_index
    # Subject index keys are tuples like {:iri, "http://..."} or {:blank, "..."}
    # We only want IRIs, not blank nodes
    ontology_set.triple_store.subject_index
    |> Map.keys()
    |> Enum.filter(fn
      {:iri, _iri} -> true
      _other -> false
    end)
    |> Enum.map(fn {:iri, iri} -> {iri, key} end)
    |> Map.new()
  end

  @spec add_iris_to_index(iri_index(), OntologySet.t()) :: iri_index()
  defp add_iris_to_index(iri_index, %OntologySet{} = ontology_set) do
    set_iris = build_iri_index_for_set(ontology_set)
    Map.merge(iri_index, set_iris)
  end

  @spec remove_iris_from_index(iri_index(), SetConfiguration.set_id(), OntologySet.version()) ::
          iri_index()
  defp remove_iris_from_index(iri_index, set_id, version) do
    key = {set_id, version}

    # Remove all IRIs that belong to this set
    Enum.reject(iri_index, fn {_iri, set_key} -> set_key == key end)
    |> Map.new()
  end
end
