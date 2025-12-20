defmodule OntoView.Ontology.Entity.ClassTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Entity.Class
  alias OntoView.Ontology.ImportResolver
  alias OntoView.Ontology.TripleStore

  @moduletag :entity_extraction

  # Task 1.3.1 — Class Extraction
  #
  # These tests validate OWL class extraction from the canonical triple store.
  # Tests verify detection of owl:Class and rdfs:Class declarations,
  # extraction of class IRIs, and proper provenance tracking.

  describe "Task 1.3.1.1 - Detect owl:Class" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "detects owl:Class declarations", %{store: store} do
      classes = Class.extract_all(store)

      # The fixture defines 5 owl:Class entities plus 1 rdfs:Class
      owl_classes = Enum.filter(classes, &(&1.type == :owl_class))
      assert length(owl_classes) >= 5

      # Verify specific classes are detected
      iris = Enum.map(owl_classes, & &1.iri)
      assert "http://example.org/entities#Person" in iris
      assert "http://example.org/entities#Organization" in iris
      assert "http://example.org/entities#Employee" in iris
      assert "http://example.org/entities#Manager" in iris
      assert "http://example.org/entities#Department" in iris
    end

    test "detects rdfs:Class declarations for compatibility", %{store: store} do
      classes = Class.extract_all(store)

      rdfs_classes = Enum.filter(classes, &(&1.type == :rdfs_class))
      assert length(rdfs_classes) >= 1

      iris = Enum.map(rdfs_classes, & &1.iri)
      assert "http://example.org/entities#LegacyClass" in iris
    end

    test "does not extract object properties as classes", %{store: store} do
      classes = Class.extract_all(store)
      iris = Enum.map(classes, & &1.iri)

      # Object properties should not be detected as classes
      refute "http://example.org/entities#worksFor" in iris
      refute "http://example.org/entities#manages" in iris
    end

    test "does not extract data properties as classes", %{store: store} do
      classes = Class.extract_all(store)
      iris = Enum.map(classes, & &1.iri)

      # Data properties should not be detected as classes
      refute "http://example.org/entities#hasName" in iris
      refute "http://example.org/entities#hasAge" in iris
    end

    test "does not extract individuals as classes", %{store: store} do
      classes = Class.extract_all(store)
      iris = Enum.map(classes, & &1.iri)

      # Named individuals should not be detected as classes
      refute "http://example.org/entities#JohnDoe" in iris
    end
  end

  describe "Task 1.3.1.2 - Extract class IRIs" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "extracts full IRIs for all classes", %{store: store} do
      classes = Class.extract_all(store)

      # All IRIs should be fully qualified (not prefixed)
      Enum.each(classes, fn class ->
        assert is_binary(class.iri)
        assert String.starts_with?(class.iri, "http://")
      end)
    end

    test "list_iris/1 returns only IRI strings", %{store: store} do
      iris = Class.list_iris(store)

      assert is_list(iris)
      assert length(iris) >= 6

      Enum.each(iris, fn iri ->
        assert is_binary(iri)
        assert String.starts_with?(iri, "http://")
      end)
    end

    test "deduplicates classes with same IRI", %{store: store} do
      classes = Class.extract_all(store)
      iris = Enum.map(classes, & &1.iri)

      # Each IRI should appear exactly once
      assert length(iris) == length(Enum.uniq(iris))
    end
  end

  describe "Task 1.3.1.3 - Attach ontology-of-origin metadata" do
    test "attaches source graph to single-ontology classes" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      classes = Class.extract_all(store)

      # All classes should have source_graph pointing to the ontology
      Enum.each(classes, fn class ->
        assert is_binary(class.source_graph)
        assert class.source_graph == "http://example.org/entities#"
      end)
    end

    test "attaches correct source graphs for multi-ontology imports" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes_with_imports.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      classes = Class.extract_all(store)

      # Classes from main ontology
      main_classes = Enum.filter(classes, &(&1.source_graph == "http://example.org/main#"))
      main_iris = Enum.map(main_classes, & &1.iri)
      assert "http://example.org/main#Project" in main_iris
      assert "http://example.org/main#Task" in main_iris
      assert "http://example.org/main#Team" in main_iris

      # Classes from imported ontology
      base_classes = Enum.filter(classes, &(&1.source_graph == "http://example.org/base#"))
      base_iris = Enum.map(base_classes, & &1.iri)
      assert "http://example.org/base#Thing" in base_iris
      assert "http://example.org/base#Agent" in base_iris
      assert "http://example.org/base#Location" in base_iris
    end

    test "extract_from_graph/2 filters by source ontology" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes_with_imports.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)

      # Only main ontology classes
      main_classes = Class.extract_from_graph(store, "http://example.org/main#")
      assert length(main_classes) == 3

      Enum.each(main_classes, fn class ->
        assert class.source_graph == "http://example.org/main#"
      end)

      # Only base ontology classes
      base_classes = Class.extract_from_graph(store, "http://example.org/base#")
      assert length(base_classes) == 3

      Enum.each(base_classes, fn class ->
        assert class.source_graph == "http://example.org/base#"
      end)
    end
  end

  describe "extract_all/1" do
    test "returns empty list for ontology with no classes" do
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/empty.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      classes = Class.extract_all(store)

      assert classes == []
    end

    test "handles ontology with only properties (no classes)" do
      # The valid_simple.ttl has Module and Function as owl:Class
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      classes = Class.extract_all(store)

      assert length(classes) >= 2
      iris = Enum.map(classes, & &1.iri)
      assert "http://example.org/elixir/core#Module" in iris
      assert "http://example.org/elixir/core#Function" in iris
    end

    test "returns Class structs with all required fields" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      classes = Class.extract_all(store)

      Enum.each(classes, fn class ->
        assert %Class{} = class
        assert is_binary(class.iri)
        assert is_binary(class.source_graph)
        assert class.type in [:owl_class, :rdfs_class]
      end)
    end
  end

  describe "extract_all_as_map/1" do
    test "returns map keyed by IRI" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      class_map = Class.extract_all_as_map(store)

      assert is_map(class_map)
      assert Map.has_key?(class_map, "http://example.org/entities#Person")

      person = class_map["http://example.org/entities#Person"]
      assert %Class{} = person
      assert person.iri == "http://example.org/entities#Person"
    end

    test "enables O(1) lookup by IRI" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      class_map = Class.extract_all_as_map(store)

      # Direct map lookup
      assert class_map["http://example.org/entities#Manager"] != nil
      assert class_map["http://example.org/nonexistent#Foo"] == nil
    end
  end

  describe "count/1" do
    test "returns correct count of classes" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      count = Class.count(store)

      # 5 owl:Class + 1 rdfs:Class = 6 classes
      assert count == 6
    end

    test "returns 0 for empty ontology" do
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/empty.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      count = Class.count(store)

      assert count == 0
    end
  end

  describe "is_class?/2" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "returns true for owl:Class IRIs", %{store: store} do
      assert Class.is_class?(store, "http://example.org/entities#Person")
      assert Class.is_class?(store, "http://example.org/entities#Manager")
    end

    test "returns true for rdfs:Class IRIs", %{store: store} do
      assert Class.is_class?(store, "http://example.org/entities#LegacyClass")
    end

    test "returns false for non-class IRIs", %{store: store} do
      refute Class.is_class?(store, "http://example.org/entities#worksFor")
      refute Class.is_class?(store, "http://example.org/entities#JohnDoe")
      refute Class.is_class?(store, "http://example.org/nonexistent#Foo")
    end
  end

  describe "get/2" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "returns {:ok, class} for existing class", %{store: store} do
      {:ok, class} = Class.get(store, "http://example.org/entities#Person")

      assert %Class{} = class
      assert class.iri == "http://example.org/entities#Person"
      assert class.type == :owl_class
      assert class.source_graph == "http://example.org/entities#"
    end

    test "returns {:error, :not_found} for non-existent class", %{store: store} do
      assert {:error, {:not_found, _}} = Class.get(store, "http://example.org/nonexistent#Foo")
    end

    test "returns {:error, :not_found} for property IRI", %{store: store} do
      assert {:error, {:not_found, _}} = Class.get(store, "http://example.org/entities#worksFor")
    end
  end

  describe "integration with TripleStore" do
    test "works with valid_simple.ttl fixture" do
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      classes = Class.extract_all(store)

      # valid_simple.ttl has Module and Function as classes
      assert length(classes) == 2
      iris = Enum.map(classes, & &1.iri)
      assert "http://example.org/elixir/core#Module" in iris
      assert "http://example.org/elixir/core#Function" in iris
    end

    test "handles blank nodes gracefully (should not extract as classes)" do
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/blank_nodes.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      classes = Class.extract_all(store)

      # Blank nodes should not be extracted as classes (only IRIs)
      Enum.each(classes, fn class ->
        assert String.starts_with?(class.iri, "http://")
      end)
    end
  end
end
