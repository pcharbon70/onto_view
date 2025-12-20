defmodule OntoView.Ontology.Entity.Helpers do
  @moduledoc """
  Shared helper functions for OWL entity extraction.

  This module provides common functionality used across all entity extraction
  modules (Class, ObjectProperty, DataProperty, Individual) to reduce code
  duplication and ensure consistent behavior.

  ## Functions

  - `extract_domain/2` - Extract rdfs:domain declarations for a property
  - `extract_range/2` - Extract rdfs:range declarations for a property
  - `validate_iri/1` - Validate IRI format and length
  - `valid_iri?/1` - Check if an IRI is valid
  - `apply_limit/2` - Apply optional limit to enumerable
  - `filter_by_field/3` - Filter entities by a field value
  - `group_by_field/2` - Group entities by a field value

  ## IRI Validation

  IRIs are validated for:
  - Maximum length (8192 bytes) to prevent DoS attacks
  - Binary format (must be a string)

  ## Usage

      iex> Helpers.valid_iri?("http://example.org/Person")
      true

      iex> Helpers.validate_iri(String.duplicate("a", 10000))
      {:error, {:iri_too_long, length: 10000, max: 8192}}

  Part of Task 1.3.100 — Section 1.3 Review Improvements
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.TripleStore.Triple
  alias OntoView.Ontology.Namespaces

  # Maximum IRI length in bytes (security: prevent DoS with malformed input)
  @max_iri_length 8192

  # ==========================================================================
  # IRI Validation
  # ==========================================================================

  @doc """
  Returns the maximum allowed IRI length in bytes.

  ## Returns

  The maximum IRI length (8192 bytes).
  """
  @spec max_iri_length() :: pos_integer()
  def max_iri_length, do: @max_iri_length

  @doc """
  Validates an IRI for format and length constraints.

  ## Parameters

  - `iri` - The IRI string to validate

  ## Returns

  - `:ok` if the IRI is valid
  - `{:error, reason}` if validation fails

  ## Error Reasons

  - `{:iri_too_long, length: integer, max: integer}` - IRI exceeds maximum length
  - `:invalid_iri_format` - IRI is not a binary string

  ## Examples

      iex> Helpers.validate_iri("http://example.org/Person")
      :ok

      iex> Helpers.validate_iri(String.duplicate("a", 10000))
      {:error, {:iri_too_long, length: 10000, max: 8192}}

      iex> Helpers.validate_iri(123)
      {:error, :invalid_iri_format}
  """
  @spec validate_iri(term()) :: :ok | {:error, term()}
  def validate_iri(iri) when is_binary(iri) do
    length = byte_size(iri)

    if length > @max_iri_length do
      {:error, {:iri_too_long, length: length, max: @max_iri_length}}
    else
      :ok
    end
  end

  def validate_iri(_iri), do: {:error, :invalid_iri_format}

  @doc """
  Checks if an IRI is valid.

  ## Parameters

  - `iri` - The IRI to check

  ## Returns

  `true` if the IRI is valid, `false` otherwise.

  ## Examples

      iex> Helpers.valid_iri?("http://example.org/Person")
      true

      iex> Helpers.valid_iri?(123)
      false
  """
  @spec valid_iri?(term()) :: boolean()
  def valid_iri?(iri), do: validate_iri(iri) == :ok

  # ==========================================================================
  # Domain and Range Extraction
  # ==========================================================================

  @doc """
  Extracts all rdfs:domain declarations for a property.

  Scans the triple store for all triples where the property is the subject
  and rdfs:domain is the predicate, returning the object IRIs.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `property_iri` - The IRI of the property to extract domains for

  ## Returns

  A list of domain class IRI strings.

  ## Examples

      iex> domains = Helpers.extract_domain(store, "http://example.org/worksFor")
      ["http://example.org/Person"]
  """
  @spec extract_domain(TripleStore.t(), String.t()) :: [String.t()]
  def extract_domain(%TripleStore{} = store, property_iri) when is_binary(property_iri) do
    property_subject = {:iri, property_iri}
    rdfs_domain = Namespaces.rdfs_domain()

    store
    |> TripleStore.by_subject(property_subject)
    |> Enum.filter(&(&1.predicate == rdfs_domain))
    |> Enum.filter(&match?({:iri, _}, &1.object))
    |> Enum.map(fn %Triple{object: {:iri, iri}} -> iri end)
  end

  @doc """
  Extracts all rdfs:range declarations for a property.

  Scans the triple store for all triples where the property is the subject
  and rdfs:range is the predicate, returning the object IRIs.

  For object properties, ranges are typically class IRIs.
  For data properties, ranges are typically XSD datatype IRIs.

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples
  - `property_iri` - The IRI of the property to extract ranges for

  ## Returns

  A list of range IRI strings (classes or datatypes).

  ## Examples

      iex> ranges = Helpers.extract_range(store, "http://example.org/hasName")
      ["http://www.w3.org/2001/XMLSchema#string"]
  """
  @spec extract_range(TripleStore.t(), String.t()) :: [String.t()]
  def extract_range(%TripleStore{} = store, property_iri) when is_binary(property_iri) do
    property_subject = {:iri, property_iri}
    rdfs_range = Namespaces.rdfs_range()

    store
    |> TripleStore.by_subject(property_subject)
    |> Enum.filter(&(&1.predicate == rdfs_range))
    |> Enum.filter(&match?({:iri, _}, &1.object))
    |> Enum.map(fn %Triple{object: {:iri, iri}} -> iri end)
  end

  # ==========================================================================
  # Limit Application
  # ==========================================================================

  @doc """
  Applies an optional limit to an enumerable.

  Used to implement the `:limit` option in entity extraction functions.

  ## Parameters

  - `enumerable` - The enumerable to limit
  - `limit` - Either a positive integer or `:infinity`

  ## Returns

  The enumerable, potentially truncated to the specified limit.

  ## Examples

      iex> Helpers.apply_limit([1, 2, 3, 4, 5], 3)
      [1, 2, 3]

      iex> Helpers.apply_limit([1, 2, 3], :infinity)
      [1, 2, 3]
  """
  @spec apply_limit(Enumerable.t(), pos_integer() | :infinity) :: list()
  def apply_limit(enumerable, :infinity), do: Enum.to_list(enumerable)

  def apply_limit(enumerable, limit) when is_integer(limit) and limit > 0 do
    Enum.take(enumerable, limit)
  end

  # ==========================================================================
  # Entity Filtering and Grouping
  # ==========================================================================

  @doc """
  Filters a list of entities by checking if a field value is in a list field.

  Useful for filtering properties by domain/range or individuals by class.

  ## Parameters

  - `entities` - List of entity structs
  - `field` - The field name (atom) containing a list
  - `value` - The value to check for membership

  ## Returns

  A filtered list of entities where `value in entity.field`.

  ## Examples

      iex> Helpers.filter_by_membership(properties, :domain, "http://example.org/Person")
      [%ObjectProperty{domain: ["http://example.org/Person"], ...}]
  """
  @spec filter_by_membership(list(struct()), atom(), term()) :: list(struct())
  def filter_by_membership(entities, field, value) when is_list(entities) and is_atom(field) do
    Enum.filter(entities, fn entity ->
      value in Map.get(entity, field, [])
    end)
  end

  @doc """
  Groups a list of entities by a field value.

  Useful for organizing entities by source graph or other attributes.

  ## Parameters

  - `entities` - List of entity structs
  - `field` - The field name (atom) to group by

  ## Returns

  A map where keys are field values and values are lists of entities.

  ## Examples

      iex> Helpers.group_by_field(classes, :source_graph)
      %{"http://example.org#" => [%Class{...}]}
  """
  @spec group_by_field(list(struct()), atom()) :: %{term() => list(struct())}
  def group_by_field(entities, field) when is_list(entities) and is_atom(field) do
    Enum.group_by(entities, &Map.get(&1, field))
  end

  # ==========================================================================
  # Error Tuple Construction
  # ==========================================================================

  @doc """
  Constructs a context-rich not_found error tuple.

  ## Parameters

  - `iri` - The IRI that was not found
  - `entity_type` - The type of entity (e.g., :class, :object_property)

  ## Returns

  An error tuple with context information.

  ## Examples

      iex> Helpers.not_found_error("http://example.org/Missing", :class)
      {:error, {:not_found, iri: "http://example.org/Missing", entity_type: :class}}
  """
  @spec not_found_error(String.t(), atom()) :: {:error, {:not_found, keyword()}}
  def not_found_error(iri, entity_type) when is_binary(iri) and is_atom(entity_type) do
    {:error, {:not_found, iri: iri, entity_type: entity_type}}
  end
end
