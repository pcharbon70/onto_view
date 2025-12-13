defmodule OntoView.Ontology.TripleStore do
  @moduledoc """
  Manages the canonical triple store extracted from loaded ontologies.

  This module extracts triples from RDF.Dataset structures (produced by
  Section 1.1 import resolution) and provides a normalized, queryable
  representation for OWL entity extraction (Section 1.3).

  ## Architecture

  The TripleStore serves as the canonical triple layer between:
  - **Input**: RDF.Dataset from ImportResolver (Section 1.1)
  - **Output**: Normalized triples for OWL entity extraction (Section 1.3)

  ## Provenance Tracking

  All triples maintain provenance information indicating which ontology
  graph they originated from. This is preserved via the `graph` field
  in each `Triple.t()` struct, using the named graph IRIs from the
  RDF.Dataset.

  ## Subtask Coverage

  - Task 1.2.1.1: Parse (subject, predicate, object) triples
  - Task 1.2.1.2: Normalize IRIs (via Triple module)
  - Task 1.2.1.3: Expand prefix mappings (handled by RDF.ex during parsing)
  - Task 1.2.1.4: Separate literals from IRIs (via Triple module)
  - Task 1.2.2: Blank node stabilization (via BlankNodeStabilizer module)
  - Task 1.2.3.1: Index by subject
  - Task 1.2.3.2: Index by predicate
  - Task 1.2.3.3: Index by object

  ## Query Interface

  The module provides indexed query functions for efficient triple lookup:
  - `all/1` - Retrieve all triples (O(1))
  - `from_graph/2` - Filter triples by ontology graph (O(n))
  - `count/1` - Count total triples (O(1))
  - `by_subject/2` - Find triples by subject (O(log n), Task 1.2.3.1)
  - `by_predicate/2` - Find triples by predicate (O(log n), Task 1.2.3.2)
  - `by_object/2` - Find triples by object (O(log n), Task 1.2.3.3)

  Part of Task 1.2.1 — RDF Triple Parsing
  """

  alias OntoView.Ontology.TripleStore.Triple
  alias OntoView.Ontology.TripleStore.BlankNodeStabilizer
  alias OntoView.Ontology.ImportResolver.LoadedOntologies

  @type t :: %__MODULE__{
          triples: [Triple.t()],
          count: non_neg_integer(),
          ontologies: MapSet.t(String.t()),
          subject_index: %{Triple.subject_value() => [Triple.t()]},
          predicate_index: %{Triple.predicate_value() => [Triple.t()]},
          object_index: %{Triple.object_value() => [Triple.t()]}
        }

  defstruct triples: [],
            count: 0,
            ontologies: MapSet.new(),
            subject_index: %{},
            predicate_index: %{},
            object_index: %{}

  @doc """
  Builds a triple store from loaded ontologies.

  Extracts all triples from all named graphs in the dataset,
  converting them to canonical format with provenance tracking.

  ## Task Coverage

  - Task 1.2.1.1: Parse (subject, predicate, object) triples
  - Task 1.2.2: Blank node stabilization
  - Task 1.2.3: Triple indexing (subject, predicate, object)

  ## Parameters

  - `loaded_ontologies` - LoadedOntologies struct from ImportResolver

  ## Returns

  A `TripleStore.t()` containing all normalized triples.

  ## Examples

      iex> {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = TripleStore.from_loaded_ontologies(loaded)
      iex> store.count > 0
      true
      iex> is_list(store.triples)
      true
  """
  @spec from_loaded_ontologies(LoadedOntologies.t()) :: t()
  def from_loaded_ontologies(%LoadedOntologies{} = loaded) do
    raw_triples = extract_all_triples(loaded.dataset)
    stabilized_triples = BlankNodeStabilizer.stabilize(raw_triples)
    ontology_iris = MapSet.new(Map.keys(loaded.ontologies))

    # Build indexes (Task 1.2.3)
    {subject_idx, predicate_idx, object_idx} = build_indexes(stabilized_triples)

    %__MODULE__{
      triples: stabilized_triples,
      count: length(stabilized_triples),
      ontologies: ontology_iris,
      subject_index: subject_idx,
      predicate_index: predicate_idx,
      object_index: object_idx
    }
  end

  @doc """
  Returns all triples in the store.

  ## Examples

      iex> {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = TripleStore.from_loaded_ontologies(loaded)
      iex> all_triples = TripleStore.all(store)
      iex> is_list(all_triples)
      true
      iex> length(all_triples) == store.count
      true
  """
  @spec all(t()) :: [Triple.t()]
  def all(%__MODULE__{triples: triples}), do: triples

  @doc """
  Returns triples from a specific ontology graph.

  Filters triples by their graph provenance, returning only those
  that originated from the specified ontology IRI.

  ## Parameters

  - `store` - The triple store
  - `graph_iri` - IRI of the ontology graph to filter by

  ## Returns

  List of triples from the specified graph.

  ## Examples

      iex> {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/integration/hub.ttl")
      iex> store = TripleStore.from_loaded_ontologies(loaded)
      iex> hub_iri = loaded.import_chain.root_iri
      iex> hub_triples = TripleStore.from_graph(store, hub_iri)
      iex> Enum.all?(hub_triples, fn t -> t.graph == hub_iri end)
      true
  """
  @spec from_graph(t(), String.t()) :: [Triple.t()]
  def from_graph(%__MODULE__{triples: triples}, graph_iri) do
    Enum.filter(triples, &(&1.graph == graph_iri))
  end

  @doc """
  Returns the count of triples in the store.

  ## Examples

      iex> {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = TripleStore.from_loaded_ontologies(loaded)
      iex> TripleStore.count(store) > 0
      true
  """
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{count: count}), do: count

  @doc """
  Returns all triples with the specified subject.

  Uses the subject index for O(log n) lookup performance.

  ## Task Coverage

  Task 1.2.3.1: Index by subject

  ## Parameters

  - `store` - The triple store
  - `subject` - Subject term to search for (e.g., `{:iri, "http://..."}` or `{:blank, "..."}`)

  ## Returns

  List of triples with matching subject, or empty list if none found.

  ## Examples

      iex> {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = TripleStore.from_loaded_ontologies(loaded)
      iex> module_iri = {:iri, "http://example.org/Module"}
      iex> triples = TripleStore.by_subject(store, module_iri)
      iex> Enum.all?(triples, fn t -> t.subject == module_iri end)
      true
  """
  @spec by_subject(t(), Triple.subject_value()) :: [Triple.t()]
  def by_subject(%__MODULE__{subject_index: index}, subject) do
    Map.get(index, subject, [])
  end

  @doc """
  Returns all triples with the specified predicate.

  Uses the predicate index for O(log n) lookup performance.
  This is particularly useful for finding all instances of a relationship
  type (e.g., all `rdf:type`, `rdfs:subClassOf` assertions).

  ## Task Coverage

  Task 1.2.3.2: Index by predicate

  ## Parameters

  - `store` - The triple store
  - `predicate` - Predicate term to search for (e.g., `{:iri, "http://..."}`)

  ## Returns

  List of triples with matching predicate, or empty list if none found.

  ## Examples

      iex> {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = TripleStore.from_loaded_ontologies(loaded)
      iex> rdf_type = {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"}
      iex> triples = TripleStore.by_predicate(store, rdf_type)
      iex> Enum.all?(triples, fn t -> t.predicate == rdf_type end)
      true
  """
  @spec by_predicate(t(), Triple.predicate_value()) :: [Triple.t()]
  def by_predicate(%__MODULE__{predicate_index: index}, predicate) do
    Map.get(index, predicate, [])
  end

  @doc """
  Returns all triples with the specified object.

  Uses the object index for O(log n) lookup performance.
  Useful for finding all entities of a certain type or pointing to a resource.

  ## Task Coverage

  Task 1.2.3.3: Index by object

  ## Parameters

  - `store` - The triple store
  - `object` - Object term to search for (e.g., `{:iri, "http://..."}`, `{:literal, ...}`, or `{:blank, "..."}`)

  ## Returns

  List of triples with matching object, or empty list if none found.

  ## Examples

      iex> {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      iex> store = TripleStore.from_loaded_ontologies(loaded)
      iex> owl_class = {:iri, "http://www.w3.org/2002/07/owl#Class"}
      iex> triples = TripleStore.by_object(store, owl_class)
      iex> Enum.all?(triples, fn t -> t.object == owl_class end)
      true
  """
  @spec by_object(t(), Triple.object_value()) :: [Triple.t()]
  def by_object(%__MODULE__{object_index: index}, object) do
    Map.get(index, object, [])
  end

  # Private functions

  # Extract all triples from all named graphs in the dataset
  # Task 1.2.1.1: Parse (subject, predicate, object) triples
  defp extract_all_triples(dataset) do
    dataset
    |> RDF.Dataset.graph_names()
    |> Enum.flat_map(fn graph_name ->
      graph = RDF.Dataset.graph(dataset, graph_name)
      graph_iri = graph_name_to_string(graph_name)

      graph
      |> RDF.Graph.triples()
      |> Enum.map(&Triple.from_rdf_triple(&1, graph_iri))
    end)
  end

  # Convert graph name to string IRI for provenance tracking
  defp graph_name_to_string(%RDF.IRI{} = iri), do: to_string(iri)
  defp graph_name_to_string(other), do: to_string(other)

  # Build all three indexes from triple list (Task 1.2.3)
  @spec build_indexes([Triple.t()]) :: {
          subject_index :: %{Triple.subject_value() => [Triple.t()]},
          predicate_index :: %{Triple.predicate_value() => [Triple.t()]},
          object_index :: %{Triple.object_value() => [Triple.t()]}
        }
  defp build_indexes(triples) do
    subject_index = build_subject_index(triples)
    predicate_index = build_predicate_index(triples)
    object_index = build_object_index(triples)
    {subject_index, predicate_index, object_index}
  end

  # Task 1.2.3.1: Index by subject
  # Groups all triples by their subject value for efficient lookup
  defp build_subject_index(triples) do
    Enum.group_by(triples, & &1.subject)
  end

  # Task 1.2.3.2: Index by predicate
  # Groups all triples by their predicate value for efficient lookup
  defp build_predicate_index(triples) do
    Enum.group_by(triples, & &1.predicate)
  end

  # Task 1.2.3.3: Index by object
  # Groups all triples by their object value for efficient lookup
  defp build_object_index(triples) do
    Enum.group_by(triples, & &1.object)
  end
end
