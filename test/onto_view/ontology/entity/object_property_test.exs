defmodule OntoView.Ontology.Entity.ObjectPropertyTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Entity.ObjectProperty
  alias OntoView.Ontology.ImportResolver
  alias OntoView.Ontology.TripleStore

  @moduletag :entity_extraction

  # Task 1.3.2 — Object Property Extraction
  #
  # These tests validate OWL object property extraction from the canonical triple store.
  # Tests verify detection of owl:ObjectProperty declarations, extraction of property IRIs,
  # domain/range registration, and proper provenance tracking.

  describe "Task 1.3.2.1 - Detect owl:ObjectProperty" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "detects owl:ObjectProperty declarations", %{store: store} do
      props = ObjectProperty.extract_all(store)

      # The fixture defines 9 object properties
      assert length(props) >= 9

      # Verify specific properties are detected
      iris = Enum.map(props, & &1.iri)
      assert "http://example.org/properties#worksFor" in iris
      assert "http://example.org/properties#participatesIn" in iris
      assert "http://example.org/properties#locatedIn" in iris
      assert "http://example.org/properties#relatedTo" in iris
      assert "http://example.org/properties#owns" in iris
      assert "http://example.org/properties#ownedBy" in iris
      assert "http://example.org/properties#employs" in iris
      assert "http://example.org/properties#knows" in iris
      assert "http://example.org/properties#ancestorOf" in iris
    end

    test "does not extract data properties", %{store: store} do
      props = ObjectProperty.extract_all(store)
      iris = Enum.map(props, & &1.iri)

      # Data properties should not be detected as object properties
      refute "http://example.org/properties#hasName" in iris
    end

    test "does not extract classes", %{store: store} do
      props = ObjectProperty.extract_all(store)
      iris = Enum.map(props, & &1.iri)

      # Classes should not be detected as object properties
      refute "http://example.org/properties#Person" in iris
      refute "http://example.org/properties#Organization" in iris
    end

    test "does not extract individuals", %{store: store} do
      props = ObjectProperty.extract_all(store)
      iris = Enum.map(props, & &1.iri)

      # Named individuals should not be detected as object properties
      refute "http://example.org/properties#JohnDoe" in iris
    end

    test "detects symmetric properties as object properties", %{store: store} do
      props = ObjectProperty.extract_all(store)
      iris = Enum.map(props, & &1.iri)

      # SymmetricProperty is a subclass of ObjectProperty
      assert "http://example.org/properties#knows" in iris
    end

    test "detects transitive properties as object properties", %{store: store} do
      props = ObjectProperty.extract_all(store)
      iris = Enum.map(props, & &1.iri)

      # TransitiveProperty is a subclass of ObjectProperty
      assert "http://example.org/properties#ancestorOf" in iris
    end
  end

  describe "Task 1.3.2.2 - Register domain placeholders" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "extracts single domain declaration", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#worksFor")

      assert prop.domain == ["http://example.org/properties#Person"]
    end

    test "extracts multiple domain declarations", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#participatesIn")

      assert length(prop.domain) == 2
      assert "http://example.org/properties#Person" in prop.domain
      assert "http://example.org/properties#Organization" in prop.domain
    end

    test "returns empty list when no domain declared", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#relatedTo")

      assert prop.domain == []
    end

    test "returns empty list when only range declared (no domain)", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#ownedBy")

      assert prop.domain == []
      assert prop.range == ["http://example.org/properties#Person"]
    end
  end

  describe "Task 1.3.2.3 - Register range placeholders" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "extracts single range declaration", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#worksFor")

      assert prop.range == ["http://example.org/properties#Organization"]
    end

    test "extracts multiple range declarations", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#locatedIn")

      assert length(prop.range) == 2
      assert "http://example.org/properties#Location" in prop.range
      assert "http://example.org/properties#Organization" in prop.range
    end

    test "returns empty list when no range declared", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#relatedTo")

      assert prop.range == []
    end

    test "returns empty list when only domain declared (no range)", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#owns")

      assert prop.range == []
      assert prop.domain == ["http://example.org/properties#Person"]
    end
  end

  describe "provenance tracking" do
    test "attaches source graph to properties" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_all(store)

      # All properties should have source_graph pointing to the ontology
      Enum.each(props, fn prop ->
        assert is_binary(prop.source_graph)
        assert prop.source_graph == "http://example.org/properties#"
      end)
    end

    test "extract_from_graph/2 filters by source ontology" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_from_graph(store, "http://example.org/properties#")

      assert length(props) >= 9

      Enum.each(props, fn prop ->
        assert prop.source_graph == "http://example.org/properties#"
      end)
    end

    test "extract_from_graph/2 returns empty for non-existent graph" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_from_graph(store, "http://example.org/nonexistent#")

      assert props == []
    end
  end

  describe "extract_all/1" do
    test "returns empty list for ontology with no object properties" do
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/empty.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_all(store)

      assert props == []
    end

    test "returns ObjectProperty structs with all required fields" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_all(store)

      Enum.each(props, fn prop ->
        assert %ObjectProperty{} = prop
        assert is_binary(prop.iri)
        assert is_binary(prop.source_graph)
        assert is_list(prop.domain)
        assert is_list(prop.range)
      end)
    end

    test "deduplicates properties with same IRI" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_all(store)
      iris = Enum.map(props, & &1.iri)

      # Each IRI should appear exactly once
      assert length(iris) == length(Enum.uniq(iris))
    end
  end

  describe "extract_all_as_map/1" do
    test "returns map keyed by IRI" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      prop_map = ObjectProperty.extract_all_as_map(store)

      assert is_map(prop_map)
      assert Map.has_key?(prop_map, "http://example.org/properties#worksFor")

      works_for = prop_map["http://example.org/properties#worksFor"]
      assert %ObjectProperty{} = works_for
      assert works_for.iri == "http://example.org/properties#worksFor"
    end

    test "enables O(1) lookup by IRI" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      prop_map = ObjectProperty.extract_all_as_map(store)

      # Direct map lookup
      assert prop_map["http://example.org/properties#employs"] != nil
      assert prop_map["http://example.org/nonexistent#Foo"] == nil
    end
  end

  describe "count/1" do
    test "returns correct count of object properties" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      count = ObjectProperty.count(store)

      # 9 object properties in fixture
      assert count == 9
    end

    test "returns 0 for empty ontology" do
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/empty.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      count = ObjectProperty.count(store)

      assert count == 0
    end
  end

  describe "is_object_property?/2" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "returns true for object property IRIs", %{store: store} do
      assert ObjectProperty.is_object_property?(store, "http://example.org/properties#worksFor")
      assert ObjectProperty.is_object_property?(store, "http://example.org/properties#employs")
    end

    test "returns false for class IRIs", %{store: store} do
      refute ObjectProperty.is_object_property?(store, "http://example.org/properties#Person")
    end

    test "returns false for data property IRIs", %{store: store} do
      refute ObjectProperty.is_object_property?(store, "http://example.org/properties#hasName")
    end

    test "returns false for non-existent IRIs", %{store: store} do
      refute ObjectProperty.is_object_property?(store, "http://example.org/nonexistent#Foo")
    end
  end

  describe "get/2" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "returns {:ok, property} for existing property", %{store: store} do
      {:ok, prop} = ObjectProperty.get(store, "http://example.org/properties#worksFor")

      assert %ObjectProperty{} = prop
      assert prop.iri == "http://example.org/properties#worksFor"
      assert prop.source_graph == "http://example.org/properties#"
      assert prop.domain == ["http://example.org/properties#Person"]
      assert prop.range == ["http://example.org/properties#Organization"]
    end

    test "returns {:error, :not_found} for non-existent property", %{store: store} do
      assert {:error, {:not_found, _}} =
               ObjectProperty.get(store, "http://example.org/nonexistent#Foo")
    end

    test "returns {:error, :not_found} for class IRI", %{store: store} do
      assert {:error, {:not_found, _}} =
               ObjectProperty.get(store, "http://example.org/properties#Person")
    end
  end

  describe "list_iris/1" do
    test "returns all property IRIs" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      iris = ObjectProperty.list_iris(store)

      assert is_list(iris)
      assert length(iris) == 9
      assert "http://example.org/properties#worksFor" in iris
      assert "http://example.org/properties#employs" in iris
    end
  end

  describe "with_domain/2" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "finds properties with specified domain", %{store: store} do
      props = ObjectProperty.with_domain(store, "http://example.org/properties#Person")

      assert length(props) >= 4
      iris = Enum.map(props, & &1.iri)
      assert "http://example.org/properties#worksFor" in iris
      assert "http://example.org/properties#participatesIn" in iris
      assert "http://example.org/properties#owns" in iris
      assert "http://example.org/properties#knows" in iris
    end

    test "returns empty list for unused domain", %{store: store} do
      props = ObjectProperty.with_domain(store, "http://example.org/properties#Project")

      assert props == []
    end
  end

  describe "with_range/2" do
    setup do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/object_properties.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, store: store}
    end

    test "finds properties with specified range", %{store: store} do
      props = ObjectProperty.with_range(store, "http://example.org/properties#Person")

      assert length(props) >= 4
      iris = Enum.map(props, & &1.iri)
      assert "http://example.org/properties#employs" in iris
      assert "http://example.org/properties#ownedBy" in iris
      assert "http://example.org/properties#knows" in iris
      assert "http://example.org/properties#ancestorOf" in iris
    end

    test "returns empty list for unused range", %{store: store} do
      props = ObjectProperty.with_range(store, "http://example.org/properties#Animal")

      assert props == []
    end
  end

  describe "integration with existing fixtures" do
    test "works with classes.ttl fixture (has 2 object properties)" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_all(store)

      # classes.ttl has worksFor and manages
      assert length(props) == 2
      iris = Enum.map(props, & &1.iri)
      assert "http://example.org/entities#worksFor" in iris
      assert "http://example.org/entities#manages" in iris
    end

    test "extracts domain and range from classes.ttl" do
      {:ok, loaded} =
        ImportResolver.load_with_imports(
          "test/support/fixtures/ontologies/entity_extraction/classes.ttl"
        )

      store = TripleStore.from_loaded_ontologies(loaded)
      {:ok, works_for} = ObjectProperty.get(store, "http://example.org/entities#worksFor")

      assert works_for.domain == ["http://example.org/entities#Employee"]
      assert works_for.range == ["http://example.org/entities#Organization"]
    end

    test "works with valid_simple.ttl (no object properties)" do
      {:ok, loaded} =
        ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")

      store = TripleStore.from_loaded_ontologies(loaded)
      props = ObjectProperty.extract_all(store)

      # valid_simple.ttl has no object properties
      assert props == []
    end
  end
end
