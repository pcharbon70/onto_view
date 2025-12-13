defmodule OntoView.OntologyHub do
  @moduledoc """
  Multi-ontology hub GenServer managing versioned ontology sets.

  The OntologyHub enables OntoView to host multiple independent ontology
  sets (e.g., Elixir, Ecto, Phoenix) with versioning support, lazy loading,
  and intelligent caching.

  ## Architecture

  - **Configuration Layer**: Lightweight metadata loaded at startup
  - **Loading Layer**: On-demand loading via Phase 1 pipeline
  - **Caching Layer**: LRU/LFU eviction with configurable limits
  - **Query Layer**: Synchronous API for retrieving loaded sets

  ## Configuration

  Configure available ontology sets in `config/runtime.exs`:

      config :onto_view, :ontology_sets, [
        [
          set_id: "elixir",
          name: "Elixir Core Ontology",
          versions: [
            [version: "v1.17", root_path: "priv/ontologies/elixir/v1.17.ttl", default: true]
          ],
          auto_load: true
        ]
      ]

  ## Starting

  The OntologyHub is supervised by OntoView.Application:

      children = [
        OntoView.OntologyHub
      ]

  ## Query API

  - `get_set/3` - Get a specific set+version (lazy load)
  - `get_default_set/2` - Get default version of a set
  - `list_sets/0` - List all available sets (metadata only)
  - `list_versions/1` - List versions for a set

  ## Cache Management

  - `reload_set/3` - Force reload from disk (dev use)
  - `unload_set/2` - Evict from cache
  - `get_stats/0` - Cache performance metrics
  - `configure_cache/1` - Runtime cache tuning

  ## IRI Resolution (Task 0.2.4)

  - `resolve_iri/1` - Find which set contains an IRI

  Part of Section 0.1 — Core Hub Infrastructure
  """

  use GenServer
  require Logger

  alias OntoView.OntologyHub.{State, SetConfiguration, VersionConfiguration, OntologySet}
  alias OntoView.Ontology.{ImportResolver, TripleStore}

  @auto_load_delay_ms 1000

  # Client API (Public Interface)

  @doc """
  Starts the OntologyHub GenServer.

  ## Options

  - `:name` - GenServer name (default: `__MODULE__`)
  - `:cache_strategy` - `:lru` or `:lfu` (default: `:lru`)
  - `:cache_limit` - Max loaded sets (default: 5)

  ## Examples

      # Started automatically by Application supervision tree
      {:ok, pid} = OntoView.OntologyHub.start_link()
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Retrieves a specific ontology set by ID and version.

  Lazy loads if not in cache. Updates cache access metadata.

  ## Parameters

  - `set_id` - Set identifier (e.g., "elixir")
  - `version` - Version string (e.g., "v1.17")
  - `opts` - Options (reserved for future use)

  ## Returns

  - `{:ok, OntologySet.t()}` - Loaded set (from cache or disk)
  - `{:error, :set_not_found}` - Unknown set_id
  - `{:error, :version_not_found}` - Unknown version
  - `{:error, reason}` - Load failure

  ## Examples

      iex> {:ok, set} = OntologyHub.get_set("elixir", "v1.17")
      iex> set.set_id
      "elixir"

  Part of Task 0.2.2 — Public Query API
  """
  @spec get_set(String.t(), String.t(), keyword()) :: {:ok, OntologySet.t()} | {:error, term()}
  def get_set(set_id, version, opts \\ []) when is_binary(set_id) and is_binary(version) do
    GenServer.call(__MODULE__, {:get_set, set_id, version, opts})
  end

  @doc """
  Retrieves the default version of a set.

  Convenience wrapper around get_set/3.

  ## Examples

      iex> {:ok, set} = OntologyHub.get_default_set("elixir")
      iex> set.version
      "v1.17"  # or whatever is configured as default
  """
  @spec get_default_set(String.t(), keyword()) :: {:ok, OntologySet.t()} | {:error, term()}
  def get_default_set(set_id, opts \\ []) when is_binary(set_id) do
    GenServer.call(__MODULE__, {:get_default_set, set_id, opts})
  end

  @doc """
  Lists all available ontology sets (metadata only).

  Returns lightweight SetConfiguration structs, not loaded sets.

  ## Returns

  List of `%{set_id, name, versions, default_version, loaded}` maps.

  ## Examples

      iex> sets = OntologyHub.list_sets()
      iex> Enum.find(sets, & &1.set_id == "elixir")
      %{set_id: "elixir", name: "Elixir Core Ontology", ...}
  """
  @spec list_sets() :: [map()]
  def list_sets do
    GenServer.call(__MODULE__, :list_sets)
  end

  @doc """
  Lists all versions for a specific set.

  ## Returns

  - `{:ok, [%{version, default, loaded, stats}]}` - Version metadata
  - `{:error, :set_not_found}` - Unknown set_id

  ## Examples

      iex> {:ok, versions} = OntologyHub.list_versions("elixir")
      iex> Enum.any?(versions, & &1.default)
      true
  """
  @spec list_versions(String.t()) :: {:ok, [map()]} | {:error, :set_not_found}
  def list_versions(set_id) when is_binary(set_id) do
    GenServer.call(__MODULE__, {:list_versions, set_id})
  end

  # Cache Management API (Task 0.2.3)

  @doc """
  Forces reload of a set from disk.

  Useful for development when TTL files change.

  ## Examples

      iex> :ok = OntologyHub.reload_set("elixir", "v1.17")
  """
  @spec reload_set(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def reload_set(set_id, version, opts \\ []) when is_binary(set_id) and is_binary(version) do
    GenServer.call(__MODULE__, {:reload_set, set_id, version, opts})
  end

  @doc """
  Unloads a set from cache to free memory.

  ## Examples

      iex> :ok = OntologyHub.unload_set("elixir", "v1.17")
  """
  @spec unload_set(String.t(), String.t()) :: :ok | {:error, :not_loaded}
  def unload_set(set_id, version) when is_binary(set_id) and is_binary(version) do
    GenServer.call(__MODULE__, {:unload_set, set_id, version})
  end

  @doc """
  Returns cache performance statistics.

  ## Returns

      %{
        loaded_count: 3,
        cache_hit_rate: 0.87,
        cache_hit_count: 42,
        cache_miss_count: 6,
        eviction_count: 1,
        uptime_seconds: 3600
      }
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Configures cache behavior at runtime.

  ## Options

  - `:strategy` - `:lru` or `:lfu`
  - `:limit` - Max loaded sets

  ## Examples

      iex> :ok = OntologyHub.configure_cache(strategy: :lfu, limit: 10)
  """
  @spec configure_cache(keyword()) :: :ok
  def configure_cache(opts) when is_list(opts) do
    GenServer.call(__MODULE__, {:configure_cache, opts})
  end

  # IRI Resolution API (Task 0.2.4)

  @doc """
  Resolves an IRI to its containing set and version.

  Searches all loaded sets for the IRI, returning metadata about where it's defined.

  ## Returns

  - `{:ok, %{set_id, version, entity_type, iri}}` - IRI found
  - `{:error, :iri_not_found}` - IRI not in any loaded set

  ## Examples

      iex> {:ok, result} = OntologyHub.resolve_iri("http://example.org/MyClass")
      iex> result.set_id
      "elixir"
  """
  @spec resolve_iri(String.t()) :: {:ok, map()} | {:error, :iri_not_found}
  def resolve_iri(iri) when is_binary(iri) do
    GenServer.call(__MODULE__, {:resolve_iri, iri})
  end

  # GenServer Callbacks (Task 0.1.3)

  @impl true
  def init(opts) do
    Logger.info("Starting OntologyHub GenServer")

    # Load configurations from Application env
    case load_set_configurations() do
      {:ok, configs} ->
        state = State.new(configs, opts)
        Logger.info("Loaded #{map_size(state.configurations)} ontology set configurations")

        # Schedule auto-load for sets with auto_load: true
        Process.send_after(self(), :auto_load, @auto_load_delay_ms)

        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to load ontology set configurations: #{inspect(reason)}")
        {:stop, {:config_error, reason}}
    end
  end

  @impl true
  def handle_call({:get_set, set_id, version, _opts}, _from, state) do
    key = {set_id, version}

    case Map.get(state.loaded_sets, key) do
      nil ->
        # Cache miss - need to load
        state = State.record_cache_miss(state)

        case load_set(state, set_id, version) do
          {:ok, ontology_set, new_state} ->
            new_state = State.record_load(new_state)
            {:reply, {:ok, ontology_set}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      ontology_set ->
        # Cache hit
        new_state = State.record_cache_hit(state, set_id, version)
        {:reply, {:ok, ontology_set}, new_state}
    end
  end

  @impl true
  def handle_call({:get_default_set, set_id, opts}, _from, state) do
    case Map.get(state.configurations, set_id) do
      nil ->
        {:reply, {:error, :set_not_found}, state}

      config ->
        version = config.default_version
        # Delegate to get_set
        handle_call({:get_set, set_id, version, opts}, nil, state)
    end
  end

  @impl true
  def handle_call(:list_sets, _from, state) do
    sets =
      state.configurations
      |> Enum.map(fn {_id, config} ->
        loaded_versions =
          Enum.filter(state.loaded_sets, fn {{sid, _v}, _set} -> sid == config.set_id end)
          |> Enum.map(fn {{_sid, v}, _set} -> v end)

        %{
          set_id: config.set_id,
          name: config.display.name,
          description: config.display.description,
          homepage_url: config.display.homepage_url,
          versions: SetConfiguration.list_version_strings(config),
          default_version: config.default_version,
          loaded_versions: loaded_versions,
          auto_load: config.auto_load,
          priority: config.priority
        }
      end)
      |> Enum.sort_by(& &1.priority)

    {:reply, sets, state}
  end

  @impl true
  def handle_call({:list_versions, set_id}, _from, state) do
    case Map.get(state.configurations, set_id) do
      nil ->
        {:reply, {:error, :set_not_found}, state}

      config ->
        versions =
          Enum.map(config.versions, fn vc ->
            key = {set_id, vc.version}
            loaded_set = Map.get(state.loaded_sets, key)

            %{
              version: vc.version,
              default: vc.default,
              root_path: vc.root_path,
              loaded: loaded_set != nil,
              stats: if(loaded_set, do: loaded_set.stats, else: nil),
              release_metadata: vc.release_metadata
            }
          end)

        {:reply, {:ok, versions}, state}
    end
  end

  @impl true
  def handle_call({:reload_set, set_id, version, _opts}, _from, state) do
    # Remove from cache if loaded, then load fresh
    state = State.remove_set(state, set_id, version)

    case load_set(state, set_id, version) do
      {:ok, _ontology_set, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unload_set, set_id, version}, _from, state) do
    key = {set_id, version}

    if Map.has_key?(state.loaded_sets, key) do
      new_state = State.remove_set(state, set_id, version)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_loaded}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    uptime_seconds =
      DateTime.diff(DateTime.utc_now(), state.metrics.started_at, :second)

    stats =
      state.metrics
      |> Map.put(:loaded_count, State.loaded_count(state))
      |> Map.put(:cache_hit_rate, State.cache_hit_rate(state))
      |> Map.put(:uptime_seconds, uptime_seconds)

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:configure_cache, opts}, _from, state) do
    new_state =
      state
      |> maybe_update_cache_strategy(opts)
      |> maybe_update_cache_limit(opts)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:resolve_iri, iri}, _from, state) do
    # Check IRI index first (O(1))
    case Map.get(state.iri_index, iri) do
      {set_id, version} = _key ->
        # TODO: Determine entity_type from triple store
        result = %{
          set_id: set_id,
          version: version,
          entity_type: :unknown,
          iri: iri
        }

        {:reply, {:ok, result}, state}

      nil ->
        {:reply, {:error, :iri_not_found}, state}
    end
  end

  @impl true
  def handle_info(:auto_load, state) do
    Logger.info("Auto-loading configured ontology sets")

    new_state =
      state.configurations
      |> Enum.filter(fn {_id, config} -> config.auto_load end)
      |> Enum.sort_by(fn {_id, config} -> config.priority end)
      |> Enum.reduce(state, fn {set_id, config}, acc_state ->
        version = config.default_version

        case load_set(acc_state, set_id, version) do
          {:ok, _set, new_state} ->
            Logger.info("Auto-loaded #{set_id} #{version}")
            new_state

          {:error, reason} ->
            Logger.error("Failed to auto-load #{set_id} #{version}: #{inspect(reason)}")
            acc_state
        end
      end)

    {:noreply, new_state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("OntologyHub terminating: #{inspect(reason)}")
    Logger.info("Final stats: #{State.loaded_count(state)} sets loaded")
    :ok
  end

  # Private Functions (Task 0.2.1 — Set Loading Pipeline)

  # Load a set from configuration, add to cache
  @spec load_set(State.t(), String.t(), String.t()) ::
          {:ok, OntologySet.t(), State.t()} | {:error, term()}
  defp load_set(state, set_id, version) do
    with {:ok, set_config} <- fetch_set_config(state, set_id),
         {:ok, version_config} <- fetch_version_config(set_config, version),
         {:ok, loaded_ontologies} <- load_ontology_files(version_config),
         {:ok, triple_store} <- build_triple_store(loaded_ontologies) do
      ontology_set = OntologySet.new(set_id, version, loaded_ontologies, triple_store)
      new_state = State.add_loaded_set(state, ontology_set)

      {:ok, ontology_set, new_state}
    end
  end

  @spec fetch_set_config(State.t(), String.t()) ::
          {:ok, SetConfiguration.t()} | {:error, :set_not_found}
  defp fetch_set_config(state, set_id) do
    case Map.get(state.configurations, set_id) do
      nil -> {:error, :set_not_found}
      config -> {:ok, config}
    end
  end

  @spec fetch_version_config(SetConfiguration.t(), String.t()) ::
          {:ok, VersionConfiguration.t()} | {:error, :version_not_found}
  defp fetch_version_config(set_config, version) do
    case SetConfiguration.get_version(set_config, version) do
      nil -> {:error, :version_not_found}
      version_config -> {:ok, version_config}
    end
  end

  @spec load_ontology_files(VersionConfiguration.t()) ::
          {:ok, ImportResolver.loaded_ontologies()} | {:error, term()}
  defp load_ontology_files(version_config) do
    base_dir = version_config.base_dir || Path.dirname(version_config.root_path)

    ImportResolver.load_with_imports(version_config.root_path, base_dir: base_dir)
  end

  @spec build_triple_store(ImportResolver.loaded_ontologies()) ::
          {:ok, TripleStore.t()} | {:error, term()}
  defp build_triple_store(loaded_ontologies) do
    {:ok, TripleStore.from_loaded_ontologies(loaded_ontologies)}
  end

  # Configuration Loading (Task 0.1.2)

  @spec load_set_configurations() :: {:ok, [SetConfiguration.t()]} | {:error, term()}
  defp load_set_configurations do
    case Application.get_env(:onto_view, :ontology_sets) do
      nil ->
        Logger.warning("No :ontology_sets configuration found")
        {:ok, []}

      configs when is_list(configs) ->
        configs
        |> Enum.reduce_while({:ok, []}, fn config_kw, {:ok, acc} ->
          case SetConfiguration.from_config(config_kw) do
            {:ok, set_config} ->
              {:cont, {:ok, [set_config | acc]}}

            {:error, reason} ->
              {:halt, {:error, {:invalid_set_config, reason, config_kw}}}
          end
        end)
        |> case do
          {:ok, configs} -> {:ok, Enum.reverse(configs)}
          error -> error
        end

      _ ->
        {:error, :invalid_ontology_sets_format}
    end
  end

  # Cache Management Helpers

  defp maybe_update_cache_strategy(state, opts) do
    case Keyword.get(opts, :strategy) do
      nil -> state
      strategy when strategy in [:lru, :lfu] -> %{state | cache_strategy: strategy}
      _ -> state
    end
  end

  defp maybe_update_cache_limit(state, opts) do
    case Keyword.get(opts, :limit) do
      nil -> state
      limit when is_integer(limit) and limit > 0 -> %{state | cache_limit: limit}
      _ -> state
    end
  end
end
