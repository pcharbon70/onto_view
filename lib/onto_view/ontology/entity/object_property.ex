defmodule OntoView.Ontology.Entity.ObjectProperty do
  @moduledoc """
  Represents an OWL object property extracted from the canonical triple store.

  This module defines the OWL object property structure and provides extraction
  functions to identify all object properties declared in loaded ontologies,
  including their domain and range declarations.

  ## Task Coverage

  - Task 1.3.2.1: Detect `owl:ObjectProperty`
  - Task 1.3.2.2: Register domain placeholders
  - Task 1.3.2.3: Register range placeholders

  ## Object Property Detection

  An entity is considered an OWL object property if it appears as the subject
  of a triple with:
  - `rdf:type owl:ObjectProperty`

  ## Domain and Range

  Object properties may have:
  - `rdfs:domain` - The class(es) that can be subjects of this property
  - `rdfs:range` - The class(es) that can be objects of this property

  These are extracted as "placeholders" (IRIs) that can be resolved to
  Class entities in a separate step if needed.

  ## Provenance Tracking

  Each extracted property maintains its ontology-of-origin, enabling
  per-ontology filtering in the UI and multi-set documentation.

  ## Usage Examples

      # Load ontology and create triple store
      {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("ontology.ttl")
      store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)

      # Extract all object properties
      properties = ObjectProperty.extract_all(store)
      # => [%ObjectProperty{iri: "http://example.org/knows", domain: [...], ...}]

      # Extract with limit
      first_5 = ObjectProperty.extract_all(store, limit: 5)

      # Find properties with a specific domain
      person_props = ObjectProperty.with_domain(store, "http://example.org/Person")

      # Find properties with a specific range
      org_props = ObjectProperty.with_range(store, "http://example.org/Organization")

  Part of Task 1.3.2 — Object Property Extraction
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.TripleStore.Triple
  alias OntoView.Ontology.Namespaces
  alias OntoView.Ontology.Entity.Helpers

  @typedoc """
  Represents an OWL object property entity.

  ## Fields

  - `iri` - The full IRI of the property
  - `source_graph` - The ontology graph IRI where the property was declared
  - `domain` - List of domain class IRIs (may be empty if not declared)
  - `range` - List of range class IRIs (may be empty if not declared)
  """
  @type t :: %__MODULE__{
          iri: String.t(),
          source_graph: String.t(),
          domain: [String.t()],
          range: [String.t()]
        }

  defstruct [:iri, :source_graph, domain: [], range: []]

  @doc """
  Extracts all OWL object properties from a triple store.

  Scans the triple store for all `rdf:type owl:ObjectProperty` assertions,
  extracting the subject IRI, provenance information, and any domain/range
  declarations.

  ## Task Coverage

  - Task 1.3.2.1: Detect `owl:ObjectProperty`
  - Task 1.3.2.2: Register domain placeholders
  - Task 1.3.2.3: Register range placeholders

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `opts` - Optional keyword list:
    - `:limit` - Maximum number of properties to return (default: `:infinity`)

  ## Returns

  A list of `ObjectProperty.t()` structs representing all detected object properties.
  Properties are deduplicated by IRI - if the same property is declared in multiple
  ontologies, only the first occurrence is returned (based on triple order).

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> props = ObjectProperty.extract_all(store)
      iex> length(props) >= 2
      true
      iex> Enum.any?(props, fn p -> String.ends_with?(p.iri, "worksFor") end)
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
  Returns a stream of all OWL object properties from a triple store.

  This is useful for memory-efficient processing of large ontologies,
  as properties are extracted lazily.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A `Stream` of `ObjectProperty.t()` structs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> stream = ObjectProperty.extract_all_stream(store)
      iex> is_function(stream, 2) or is_struct(stream, Stream)
      true
  """
  @spec extract_all_stream(TripleStore.t()) :: Enumerable.t()
  def extract_all_stream(%TripleStore{} = store) do
    rdf_type = Namespaces.rdf_type()
    owl_object_property = Namespaces.owl_object_property()

    # Task 1.3.2.1: Detect owl:ObjectProperty by finding rdf:type assertions
    store
    |> TripleStore.by_predicate(rdf_type)
    |> Stream.filter(&(&1.object == owl_object_property))
    |> Stream.filter(&match?({:iri, _}, &1.subject))
    |> Stream.map(fn %Triple{subject: {:iri, iri}, graph: graph} ->
      # Task 1.3.2.2 & 1.3.2.3: Extract domain and range using shared helpers
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
  Extracts OWL object properties from a triple store, returning a map keyed by IRI.

  This is useful for O(1) lookups when checking if an IRI is an object property.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A map where keys are property IRIs (strings) and values are `ObjectProperty.t()` structs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> prop_map = ObjectProperty.extract_all_as_map(store)
      iex> is_map(prop_map)
      true
      iex> Map.has_key?(prop_map, "http://example.org/entities#worksFor")
      true
  """
  @spec extract_all_as_map(TripleStore.t()) :: %{String.t() => t()}
  def extract_all_as_map(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Map.new(&{&1.iri, &1})
  end

  @doc """
  Extracts object properties declared in a specific ontology graph.

  Filters extraction to only include properties whose declaration triple
  originated from the specified graph.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `graph_iri` - The IRI of the ontology graph to filter by

  ## Returns

  A list of `ObjectProperty.t()` structs from the specified graph.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> graph_iri = "http://example.org/entities#"
      iex> props = ObjectProperty.extract_from_graph(store, graph_iri)
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
  Counts the total number of object properties in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  The count of unique object properties.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> ObjectProperty.count(store) >= 2
      true
  """
  @spec count(TripleStore.t()) :: non_neg_integer()
  def count(%TripleStore{} = store) do
    store |> extract_all() |> length()
  end

  @doc """
  Checks if a given IRI is an object property in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI to check (as a string)

  ## Returns

  `true` if the IRI is declared as an object property, `false` otherwise.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> ObjectProperty.is_object_property?(store, "http://example.org/entities#worksFor")
      true
      iex> ObjectProperty.is_object_property?(store, "http://example.org/entities#Person")
      false
  """
  @spec is_object_property?(TripleStore.t(), String.t()) :: boolean()
  def is_object_property?(%TripleStore{} = store, iri) when is_binary(iri) do
    store
    |> extract_all_as_map()
    |> Map.has_key?(iri)
  end

  @doc """
  Gets an object property by its IRI.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `iri` - The IRI of the property to retrieve (as a string)

  ## Returns

  - `{:ok, property}` if found
  - `{:error, {:not_found, iri: iri, entity_type: :object_property}}` otherwise

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> {:ok, prop} = ObjectProperty.get(store, "http://example.org/entities#worksFor")
      iex> prop.domain
      ["http://example.org/entities#Employee"]
  """
  @spec get(TripleStore.t(), String.t()) :: {:ok, t()} | {:error, {:not_found, keyword()}}
  def get(%TripleStore{} = store, iri) when is_binary(iri) do
    case extract_all_as_map(store) |> Map.get(iri) do
      nil -> Helpers.not_found_error(iri, :object_property)
      property -> {:ok, property}
    end
  end

  @doc """
  Lists all unique object property IRIs in the triple store.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A list of property IRI strings.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> iris = ObjectProperty.list_iris(store)
      iex> "http://example.org/entities#worksFor" in iris
      true
  """
  @spec list_iris(TripleStore.t()) :: [String.t()]
  def list_iris(%TripleStore{} = store) do
    store
    |> extract_all()
    |> Enum.map(& &1.iri)
  end

  @doc """
  Finds all object properties with a specific domain class.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `domain_iri` - The IRI of the domain class to filter by

  ## Returns

  A list of `ObjectProperty.t()` structs that have the specified domain.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> props = ObjectProperty.with_domain(store, "http://example.org/entities#Employee")
      iex> Enum.any?(props, fn p -> String.ends_with?(p.iri, "worksFor") end)
      true
  """
  @spec with_domain(TripleStore.t(), String.t()) :: [t()]
  def with_domain(%TripleStore{} = store, domain_iri) when is_binary(domain_iri) do
    store
    |> extract_all()
    |> Helpers.filter_by_membership(:domain, domain_iri)
  end

  @doc """
  Finds all object properties with a specific range class.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `range_iri` - The IRI of the range class to filter by

  ## Returns

  A list of `ObjectProperty.t()` structs that have the specified range.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> props = ObjectProperty.with_range(store, "http://example.org/entities#Organization")
      iex> Enum.any?(props, fn p -> String.ends_with?(p.iri, "worksFor") end)
      true
  """
  @spec with_range(TripleStore.t(), String.t()) :: [t()]
  def with_range(%TripleStore{} = store, range_iri) when is_binary(range_iri) do
    store
    |> extract_all()
    |> Helpers.filter_by_membership(:range, range_iri)
  end
end
