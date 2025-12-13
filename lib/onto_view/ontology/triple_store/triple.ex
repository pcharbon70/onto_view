defmodule OntoView.Ontology.TripleStore.Triple do
  @moduledoc """
  Canonical representation of an RDF triple.

  This module defines the normalized triple structure used throughout
  the ontology system, independent of the underlying RDF.ex representation.

  Triples are extracted from RDF graphs and converted to a simple,
  queryable format that separates IRIs, literals, and blank nodes.

  ## Subtask Coverage

  - Task 1.2.1.1: Parse (subject, predicate, object) triples
  - Task 1.2.1.2: Normalize IRIs
  - Task 1.2.1.4: Separate literals from IRIs

  ## Triple Components

  - **Subject**: Can be an IRI or blank node
  - **Predicate**: Must be an IRI
  - **Object**: Can be an IRI, literal, or blank node

  ## Canonical Representation

  All RDF terms are converted to tagged tuples:

  - IRIs: `{:iri, "http://example.org/resource"}`
  - Blank nodes: `{:blank, "b1"}`
  - Literals: `{:literal, value, datatype, language}`

  This representation enables efficient pattern matching for OWL entity
  extraction (Section 1.3) while maintaining all semantic information.

  Part of Task 1.2.1 — RDF Triple Parsing
  """

  @type subject_value :: iri_value() | blank_node_id()
  @type predicate_value :: iri_value()
  @type object_value :: iri_value() | literal_value() | blank_node_id()

  @type iri_value :: {:iri, String.t()}
  @type blank_node_id :: {:blank, String.t()}
  @type literal_value ::
          {:literal, value :: term(), datatype :: String.t() | nil, language :: String.t() | nil}

  @type t :: %__MODULE__{
          subject: subject_value(),
          predicate: predicate_value(),
          object: object_value(),
          graph: String.t()
        }

  defstruct [:subject, :predicate, :object, :graph]

  @doc """
  Converts an RDF.ex triple to canonical format.

  Takes a 3-tuple of RDF terms and the source graph IRI, producing
  a normalized triple with all IRIs expanded and types distinguished.

  ## Subtask Coverage

  - Task 1.2.1.1: Parse (subject, predicate, object) triples
  - Task 1.2.1.2: Normalize IRIs
  - Task 1.2.1.4: Separate literals from IRIs

  ## Parameters

  - `rdf_triple` - 3-tuple of `{subject, predicate, object}` from RDF.ex
  - `graph_iri` - IRI of the named graph containing this triple (for provenance)

  ## Returns

  A `Triple.t()` struct with normalized values.

  ## Examples

      iex> subject = RDF.iri("http://example.org/Subject")
      iex> predicate = RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
      iex> object = RDF.iri("http://www.w3.org/2002/07/owl#Class")
      iex> triple = Triple.from_rdf_triple({subject, predicate, object}, "http://example.org/ontology#")
      iex> match?(%Triple{subject: {:iri, _}, predicate: {:iri, _}, object: {:iri, _}}, triple)
      true

      iex> subject = RDF.iri("http://example.org/Subject")
      iex> predicate = RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
      iex> object = RDF.literal("Test Label", language: "en")
      iex> triple = Triple.from_rdf_triple({subject, predicate, object}, "http://example.org/ontology#")
      iex> match?(%Triple{object: {:literal, "Test Label", _, "en"}}, triple)
      true
  """
  @spec from_rdf_triple({term(), term(), term()}, String.t()) :: t()
  def from_rdf_triple({subject, predicate, object}, graph_iri) do
    %__MODULE__{
      subject: normalize_subject(subject),
      predicate: normalize_predicate(predicate),
      object: normalize_object(object),
      graph: graph_iri
    }
  end

  # Private normalization functions

  # Task 1.2.1.2: Normalize IRIs
  # Subjects can be IRIs or blank nodes
  defp normalize_subject(%RDF.IRI{} = iri), do: {:iri, to_string(iri)}
  defp normalize_subject(%RDF.BlankNode{value: id}), do: {:blank, id}

  defp normalize_subject(other) do
    raise ArgumentError,
          "Subject must be IRI or BlankNode, got: #{inspect(other)}"
  end

  # Predicates must be IRIs
  defp normalize_predicate(%RDF.IRI{} = iri), do: {:iri, to_string(iri)}

  defp normalize_predicate(other) do
    raise ArgumentError,
          "Predicate must be IRI, got: #{inspect(other)}"
  end

  # Task 1.2.1.4: Separate literals from IRIs
  # Objects can be IRIs, blank nodes, or literals
  defp normalize_object(%RDF.IRI{} = iri), do: {:iri, to_string(iri)}
  defp normalize_object(%RDF.BlankNode{value: id}), do: {:blank, id}

  defp normalize_object(%RDF.Literal{} = literal) do
    {:literal, RDF.Literal.value(literal), extract_datatype(literal),
     RDF.Literal.language(literal)}
  end

  defp normalize_object(other) do
    raise ArgumentError,
          "Object must be IRI, BlankNode, or Literal, got: #{inspect(other)}"
  end

  # Extract datatype IRI from literal, converting to string
  defp extract_datatype(literal) do
    case RDF.Literal.datatype_id(literal) do
      nil -> nil
      iri -> to_string(iri)
    end
  end
end
