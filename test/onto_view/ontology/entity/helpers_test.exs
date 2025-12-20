defmodule OntoView.Ontology.Entity.HelpersTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Entity.Helpers
  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.ImportResolver

  # Test fixtures path
  @fixtures_path "test/support/fixtures/ontologies/entity_extraction"

  describe "max_iri_length/0" do
    test "returns maximum allowed IRI length" do
      assert Helpers.max_iri_length() == 8192
    end
  end

  describe "validate_iri/1" do
    test "returns :ok for valid short IRI" do
      assert Helpers.validate_iri("http://example.org/Person") == :ok
    end

    test "returns :ok for IRI at max length" do
      iri = String.duplicate("a", 8192)
      assert Helpers.validate_iri(iri) == :ok
    end

    test "returns error for IRI exceeding max length" do
      iri = String.duplicate("a", 8193)
      assert {:error, {:iri_too_long, [length: 8193, max: 8192]}} = Helpers.validate_iri(iri)
    end

    test "returns error for very long IRI" do
      iri = String.duplicate("x", 10000)
      assert {:error, {:iri_too_long, [length: 10000, max: 8192]}} = Helpers.validate_iri(iri)
    end

    test "returns error for non-binary input" do
      assert Helpers.validate_iri(123) == {:error, :invalid_iri_format}
      assert Helpers.validate_iri(nil) == {:error, :invalid_iri_format}
      assert Helpers.validate_iri(:atom) == {:error, :invalid_iri_format}
      assert Helpers.validate_iri(['list']) == {:error, :invalid_iri_format}
    end

    test "returns :ok for empty string" do
      assert Helpers.validate_iri("") == :ok
    end
  end

  describe "valid_iri?/1" do
    test "returns true for valid IRI" do
      assert Helpers.valid_iri?("http://example.org/Person") == true
    end

    test "returns false for too-long IRI" do
      iri = String.duplicate("a", 10000)
      assert Helpers.valid_iri?(iri) == false
    end

    test "returns false for non-binary input" do
      assert Helpers.valid_iri?(123) == false
      assert Helpers.valid_iri?(nil) == false
    end
  end

  describe "extract_domain/2" do
    setup do
      fixture_path = Path.join(@fixtures_path, "object_properties.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)
      %{store: store}
    end

    test "extracts domain for property with single domain", %{store: store} do
      domains = Helpers.extract_domain(store, "http://example.org/properties#worksFor")
      assert domains == ["http://example.org/properties#Person"]
    end

    test "extracts domain for property with multiple domains", %{store: store} do
      domains = Helpers.extract_domain(store, "http://example.org/properties#participatesIn")
      assert "http://example.org/properties#Person" in domains
      assert "http://example.org/properties#Organization" in domains
    end

    test "returns empty list for property without domain", %{store: store} do
      # ownedBy has no domain in the fixture
      domains = Helpers.extract_domain(store, "http://example.org/properties#ownedBy")
      assert domains == []
    end

    test "returns empty list for non-existent property", %{store: store} do
      domains = Helpers.extract_domain(store, "http://example.org/nonexistent")
      assert domains == []
    end
  end

  describe "extract_range/2" do
    setup do
      fixture_path = Path.join(@fixtures_path, "object_properties.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)
      %{store: store}
    end

    test "extracts range for property with single range", %{store: store} do
      ranges = Helpers.extract_range(store, "http://example.org/properties#worksFor")
      assert ranges == ["http://example.org/properties#Organization"]
    end

    test "extracts range for property with multiple ranges", %{store: store} do
      ranges = Helpers.extract_range(store, "http://example.org/properties#locatedIn")
      assert "http://example.org/properties#Location" in ranges
      assert "http://example.org/properties#Organization" in ranges
    end

    test "returns empty list for non-existent property", %{store: store} do
      ranges = Helpers.extract_range(store, "http://example.org/nonexistent")
      assert ranges == []
    end
  end

  describe "extract_domain/2 with data properties" do
    setup do
      fixture_path = Path.join(@fixtures_path, "data_properties.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)
      %{store: store}
    end

    test "extracts domain for data property", %{store: store} do
      domains = Helpers.extract_domain(store, "http://example.org/dataprops#hasName")
      assert "http://example.org/dataprops#Person" in domains
    end
  end

  describe "extract_range/2 with data properties" do
    setup do
      fixture_path = Path.join(@fixtures_path, "data_properties.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)
      %{store: store}
    end

    test "extracts datatype range for data property", %{store: store} do
      ranges = Helpers.extract_range(store, "http://example.org/dataprops#hasName")
      assert "http://www.w3.org/2001/XMLSchema#string" in ranges
    end

    test "extracts integer range for data property", %{store: store} do
      ranges = Helpers.extract_range(store, "http://example.org/dataprops#hasAge")
      assert "http://www.w3.org/2001/XMLSchema#integer" in ranges
    end
  end

  describe "apply_limit/2" do
    test "returns all items when limit is :infinity" do
      items = [1, 2, 3, 4, 5]
      assert Helpers.apply_limit(items, :infinity) == [1, 2, 3, 4, 5]
    end

    test "returns limited items when limit is positive integer" do
      items = [1, 2, 3, 4, 5]
      assert Helpers.apply_limit(items, 3) == [1, 2, 3]
    end

    test "returns all items when limit exceeds list length" do
      items = [1, 2, 3]
      assert Helpers.apply_limit(items, 10) == [1, 2, 3]
    end

    test "returns single item when limit is 1" do
      items = [1, 2, 3, 4, 5]
      assert Helpers.apply_limit(items, 1) == [1]
    end

    test "works with streams" do
      stream = Stream.iterate(1, &(&1 + 1))
      assert Helpers.apply_limit(stream, 5) == [1, 2, 3, 4, 5]
    end

    test "returns empty list for empty input with infinity" do
      assert Helpers.apply_limit([], :infinity) == []
    end

    test "returns empty list for empty input with limit" do
      assert Helpers.apply_limit([], 5) == []
    end
  end

  describe "filter_by_membership/3" do
    test "filters structs by list field membership" do
      entities = [
        %{iri: "a", domain: ["Class1", "Class2"]},
        %{iri: "b", domain: ["Class2", "Class3"]},
        %{iri: "c", domain: ["Class3"]}
      ]

      result = Helpers.filter_by_membership(entities, :domain, "Class2")
      assert length(result) == 2
      assert Enum.any?(result, &(&1.iri == "a"))
      assert Enum.any?(result, &(&1.iri == "b"))
    end

    test "returns empty list when no matches" do
      entities = [
        %{iri: "a", domain: ["Class1"]},
        %{iri: "b", domain: ["Class2"]}
      ]

      result = Helpers.filter_by_membership(entities, :domain, "NonExistent")
      assert result == []
    end

    test "handles empty entity list" do
      result = Helpers.filter_by_membership([], :domain, "Class1")
      assert result == []
    end

    test "handles entities with empty list fields" do
      entities = [
        %{iri: "a", domain: []},
        %{iri: "b", domain: ["Class1"]}
      ]

      result = Helpers.filter_by_membership(entities, :domain, "Class1")
      assert length(result) == 1
      assert hd(result).iri == "b"
    end
  end

  describe "group_by_field/2" do
    test "groups entities by field value" do
      entities = [
        %{iri: "a", source_graph: "graph1"},
        %{iri: "b", source_graph: "graph2"},
        %{iri: "c", source_graph: "graph1"}
      ]

      result = Helpers.group_by_field(entities, :source_graph)

      assert map_size(result) == 2
      assert length(result["graph1"]) == 2
      assert length(result["graph2"]) == 1
    end

    test "handles empty list" do
      result = Helpers.group_by_field([], :source_graph)
      assert result == %{}
    end

    test "handles single entity" do
      entities = [%{iri: "a", source_graph: "graph1"}]
      result = Helpers.group_by_field(entities, :source_graph)

      assert map_size(result) == 1
      assert result["graph1"] == entities
    end

    test "handles nil field values" do
      entities = [
        %{iri: "a", source_graph: nil},
        %{iri: "b", source_graph: "graph1"}
      ]

      result = Helpers.group_by_field(entities, :source_graph)

      assert map_size(result) == 2
      assert length(result[nil]) == 1
      assert length(result["graph1"]) == 1
    end
  end

  describe "not_found_error/2" do
    test "constructs error tuple with context" do
      result = Helpers.not_found_error("http://example.org/Missing", :class)

      assert result ==
               {:error, {:not_found, iri: "http://example.org/Missing", entity_type: :class}}
    end

    test "works with different entity types" do
      result = Helpers.not_found_error("http://example.org/Missing", :object_property)

      assert {:error, {:not_found, context}} = result
      assert context[:iri] == "http://example.org/Missing"
      assert context[:entity_type] == :object_property
    end

    test "preserves IRI in error context" do
      iri = "http://example.org/some/complex/iri#Entity"
      {:error, {:not_found, context}} = Helpers.not_found_error(iri, :individual)

      assert context[:iri] == iri
    end
  end
end
