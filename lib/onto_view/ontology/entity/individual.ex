defmodule OntoView.Ontology.Entity.Individual do
  @moduledoc """
  Represents an OWL named individual extracted from the canonical triple store.

  This module defines the OWL named individual structure and provides extraction
  functions to identify all named individuals declared in loaded ontologies,
  including their class memberships.

  ## Task Coverage

  - Task 1.3.4.1: Detect named individuals
  - Task 1.3.4.2: Associate individuals with their classes

  ## Individual Detection

  An entity is considered an OWL named individual if it appears as the subject
  of a triple with:
  - `rdf:type owl:NamedIndividual`

  Additionally, individuals may be associated with classes via `rdf:type`
  assertions where the object is an OWL class (not owl:NamedIndividual itself).

  ## Class Association

  Each individual maintains a list of class IRIs it belongs to. This is
  extracted from all `rdf:type` assertions where:
  - The subject is the individual
  - The object is an IRI (excluding owl:NamedIndividual)

  ## Provenance Tracking

  Each extracted individual maintains its ontology-of-origin, enabling
  per-ontology filtering in the UI and multi-set documentation.

  ## Usage Examples

      # Load ontology and create triple store
      {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("ontology.ttl")
      store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)

      # Extract all named individuals
      individuals = Individual.extract_all(store)
      # => [%Individual{iri: "http://example.org/alice", classes: [...], ...}]

      # Extract with limit
      first_10 = Individual.extract_all(store, limit: 10)

      # Find individuals of a specific class
      people = Individual.of_class(store, "http://example.org/Person")

      # Find individuals without class associations
      unclassified = Individual.without_class(store)

  Part of Task 1.3.4 — Individual Extraction
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.TripleStore.Triple
  alias OntoView.Ontology.Namespaces
  alias OntoView.Ontology.Entity.Helpers

  @typedoc """
  Represents an OWL named individual entity.

  ## Fields

  - `iri` - The full IRI of the individual
  - `source_graph` - The ontology graph IRI where the individual was declared
  - `classes` - List of class IRIs the individual belongs to (may be empty)
  """
  @type t :: %__MODULE__{
          iri: String.t(),
          source_graph: String.t(),
          classes: [String.t()]
        }

  defstruct [:iri, :source_graph, classes: []]

  @doc """
  Extracts all OWL named individuals from a triple store.

  Scans the triple store for all `rdf:type owl:NamedIndividual` assertions,
  extracting the subject IRI, provenance information, and any class memberships.

  ## Task Coverage

  - Task 1.3.4.1: Detect named individuals
  - Task 1.3.4.2: Associate individuals with their classes

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `opts` - Optional keyword list:
    - `:limit` - Maximum number of individuals to return (default: `:infinity`)

  ## Returns

  A list of `Individual.t()` structs representing all detected named individuals.
  Individuals are deduplicated by IRI - if the same individual is declared in
  multiple ontologies, only the first occurrence is returned.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> individuals = Individual.extract_all(store)
      iex> length(individuals) >= 1
      true
  """
  @spec extract_all(TripleStore.t(), keyword()) :: [t()]
  def extract_all(%TripleStore{} = store, opts \\ []) do
    limit = Keyword.get(opts, :limit, :infinity)

    store
    |> extract_all_stream()
    |> Helpers.apply_limit(limit)
  end

  @doc """
  Returns a stream of all OWL named individuals from a triple store.

  This is useful for memory-efficient processing of large ontologies,
  as individuals are extracted lazily.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A `Stream` of `Individual.t()` structs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> stream = Individual.extract_all_stream(store)
      iex> is_function(stream, 2) or is_struct(stream, Stream)
      true
  """
  @spec extract_all_stream(TripleStore.t()) :: Enumerable.t()
  def extract_all_stream(%TripleStore{} = store) do
    rdf_type = Namespaces.rdf_type()
    owl_named_individual = Namespaces.owl_named_individual()

    # Task 1.3.4.1: Detect named individuals by finding rdf:type owl:NamedIndividual
    store
    |> TripleStore.by_predicate(rdf_type)
    |> Stream.filter(&(&1.object == owl_named_individual))
    |> Stream.filter(&match?({:iri, _}, &1.subject))
    |> Stream.map(fn %Triple{subject: {:iri, iri}, graph: graph} ->
      # Task 1.3.4.2: Associate individuals with their classes
      classes = extract_classes(store, iri)

      %__MODULE__{
        iri: iri,
        source_graph: graph,
        classes: classes
      }
    end)
    |> Stream.uniq_by(& &1.iri)
  end

  @doc """
  Extracts OWL named individuals from a triple store, returning a map keyed by IRI.

  This is useful for O(1) lookups when checking if an IRI is a named individual.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A map where keys are individual IRIs (strings) and values are `Individual.t()` structs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> ind_map = Individual.extract_all_as_map(store)
      iex> is_map(ind_map)
      true
  """
  @spec extract_all_as_map(TripleStore.t()) :: %{String.t() => t()}
  def extract_all_as_map(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Map.new(&{&1.iri, &1})
  end

  @doc """
  Extracts named individuals declared in a specific ontology graph.

  Filters extraction to only include individuals whose declaration triple
  originated from the specified graph.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `graph_iri` - The IRI of the ontology graph to filter by

  ## Returns

  A list of `Individual.t()` structs from the specified graph.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> graph_iri = "http://example.org/individuals#"
      iex> inds = Individual.extract_from_graph(store, graph_iri)
      iex> Enum.all?(inds, fn i -> i.source_graph == graph_iri end)
      true
  """
  @spec extract_from_graph(TripleStore.t(), String.t()) :: [t()]
  def extract_from_graph(%TripleStore{} = store, graph_iri) do
    store
    |> extract_all()
    |> Enum.filter(&(&1.source_graph == graph_iri))
  end

  @doc """
  Counts the total number of named individuals in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  The count of unique named individuals.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> Individual.count(store) >= 1
      true
  """
  @spec count(TripleStore.t()) :: non_neg_integer()
  def count(%TripleStore{} = store) do
    store |> extract_all() |> length()
  end

  @doc """
  Checks if a given IRI is a named individual in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI to check (as a string)

  ## Returns

  `true` if the IRI is declared as a named individual, `false` otherwise.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> Individual.is_individual?(store, "http://example.org/individuals#JohnDoe")
      true
      iex> Individual.is_individual?(store, "http://example.org/individuals#NonExistent")
      false
  """
  @spec is_individual?(TripleStore.t(), String.t()) :: boolean()
  def is_individual?(%TripleStore{} = store, iri) when is_binary(iri) do
    store
    |> extract_all_as_map()
    |> Map.has_key?(iri)
  end

  @doc """
  Gets a named individual by its IRI.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI of the individual to retrieve (as a string)

  ## Returns

  - `{:ok, individual}` if found
  - `{:error, {:not_found, iri: iri, entity_type: :individual}}` otherwise

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> {:ok, ind} = Individual.get(store, "http://example.org/individuals#JohnDoe")
      iex> "http://example.org/individuals#Person" in ind.classes
      true
  """
  @spec get(TripleStore.t(), String.t()) :: {:ok, t()} | {:error, {:not_found, keyword()}}
  def get(%TripleStore{} = store, iri) when is_binary(iri) do
    case extract_all_as_map(store) |> Map.get(iri) do
      nil -> Helpers.not_found_error(iri, :individual)
      individual -> {:ok, individual}
    end
  end

  @doc """
  Lists all unique named individual IRIs in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A list of individual IRI strings.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> iris = Individual.list_iris(store)
      iex> "http://example.org/individuals#JohnDoe" in iris
      true
  """
  @spec list_iris(TripleStore.t()) :: [String.t()]
  def list_iris(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Enum.map(& &1.iri)
  end

  @doc """
  Finds all named individuals that are members of a specific class.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `class_iri` - The IRI of the class to filter by

  ## Returns

  A list of `Individual.t()` structs that belong to the specified class.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> inds = Individual.of_class(store, "http://example.org/individuals#Person")
      iex> Enum.any?(inds, fn i -> String.ends_with?(i.iri, "JohnDoe") end)
      true
  """
  @spec of_class(TripleStore.t(), String.t()) :: [t()]
  def of_class(%TripleStore{} = store, class_iri) when is_binary(class_iri) do
    store
    |> extract_all()
    |> Helpers.filter_by_membership(:classes, class_iri)
  end

  @doc """
  Finds all named individuals that have no class associations.

  These are individuals declared as `owl:NamedIndividual` but without
  any additional `rdf:type` assertions to OWL classes.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A list of `Individual.t()` structs with empty class lists.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> unclassified = Individual.without_class(store)
      iex> Enum.all?(unclassified, fn i -> i.classes == [] end)
      true
  """
  @spec without_class(TripleStore.t()) :: [t()]
  def without_class(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Enum.filter(&(&1.classes == []))
  end

  # Private functions

  # Task 1.3.4.2: Associate individuals with their classes
  # Extract all class memberships for an individual
  @spec extract_classes(TripleStore.t(), String.t()) :: [String.t()]
  defp extract_classes(store, individual_iri) do
    individual_subject = {:iri, individual_iri}
    rdf_type = Namespaces.rdf_type()
    excluded_types = Namespaces.excluded_individual_types()

    store
    |> TripleStore.by_subject(individual_subject)
    |> Enum.filter(&(&1.predicate == rdf_type))
    |> Enum.filter(&match?({:iri, _}, &1.object))
    |> Enum.reject(&(&1.object in excluded_types))
    |> Enum.map(fn %Triple{object: {:iri, iri}} -> iri end)
  end
end
