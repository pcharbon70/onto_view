defmodule OntoView.Ontology.Entity.Class do
  @moduledoc """
  Represents an OWL class extracted from the canonical triple store.

  This module defines the OWL class structure and provides extraction
  functions to identify all classes declared in loaded ontologies.

  ## Task Coverage

  - Task 1.3.1.1: Detect `owl:Class`
  - Task 1.3.1.2: Extract class IRIs
  - Task 1.3.1.3: Attach ontology-of-origin metadata

  ## Class Detection

  An entity is considered an OWL class if it appears as the subject of a
  triple with:
  - `rdf:type owl:Class`
  - `rdf:type rdfs:Class` (for RDFS compatibility)

  ## Provenance Tracking

  Each extracted class maintains its ontology-of-origin, enabling
  per-ontology filtering in the UI and multi-set documentation.

  Part of Task 1.3.1 — Class Extraction
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.TripleStore.Triple

  # Standard OWL/RDF/RDFS IRIs
  @rdf_type {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"}
  @owl_class {:iri, "http://www.w3.org/2002/07/owl#Class"}
  @rdfs_class {:iri, "http://www.w3.org/2000/01/rdf-schema#Class"}

  @typedoc """
  Represents an OWL class entity.

  ## Fields

  - `iri` - The full IRI of the class
  - `source_graph` - The ontology graph IRI where the class was declared
  - `type` - The RDF type used to declare the class (`:owl_class` or `:rdfs_class`)
  """
  @type t :: %__MODULE__{
          iri: String.t(),
          source_graph: String.t(),
          type: :owl_class | :rdfs_class
        }

  defstruct [:iri, :source_graph, :type]

  @doc """
  Extracts all OWL classes from a triple store.

  Scans the triple store for all `rdf:type owl:Class` and `rdf:type rdfs:Class`
  assertions, extracting the subject IRI and provenance information.

  ## Task Coverage

  - Task 1.3.1.1: Detect `owl:Class`
  - Task 1.3.1.2: Extract class IRIs
  - Task 1.3.1.3: Attach ontology-of-origin metadata

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A list of `Class.t()` structs representing all detected classes.
  Classes are deduplicated by IRI - if the same class is declared in multiple
  ontologies, only the first occurrence is returned (based on triple order).

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> classes = Class.extract_all(store)
      iex> length(classes) >= 2
      true
      iex> Enum.any?(classes, fn c -> String.ends_with?(c.iri, "Module") end)
      true
  """
  @spec extract_all(TripleStore.t()) :: [t()]
  def extract_all(%TripleStore{} = store) do
    # Task 1.3.1.1: Detect owl:Class by finding rdf:type assertions
    owl_classes = extract_classes_by_type(store, @owl_class, :owl_class)
    rdfs_classes = extract_classes_by_type(store, @rdfs_class, :rdfs_class)

    # Deduplicate by IRI, preferring owl:Class over rdfs:Class
    (owl_classes ++ rdfs_classes)
    |> Enum.uniq_by(& &1.iri)
  end

  @doc """
  Extracts OWL classes from a triple store, returning a map keyed by IRI.

  This is useful for O(1) lookups when checking if an IRI is a class.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A map where keys are class IRIs (strings) and values are `Class.t()` structs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> class_map = Class.extract_all_as_map(store)
      iex> is_map(class_map)
      true
      iex> Map.has_key?(class_map, "http://example.org/elixir/core#Module")
      true
  """
  @spec extract_all_as_map(TripleStore.t()) :: %{String.t() => t()}
  def extract_all_as_map(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Map.new(&{&1.iri, &1})
  end

  @doc """
  Extracts classes declared in a specific ontology graph.

  Filters extraction to only include classes whose declaration triple
  originated from the specified graph.

  ## Task Coverage

  - Task 1.3.1.3: Attach ontology-of-origin metadata (filtered by source)

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `graph_iri` - The IRI of the ontology graph to filter by

  ## Returns

  A list of `Class.t()` structs from the specified graph.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> graph_iri = "http://example.org/elixir/core#"
      iex> classes = Class.extract_from_graph(store, graph_iri)
      iex> Enum.all?(classes, fn c -> c.source_graph == graph_iri end)
      true
  """
  @spec extract_from_graph(TripleStore.t(), String.t()) :: [t()]
  def extract_from_graph(%TripleStore{} = store, graph_iri) do
    store
    |> extract_all()
    |> Enum.filter(&(&1.source_graph == graph_iri))
  end

  @doc """
  Counts the total number of classes in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  The count of unique classes.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> Class.count(store) >= 2
      true
  """
  @spec count(TripleStore.t()) :: non_neg_integer()
  def count(%TripleStore{} = store) do
    store |> extract_all() |> length()
  end

  @doc """
  Checks if a given IRI is a class in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI to check (as a string)

  ## Returns

  `true` if the IRI is declared as a class, `false` otherwise.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> Class.is_class?(store, "http://example.org/elixir/core#Module")
      true
      iex> Class.is_class?(store, "http://example.org/nonexistent#Foo")
      false
  """
  @spec is_class?(TripleStore.t(), String.t()) :: boolean()
  def is_class?(%TripleStore{} = store, iri) when is_binary(iri) do
    store
    |> extract_all_as_map()
    |> Map.has_key?(iri)
  end

  @doc """
  Gets a class by its IRI.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI of the class to retrieve (as a string)

  ## Returns

  `{:ok, class}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> {:ok, class} = Class.get(store, "http://example.org/elixir/core#Module")
      iex> class.type
      :owl_class
  """
  @spec get(TripleStore.t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def get(%TripleStore{} = store, iri) when is_binary(iri) do
    case extract_all_as_map(store) |> Map.get(iri) do
      nil -> {:error, :not_found}
      class -> {:ok, class}
    end
  end

  @doc """
  Lists all unique class IRIs in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A list of class IRI strings.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> iris = Class.list_iris(store)
      iex> "http://example.org/elixir/core#Module" in iris
      true
  """
  @spec list_iris(TripleStore.t()) :: [String.t()]
  def list_iris(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Enum.map(& &1.iri)
  end

  # Private functions

  # Extract classes by a specific type (owl:Class or rdfs:Class)
  # Task 1.3.1.1: Detect owl:Class
  # Task 1.3.1.2: Extract class IRIs
  @spec extract_classes_by_type(TripleStore.t(), Triple.iri_value(), :owl_class | :rdfs_class) ::
          [t()]
  defp extract_classes_by_type(store, type_iri, type_atom) do
    # Find all triples where predicate is rdf:type and object is the class type
    store
    |> TripleStore.by_predicate(@rdf_type)
    |> Enum.filter(&(&1.object == type_iri))
    |> Enum.filter(&match?({:iri, _}, &1.subject))
    |> Enum.map(fn %Triple{subject: {:iri, iri}, graph: graph} ->
      # Task 1.3.1.3: Attach ontology-of-origin metadata
      %__MODULE__{
        iri: iri,
        source_graph: graph,
        type: type_atom
      }
    end)
  end
end
