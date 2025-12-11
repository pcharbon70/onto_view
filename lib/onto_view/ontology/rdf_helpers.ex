defmodule OntoView.Ontology.RdfHelpers do
  @moduledoc """
  Helper functions for working with RDF data structures.

  This module provides utility functions to simplify common RDF operations
  and eliminate code duplication across the ontology loading modules.
  """

  @doc """
  Checks if an RDF description has a specific type.

  ## Parameters

  - `description` - An RDF.Description struct
  - `type_iri` - The type IRI to check for (as RDF.IRI or string)

  ## Examples

      iex> alias OntoView.Ontology.RdfHelpers
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> |> RDF.Description.add(RDF.type(), RDF.iri("http://www.w3.org/2002/07/owl#Ontology"))
      iex> RdfHelpers.has_type?(description, RDF.iri("http://www.w3.org/2002/07/owl#Ontology"))
      true

      iex> alias OntoView.Ontology.RdfHelpers
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> |> RDF.Description.add(RDF.type(), RDF.iri("http://www.w3.org/2002/07/owl#Class"))
      iex> RdfHelpers.has_type?(description, RDF.iri("http://www.w3.org/2002/07/owl#Ontology"))
      false
  """
  @spec has_type?(RDF.Description.t(), RDF.IRI.t() | String.t()) :: boolean()
  def has_type?(description, type_iri) do
    type_iri in get_types(description)
  end

  @doc """
  Gets all rdf:type values for an RDF description.

  Returns a list of type IRIs, always as a list even if there's only one type.
  Returns an empty list if there are no types.

  ## Examples

      iex> alias OntoView.Ontology.RdfHelpers
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> |> RDF.Description.add(RDF.type(), RDF.iri("http://www.w3.org/2002/07/owl#Class"))
      iex> |> RDF.Description.add(RDF.type(), RDF.iri("http://www.w3.org/2002/07/owl#Thing"))
      iex> types = RdfHelpers.get_types(description)
      iex> length(types)
      2
  """
  @spec get_types(RDF.Description.t()) :: [RDF.IRI.t()]
  def get_types(description) do
    description
    |> RDF.Description.get(RDF.type(), [])
    |> List.wrap()
  end

  @doc """
  Gets a single value for a property, or a default if not present.

  If the property has multiple values, returns the first one.
  If the property has no values, returns the default.

  ## Parameters

  - `description` - An RDF.Description struct
  - `property` - The property IRI
  - `default` - The default value if property is not present (default: nil)

  ## Examples

      iex> alias OntoView.Ontology.RdfHelpers
      iex> rdfs_label = RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> |> RDF.Description.add(rdfs_label, "Test Label")
      iex> RdfHelpers.get_single_value(description, rdfs_label)
      "Test Label"

      iex> alias OntoView.Ontology.RdfHelpers
      iex> rdfs_label = RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> RdfHelpers.get_single_value(description, rdfs_label, "default")
      "default"
  """
  @spec get_single_value(RDF.Description.t(), RDF.IRI.t(), any()) :: any()
  def get_single_value(description, property, default \\ nil) do
    case RDF.Description.get(description, property) do
      nil -> default
      [] -> default
      [first | _rest] -> first
      single_value -> single_value
    end
  end

  @doc """
  Gets all values for a property as a list.

  Always returns a list, even if there's only one value or no values.

  ## Examples

      iex> alias OntoView.Ontology.RdfHelpers
      iex> rdfs_label = RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> |> RDF.Description.add(rdfs_label, "Label 1")
      iex> |> RDF.Description.add(rdfs_label, "Label 2")
      iex> labels = RdfHelpers.get_values(description, rdfs_label)
      iex> length(labels)
      2

      iex> alias OntoView.Ontology.RdfHelpers
      iex> rdfs_label = RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> RdfHelpers.get_values(description, rdfs_label)
      []
  """
  @spec get_values(RDF.Description.t(), RDF.IRI.t()) :: [any()]
  def get_values(description, property) do
    description
    |> RDF.Description.get(property, [])
    |> List.wrap()
  end

  @doc """
  Finds the first description in a graph that has a specific type.

  Returns `{:ok, description}` if found, or `{:error, :not_found}` if no
  description with that type exists.

  ## Examples

      iex> alias OntoView.Ontology.RdfHelpers
      iex> graph = RDF.Graph.new()
      iex> |> RDF.Graph.add(RDF.iri("http://example.org/ont"), RDF.type(), RDF.iri("http://www.w3.org/2002/07/owl#Ontology"))
      iex> {:ok, desc} = RdfHelpers.find_by_type(graph, RDF.iri("http://www.w3.org/2002/07/owl#Ontology"))
      iex> desc.subject == RDF.iri("http://example.org/ont")
      true
  """
  @spec find_by_type(RDF.Graph.t(), RDF.IRI.t()) :: {:ok, RDF.Description.t()} | {:error, :not_found}
  def find_by_type(graph, type_iri) do
    result =
      graph
      |> RDF.Graph.descriptions()
      |> Enum.find(&has_type?(&1, type_iri))

    case result do
      nil -> {:error, :not_found}
      description -> {:ok, description}
    end
  end

  @doc """
  Extracts the IRI from an RDF description's subject.

  Returns the IRI as a string if the subject is an IRI, or nil for blank nodes.

  ## Examples

      iex> alias OntoView.Ontology.RdfHelpers
      iex> description = RDF.Description.new(RDF.iri("http://example.org/thing"))
      iex> RdfHelpers.extract_iri(description)
      "http://example.org/thing"

      iex> alias OntoView.Ontology.RdfHelpers
      iex> description = RDF.Description.new(RDF.bnode("b1"))
      iex> RdfHelpers.extract_iri(description)
      nil
  """
  @spec extract_iri(RDF.Description.t()) :: String.t() | nil
  def extract_iri(description) do
    case description.subject do
      %RDF.IRI{} = iri -> to_string(iri)
      %RDF.BlankNode{} -> nil
      other -> to_string(other)
    end
  end
end
