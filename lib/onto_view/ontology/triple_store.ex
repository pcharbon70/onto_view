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

  ## Query Interface

  The module provides basic query functions:
  - `all/1` - Retrieve all triples
  - `from_graph/2` - Filter triples by ontology graph
  - `count/1` - Count total triples

  More advanced indexing (by subject, predicate, object) will be added
  in Task 1.2.3 — Triple Indexing Engine.

  Part of Task 1.2.1 — RDF Triple Parsing
  """

  alias OntoView.Ontology.TripleStore.Triple
  alias OntoView.Ontology.ImportResolver.LoadedOntologies

  @type t :: %__MODULE__{
          triples: [Triple.t()],
          count: non_neg_integer(),
          ontologies: MapSet.t(String.t())
        }

  defstruct triples: [], count: 0, ontologies: MapSet.new()

  @doc """
  Builds a triple store from loaded ontologies.

  Extracts all triples from all named graphs in the dataset,
  converting them to canonical format with provenance tracking.

  ## Task Coverage

  Task 1.2.1.1: Parse (subject, predicate, object) triples

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
    triples = extract_all_triples(loaded.dataset)
    ontology_iris = MapSet.new(Map.keys(loaded.ontologies))

    %__MODULE__{
      triples: triples,
      count: length(triples),
      ontologies: ontology_iris
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
end
