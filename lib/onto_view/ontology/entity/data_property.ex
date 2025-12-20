defmodule OntoView.Ontology.Entity.DataProperty do
  @moduledoc """
  Represents an OWL data property extracted from the canonical triple store.

  This module defines the OWL data property structure and provides extraction
  functions to identify all data properties declared in loaded ontologies,
  including their domain and datatype range declarations.

  ## Task Coverage

  - Task 1.3.3.1: Detect `owl:DatatypeProperty`
  - Task 1.3.3.2: Register datatype ranges

  ## Data Property Detection

  An entity is considered an OWL data property if it appears as the subject
  of a triple with:
  - `rdf:type owl:DatatypeProperty`

  ## Domain and Range

  Data properties may have:
  - `rdfs:domain` - The class(es) that can be subjects of this property
  - `rdfs:range` - The datatype(s) for values of this property (e.g., xsd:string, xsd:integer)

  Unlike object properties, data property ranges are typically XML Schema
  datatypes or custom datatypes, not OWL classes.

  ## Provenance Tracking

  Each extracted property maintains its ontology-of-origin, enabling
  per-ontology filtering in the UI and multi-set documentation.

  ## Usage Examples

      # Load ontology and create triple store
      {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("ontology.ttl")
      store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)

      # Extract all data properties
      properties = DataProperty.extract_all(store)
      # => [%DataProperty{iri: "http://example.org/hasName", range: ["xsd:string"], ...}]

      # Extract with limit
      first_5 = DataProperty.extract_all(store, limit: 5)

      # Find properties with a specific domain
      person_props = DataProperty.with_domain(store, "http://example.org/Person")

      # Find string properties
      string_props = DataProperty.with_range(store, "http://www.w3.org/2001/XMLSchema#string")

      # Group properties by datatype
      by_type = DataProperty.group_by_datatype(store)

  Part of Task 1.3.3 — Data Property Extraction
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.TripleStore.Triple
  alias OntoView.Ontology.Namespaces
  alias OntoView.Ontology.Entity.Helpers

  @typedoc """
  Represents an OWL data property entity.

  ## Fields

  - `iri` - The full IRI of the property
  - `source_graph` - The ontology graph IRI where the property was declared
  - `domain` - List of domain class IRIs (may be empty if not declared)
  - `range` - List of datatype IRIs (may be empty if not declared)
  """
  @type t :: %__MODULE__{
          iri: String.t(),
          source_graph: String.t(),
          domain: [String.t()],
          range: [String.t()]
        }

  defstruct [:iri, :source_graph, domain: [], range: []]

  @doc """
  Extracts all OWL data properties from a triple store.

  Scans the triple store for all `rdf:type owl:DatatypeProperty` assertions,
  extracting the subject IRI, provenance information, and any domain/range
  declarations.

  ## Task Coverage

  - Task 1.3.3.1: Detect `owl:DatatypeProperty`
  - Task 1.3.3.2: Register datatype ranges

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `opts` - Optional keyword list:
    - `:limit` - Maximum number of properties to return (default: `:infinity`)

  ## Returns

  A list of `DataProperty.t()` structs representing all detected data properties.
  Properties are deduplicated by IRI - if the same property is declared in multiple
  ontologies, only the first occurrence is returned (based on triple order).

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> props = DataProperty.extract_all(store)
      iex> length(props) >= 1
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
  Returns a stream of all OWL data properties from a triple store.

  This is useful for memory-efficient processing of large ontologies,
  as properties are extracted lazily.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A `Stream` of `DataProperty.t()` structs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> stream = DataProperty.extract_all_stream(store)
      iex> is_function(stream, 2) or is_struct(stream, Stream)
      true
  """
  @spec extract_all_stream(TripleStore.t()) :: Enumerable.t()
  def extract_all_stream(%TripleStore{} = store) do
    rdf_type = Namespaces.rdf_type()
    owl_datatype_property = Namespaces.owl_datatype_property()

    # Task 1.3.3.1: Detect owl:DatatypeProperty by finding rdf:type assertions
    store
    |> TripleStore.by_predicate(rdf_type)
    |> Stream.filter(&(&1.object == owl_datatype_property))
    |> Stream.filter(&match?({:iri, _}, &1.subject))
    |> Stream.map(fn %Triple{subject: {:iri, iri}, graph: graph} ->
      # Task 1.3.3.2: Extract domain and datatype range using shared helpers
      domains = Helpers.extract_domain(store, iri)
      ranges = Helpers.extract_range(store, iri)

      %__MODULE__{
        iri: iri,
        source_graph: graph,
        domain: domains,
        range: ranges
      }
    end)
    |> Stream.uniq_by(& &1.iri)
  end

  @doc """
  Extracts OWL data properties from a triple store, returning a map keyed by IRI.

  This is useful for O(1) lookups when checking if an IRI is a data property.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A map where keys are property IRIs (strings) and values are `DataProperty.t()` structs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> prop_map = DataProperty.extract_all_as_map(store)
      iex> is_map(prop_map)
      true
  """
  @spec extract_all_as_map(TripleStore.t()) :: %{String.t() => t()}
  def extract_all_as_map(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Map.new(&{&1.iri, &1})
  end

  @doc """
  Extracts data properties declared in a specific ontology graph.

  Filters extraction to only include properties whose declaration triple
  originated from the specified graph.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `graph_iri` - The IRI of the ontology graph to filter by

  ## Returns

  A list of `DataProperty.t()` structs from the specified graph.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> graph_iri = "http://example.org/dataprops#"
      iex> props = DataProperty.extract_from_graph(store, graph_iri)
      iex> Enum.all?(props, fn p -> p.source_graph == graph_iri end)
      true
  """
  @spec extract_from_graph(TripleStore.t(), String.t()) :: [t()]
  def extract_from_graph(%TripleStore{} = store, graph_iri) do
    store
    |> extract_all()
    |> Enum.filter(&(&1.source_graph == graph_iri))
  end

  @doc """
  Counts the total number of data properties in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  The count of unique data properties.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> DataProperty.count(store) >= 1
      true
  """
  @spec count(TripleStore.t()) :: non_neg_integer()
  def count(%TripleStore{} = store) do
    store |> extract_all() |> length()
  end

  @doc """
  Checks if a given IRI is a data property in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI to check (as a string)

  ## Returns

  `true` if the IRI is declared as a data property, `false` otherwise.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> DataProperty.is_data_property?(store, "http://example.org/dataprops#hasName")
      true
      iex> DataProperty.is_data_property?(store, "http://example.org/dataprops#NonExistent")
      false
  """
  @spec is_data_property?(TripleStore.t(), String.t()) :: boolean()
  def is_data_property?(%TripleStore{} = store, iri) when is_binary(iri) do
    store
    |> extract_all_as_map()
    |> Map.has_key?(iri)
  end

  @doc """
  Gets a data property by its IRI.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI of the property to retrieve (as a string)

  ## Returns

  - `{:ok, property}` if found
  - `{:error, {:not_found, iri: iri, entity_type: :data_property}}` otherwise

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> {:ok, prop} = DataProperty.get(store, "http://example.org/dataprops#hasName")
      iex> "http://www.w3.org/2001/XMLSchema#string" in prop.range
      true
  """
  @spec get(TripleStore.t(), String.t()) :: {:ok, t()} | {:error, {:not_found, keyword()}}
  def get(%TripleStore{} = store, iri) when is_binary(iri) do
    case extract_all_as_map(store) |> Map.get(iri) do
      nil -> Helpers.not_found_error(iri, :data_property)
      property -> {:ok, property}
    end
  end

  @doc """
  Lists all unique data property IRIs in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A list of property IRI strings.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> iris = DataProperty.list_iris(store)
      iex> "http://example.org/dataprops#hasName" in iris
      true
  """
  @spec list_iris(TripleStore.t()) :: [String.t()]
  def list_iris(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Enum.map(& &1.iri)
  end

  @doc """
  Finds all data properties with a specific domain class.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `domain_iri` - The IRI of the domain class to filter by

  ## Returns

  A list of `DataProperty.t()` structs that have the specified domain.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> props = DataProperty.with_domain(store, "http://example.org/dataprops#Person")
      iex> Enum.any?(props, fn p -> String.ends_with?(p.iri, "hasName") end)
      true
  """
  @spec with_domain(TripleStore.t(), String.t()) :: [t()]
  def with_domain(%TripleStore{} = store, domain_iri) when is_binary(domain_iri) do
    store
    |> extract_all()
    |> Helpers.filter_by_membership(:domain, domain_iri)
  end

  @doc """
  Finds all data properties with a specific datatype range.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `range_iri` - The IRI of the datatype to filter by

  ## Returns

  A list of `DataProperty.t()` structs that have the specified range.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> props = DataProperty.with_range(store, "http://www.w3.org/2001/XMLSchema#string")
      iex> Enum.any?(props, fn p -> String.ends_with?(p.iri, "hasName") end)
      true
  """
  @spec with_range(TripleStore.t(), String.t()) :: [t()]
  def with_range(%TripleStore{} = store, range_iri) when is_binary(range_iri) do
    store
    |> extract_all()
    |> Helpers.filter_by_membership(:range, range_iri)
  end

  @doc """
  Groups data properties by their datatype range.

  Useful for presenting properties organized by the type of data they accept.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A map where keys are datatype IRIs and values are lists of `DataProperty.t()` structs.
  Properties with no range declaration are grouped under the key `:untyped`.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> by_type = DataProperty.group_by_datatype(store)
      iex> is_map(by_type)
      true
  """
  @spec group_by_datatype(TripleStore.t()) :: %{(String.t() | :untyped) => [t()]}
  def group_by_datatype(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Enum.reduce(%{}, fn prop, acc ->
      case prop.range do
        [] ->
          Map.update(acc, :untyped, [prop], &[prop | &1])

        ranges ->
          Enum.reduce(ranges, acc, fn range, inner_acc ->
            Map.update(inner_acc, range, [prop], &[prop | &1])
          end)
      end
    end)
    |> Map.new(fn {k, v} -> {k, Enum.reverse(v)} end)
  end
end
