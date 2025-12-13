defmodule OntoView.OntologyHub.OntologySet do
  @moduledoc """
  Represents a fully loaded ontology set with version and caching metadata.

  This struct contains the heavyweight data for a specific (set_id, version)
  combination. It wraps the Phase 1 TripleStore with additional metadata
  for multi-set management and cache eviction.

  An OntologySet is the result of loading TTL files through Phase 1's import
  resolution and triple indexing pipeline.

  ## Fields

  - `set_id` - Set identifier (e.g., "elixir")
  - `version` - Version string (e.g., "v1.17")
  - `triple_store` - Phase 1 TripleStore with indexed triples
  - `ontologies` - Map of IRI -> OntologyMetadata from import resolution
  - `stats` - Statistics about the loaded set
  - `loaded_at` - Timestamp when loaded from disk
  - `last_accessed` - Timestamp of most recent access (for LRU)
  - `access_count` - Number of times accessed (for LFU)

  ## Usage

      # Example (assuming Phase 1 loaded ontologies):
      {:ok, loaded} = ImportResolver.load_with_imports("priv/ontologies/elixir.ttl")
      store = TripleStore.from_loaded_ontologies(loaded)
      set = OntologySet.new("elixir", "v1.17", loaded, store)
      set.set_id
      # => "elixir"
      set.access_count
      # => 0

  Part of Task 0.1.1.1 — Define OntologySet struct
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.ImportResolver.{LoadedOntologies, OntologyMetadata}

  @type set_id :: String.t()
  @type version :: String.t()

  @typedoc """
  Statistics for a loaded ontology set.

  Fields:
  - `triple_count`: Total triples across all ontologies
  - `ontology_count`: Number of ontologies in this set
  - `class_count`: Total OWL classes (Phase 1.3+, nil for now)
  - `property_count`: Total properties (Phase 1.3+, nil for now)
  - `individual_count`: Total individuals (Phase 1.3+, nil for now)
  """
  @type set_stats :: %{
          triple_count: non_neg_integer(),
          ontology_count: non_neg_integer(),
          class_count: non_neg_integer() | nil,
          property_count: non_neg_integer() | nil,
          individual_count: non_neg_integer() | nil
        }

  @type t :: %__MODULE__{
          # Identity
          set_id: set_id(),
          version: version(),

          # Core Data (from Phase 1)
          triple_store: TripleStore.t(),
          ontologies: %{String.t() => OntologyMetadata.t()},

          # Metadata
          stats: set_stats(),
          loaded_at: DateTime.t(),

          # Cache Management
          last_accessed: DateTime.t(),
          access_count: non_neg_integer()
        }

  defstruct [
    :set_id,
    :version,
    :triple_store,
    :ontologies,
    :stats,
    :loaded_at,
    :last_accessed,
    :access_count
  ]

  @doc """
  Creates a new OntologySet from Phase 1 loaded ontologies.

  Takes the output of ImportResolver.load_with_imports/2 and wraps it
  with multi-set metadata.

  ## Parameters

  - `set_id` - Identifier for the ontology set (e.g., "elixir")
  - `version` - Version string (e.g., "v1.17", "latest")
  - `loaded_ontologies` - LoadedOntologies struct from ImportResolver
  - `triple_store` - TripleStore built from loaded ontologies

  ## Returns

  A new `OntologySet.t()` struct with:
  - Initialized access tracking (count = 0)
  - Current timestamps for loaded_at and last_accessed
  - Computed statistics from triple store

  ## Examples

      # See test/onto_view/ontology_hub/ontology_set_test.exs for working examples
  """
  @spec new(set_id(), version(), LoadedOntologies.t(), TripleStore.t()) :: t()
  def new(set_id, version, loaded_ontologies, triple_store)
      when is_binary(set_id) and is_binary(version) do
    now = DateTime.utc_now()

    stats = compute_stats(loaded_ontologies, triple_store)

    %__MODULE__{
      set_id: set_id,
      version: version,
      triple_store: triple_store,
      ontologies: loaded_ontologies.ontologies,
      stats: stats,
      loaded_at: now,
      last_accessed: now,
      access_count: 0
    }
  end

  @doc """
  Updates the last access timestamp and increments access count.

  Used for LRU and LFU cache eviction strategies. Returns a new struct
  following functional programming principles.

  ## Examples

      # See test/onto_view/ontology_hub/ontology_set_test.exs for working examples
  """
  @spec record_access(t()) :: t()
  def record_access(%__MODULE__{} = ontology_set) do
    %{ontology_set | last_accessed: DateTime.utc_now(), access_count: ontology_set.access_count + 1}
  end

  @doc """
  Returns the total number of triples in the set.

  Convenience accessor for stats.triple_count.

  ## Examples

      # See test/onto_view/ontology_hub/ontology_set_test.exs for working examples
  """
  @spec triple_count(t()) :: non_neg_integer()
  def triple_count(%__MODULE__{stats: %{triple_count: count}}), do: count

  @doc """
  Returns the number of ontologies in the set.

  Convenience accessor for stats.ontology_count.

  ## Examples

      # See test/onto_view/ontology_hub/ontology_set_test.exs for working examples
  """
  @spec ontology_count(t()) :: non_neg_integer()
  def ontology_count(%__MODULE__{stats: %{ontology_count: count}}), do: count

  # Private Helpers

  @spec compute_stats(LoadedOntologies.t(), TripleStore.t()) :: set_stats()
  defp compute_stats(loaded_ontologies, triple_store) do
    %{
      triple_count: TripleStore.count(triple_store),
      ontology_count: map_size(loaded_ontologies.ontologies),
      # Phase 1.3+ will add class/property/individual extraction
      class_count: nil,
      property_count: nil,
      individual_count: nil
    }
  end
end
