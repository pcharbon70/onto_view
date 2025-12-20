defmodule OntoView.Ontology.Hierarchy.ClassHierarchy do
  @moduledoc """
  Builds and queries the OWL class hierarchy based on rdfs:subClassOf relationships.

  This module extracts parent → child relationships from the triple store and
  provides efficient queries for hierarchical class exploration.

  ## Task Coverage

  - Task 1.4.1.1: Build subclass adjacency list
  - Task 1.4.1.2: Normalize `owl:Thing` as root

  ## Hierarchy Construction

  The hierarchy is built by:
  1. Extracting all `rdfs:subClassOf` triples from the store
  2. Building a parent → children adjacency list
  3. Identifying "orphan" classes (declared but no superclass)
  4. Normalizing orphans as children of `owl:Thing`

  ## Usage Examples

      # Load ontology and create triple store
      {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("ontology.ttl")
      store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)

      # Build the hierarchy
      hierarchy = ClassHierarchy.build(store)

      # Get direct children of a class
      children = ClassHierarchy.children(hierarchy, "http://example.org/Animal")
      # => ["http://example.org/Mammal", "http://example.org/Reptile"]

      # Get root classes (direct children of owl:Thing)
      roots = ClassHierarchy.root_classes(hierarchy)
      # => ["http://example.org/Animal", "http://example.org/Event"]

      # Check if a class has children
      ClassHierarchy.has_children?(hierarchy, "http://example.org/Animal")
      # => true

      # Get leaf classes
      leaves = ClassHierarchy.leaf_classes(hierarchy)

  Part of Task 1.4.1 — Parent → Child Graph
  """

  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.Entity.Class
  alias OntoView.Ontology.Namespaces

  @typedoc """
  Represents a class hierarchy.

  ## Fields

  - `parent_to_children` - Map from parent IRI to list of child IRIs
  - `all_class_iris` - Set of all class IRIs in the ontology
  - `owl_thing_iri` - The owl:Thing IRI string
  """
  @type t :: %__MODULE__{
          parent_to_children: %{String.t() => [String.t()]},
          all_class_iris: MapSet.t(String.t()),
          owl_thing_iri: String.t()
        }

  defstruct parent_to_children: %{},
            all_class_iris: MapSet.new(),
            owl_thing_iri: "http://www.w3.org/2002/07/owl#Thing"

  @doc """
  Builds a class hierarchy from a triple store.

  Extracts all `rdfs:subClassOf` relationships and constructs a parent → children
  adjacency list. Classes without an explicit superclass are normalized as children
  of `owl:Thing`.

  ## Task Coverage

  - Task 1.4.1.1: Build subclass adjacency list
  - Task 1.4.1.2: Normalize `owl:Thing` as root

  ## Parameters

  - `store` - A `TripleStore.t()` containing normalized triples

  ## Returns

  A `ClassHierarchy.t()` struct with the parent → children mapping.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> is_map(hierarchy.parent_to_children)
      true
  """
  @spec build(TripleStore.t()) :: t()
  def build(%TripleStore{} = store) do
    rdfs_sub_class_of = Namespaces.rdfs_sub_class_of()
    {:iri, owl_thing_iri} = Namespaces.owl_thing()

    # Get all declared class IRIs
    all_class_iris =
      store
      |> Class.extract_all()
      |> Enum.map(& &1.iri)
      |> MapSet.new()

    # Task 1.4.1.1: Build subclass adjacency list
    # Extract all rdfs:subClassOf triples: (child, rdfs:subClassOf, parent)
    subclass_triples = TripleStore.by_predicate(store, rdfs_sub_class_of)

    # Build parent → children map
    parent_to_children = build_adjacency_list(subclass_triples)

    # Find all classes that appear as children (have explicit parents)
    classes_with_parents =
      subclass_triples
      |> Enum.filter(&match?({:iri, _}, &1.subject))
      |> Enum.map(fn triple -> elem(triple.subject, 1) end)
      |> MapSet.new()

    # Task 1.4.1.2: Normalize owl:Thing as root
    # Find orphan classes: declared but no rdfs:subClassOf relationship
    orphan_classes =
      all_class_iris
      |> MapSet.difference(classes_with_parents)
      |> MapSet.delete(owl_thing_iri)
      |> MapSet.to_list()

    # Add orphans as children of owl:Thing
    parent_to_children_with_roots =
      if Enum.empty?(orphan_classes) do
        parent_to_children
      else
        Map.update(
          parent_to_children,
          owl_thing_iri,
          orphan_classes,
          &(orphan_classes ++ &1)
        )
      end

    %__MODULE__{
      parent_to_children: parent_to_children_with_roots,
      all_class_iris: all_class_iris,
      owl_thing_iri: owl_thing_iri
    }
  end

  @doc """
  Gets the direct children of a class.

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct
  - `parent_iri` - The IRI of the parent class

  ## Returns

  A list of child class IRIs (may be empty if no children).

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> children = ClassHierarchy.children(hierarchy, "http://example.org/hierarchy#Mammal")
      iex> "http://example.org/hierarchy#Dog" in children
      true
  """
  @spec children(t(), String.t()) :: [String.t()]
  def children(%__MODULE__{parent_to_children: map}, parent_iri) do
    Map.get(map, parent_iri, [])
  end

  @doc """
  Gets all root classes (direct children of owl:Thing).

  Root classes are those that either:
  - Have no explicit rdfs:subClassOf relationship, or
  - Have rdfs:subClassOf owl:Thing

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct

  ## Returns

  A list of root class IRIs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> roots = ClassHierarchy.root_classes(hierarchy)
      iex> is_list(roots)
      true
  """
  @spec root_classes(t()) :: [String.t()]
  def root_classes(%__MODULE__{parent_to_children: map, owl_thing_iri: owl_thing}) do
    Map.get(map, owl_thing, [])
  end

  @doc """
  Checks if a class has any children.

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct
  - `iri` - The IRI of the class to check

  ## Returns

  `true` if the class has at least one child, `false` otherwise.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> ClassHierarchy.has_children?(hierarchy, "http://example.org/hierarchy#Animal")
      true
  """
  @spec has_children?(t(), String.t()) :: boolean()
  def has_children?(%__MODULE__{parent_to_children: map}, iri) do
    case Map.get(map, iri) do
      nil -> false
      [] -> false
      _ -> true
    end
  end

  @doc """
  Gets all leaf classes (classes with no children).

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct

  ## Returns

  A list of leaf class IRIs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> leaves = ClassHierarchy.leaf_classes(hierarchy)
      iex> "http://example.org/hierarchy#Dog" in leaves
      true
  """
  @spec leaf_classes(t()) :: [String.t()]
  def leaf_classes(%__MODULE__{all_class_iris: all_classes, parent_to_children: map}) do
    # Get all classes that appear as parents
    parents = Map.keys(map) |> MapSet.new()

    # Leaf classes are those that are not parents
    all_classes
    |> MapSet.difference(parents)
    |> MapSet.to_list()
  end

  @doc """
  Counts the number of direct children of a class.

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct
  - `parent_iri` - The IRI of the parent class

  ## Returns

  The count of direct children.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> ClassHierarchy.child_count(hierarchy, "http://example.org/hierarchy#Vehicle")
      6
  """
  @spec child_count(t(), String.t()) :: non_neg_integer()
  def child_count(%__MODULE__{} = hierarchy, parent_iri) do
    hierarchy |> children(parent_iri) |> length()
  end

  @doc """
  Lists all parents in the hierarchy (classes that have at least one child).

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct

  ## Returns

  A list of parent class IRIs.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> parents = ClassHierarchy.parents(hierarchy)
      iex> is_list(parents)
      true
  """
  @spec parents(t()) :: [String.t()]
  def parents(%__MODULE__{parent_to_children: map}) do
    Map.keys(map)
  end

  @doc """
  Counts the total number of classes in the hierarchy.

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct

  ## Returns

  The total count of classes.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> ClassHierarchy.class_count(hierarchy) >= 10
      true
  """
  @spec class_count(t()) :: non_neg_integer()
  def class_count(%__MODULE__{all_class_iris: all_classes}) do
    MapSet.size(all_classes)
  end

  @doc """
  Checks if an IRI is a known class in the hierarchy.

  ## Parameters

  - `hierarchy` - A `ClassHierarchy.t()` struct
  - `iri` - The IRI to check

  ## Returns

  `true` if the IRI is a known class, `false` otherwise.

  ## Examples

      iex> {:ok, loaded} = OntoView.Ontology.ImportResolver.load_with_imports("test/support/fixtures/ontologies/class_hierarchy.ttl")
      iex> store = OntoView.Ontology.TripleStore.from_loaded_ontologies(loaded)
      iex> hierarchy = ClassHierarchy.build(store)
      iex> ClassHierarchy.class?(hierarchy, "http://example.org/hierarchy#Animal")
      true
  """
  @spec class?(t(), String.t()) :: boolean()
  def class?(%__MODULE__{all_class_iris: all_classes}, iri) do
    MapSet.member?(all_classes, iri)
  end

  # Private functions

  # Build adjacency list from subclass triples
  # Triple format: (child, rdfs:subClassOf, parent)
  @spec build_adjacency_list([TripleStore.Triple.t()]) :: %{String.t() => [String.t()]}
  defp build_adjacency_list(subclass_triples) do
    subclass_triples
    |> Enum.filter(fn triple ->
      # Only include triples where both subject and object are IRIs
      match?({:iri, _}, triple.subject) and match?({:iri, _}, triple.object)
    end)
    |> Enum.reduce(%{}, fn triple, acc ->
      {:iri, child_iri} = triple.subject
      {:iri, parent_iri} = triple.object

      Map.update(acc, parent_iri, [child_iri], &[child_iri | &1])
    end)
  end
end
