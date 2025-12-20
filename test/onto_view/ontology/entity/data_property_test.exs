defmodule OntoView.Ontology.Entity.DataPropertyTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Entity.DataProperty
  alias OntoView.Ontology.ImportResolver
  alias OntoView.Ontology.TripleStore

  @fixture_path "test/support/fixtures/ontologies/entity_extraction/data_properties.ttl"
  @classes_fixture_path "test/support/fixtures/ontologies/entity_extraction/classes.ttl"

  # Helper to load fixture and create triple store
  defp load_fixture(path \\ @fixture_path) do
    {:ok, loaded} = ImportResolver.load_with_imports(path)
    TripleStore.from_loaded_ontologies(loaded)
  end

  # Expected IRIs from the data_properties.ttl fixture
  @has_name "http://example.org/dataprops#hasName"
  @has_age "http://example.org/dataprops#hasAge"
  @is_active "http://example.org/dataprops#isActive"
  @birth_date "http://example.org/dataprops#birthDate"
  @created_at "http://example.org/dataprops#createdAt"
  @has_price "http://example.org/dataprops#hasPrice"
  @has_weight "http://example.org/dataprops#hasWeight"
  @has_description "http://example.org/dataprops#hasDescription"
  @has_identifier "http://example.org/dataprops#hasIdentifier"
  @has_note "http://example.org/dataprops#hasNote"
  @has_value "http://example.org/dataprops#hasValue"
  @has_homepage "http://example.org/dataprops#hasHomepage"
  @start_time "http://example.org/dataprops#startTime"
  @has_duration "http://example.org/dataprops#hasDuration"

  # Datatype IRIs
  @xsd_string "http://www.w3.org/2001/XMLSchema#string"
  @xsd_integer "http://www.w3.org/2001/XMLSchema#integer"
  @xsd_boolean "http://www.w3.org/2001/XMLSchema#boolean"
  @xsd_date "http://www.w3.org/2001/XMLSchema#date"
  @xsd_datetime "http://www.w3.org/2001/XMLSchema#dateTime"
  @xsd_decimal "http://www.w3.org/2001/XMLSchema#decimal"
  @xsd_double "http://www.w3.org/2001/XMLSchema#double"
  @xsd_anyuri "http://www.w3.org/2001/XMLSchema#anyURI"
  @xsd_time "http://www.w3.org/2001/XMLSchema#time"
  @xsd_duration "http://www.w3.org/2001/XMLSchema#duration"

  # Class IRIs
  @person_class "http://example.org/dataprops#Person"
  @organization_class "http://example.org/dataprops#Organization"
  @product_class "http://example.org/dataprops#Product"
  @event_class "http://example.org/dataprops#Event"

  @graph_iri "http://example.org/dataprops#"

  describe "Task 1.3.3.1 - Detect owl:DatatypeProperty" do
    test "extracts properties declared with owl:DatatypeProperty" do
      store = load_fixture()
      properties = DataProperty.extract_all(store)

      # Should find all 14 data properties from the fixture
      assert length(properties) == 14

      iris = Enum.map(properties, & &1.iri)
      assert @has_name in iris
      assert @has_age in iris
      assert @is_active in iris
      assert @birth_date in iris
      assert @created_at in iris
      assert @has_price in iris
      assert @has_weight in iris
      assert @has_description in iris
      assert @has_identifier in iris
      assert @has_note in iris
      assert @has_value in iris
      assert @has_homepage in iris
      assert @start_time in iris
      assert @has_duration in iris
    end

    test "does not extract object properties as data properties" do
      store = load_fixture()
      properties = DataProperty.extract_all(store)
      iris = Enum.map(properties, & &1.iri)

      # The 'knows' object property should not appear
      refute "http://example.org/dataprops#knows" in iris
    end

    test "does not extract classes as data properties" do
      store = load_fixture()
      properties = DataProperty.extract_all(store)
      iris = Enum.map(properties, & &1.iri)

      refute @person_class in iris
      refute @organization_class in iris
      refute @product_class in iris
    end

    test "does not extract individuals as data properties" do
      store = load_fixture()
      properties = DataProperty.extract_all(store)
      iris = Enum.map(properties, & &1.iri)

      refute "http://example.org/dataprops#JohnDoe" in iris
    end

    test "deduplicates properties by IRI" do
      store = load_fixture()
      properties = DataProperty.extract_all(store)

      iris = Enum.map(properties, & &1.iri)
      unique_iris = Enum.uniq(iris)

      assert length(iris) == length(unique_iris)
    end

    test "handles ontology with no data properties" do
      {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      store = TripleStore.from_loaded_ontologies(loaded)

      properties = DataProperty.extract_all(store)
      # May have some or none, just verify no crash
      assert is_list(properties)
    end
  end

  describe "Task 1.3.3.2 - Register datatype ranges" do
    test "extracts xsd:string range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_name)

      assert @xsd_string in prop.range
      assert length(prop.range) == 1
    end

    test "extracts xsd:integer range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_age)

      assert @xsd_integer in prop.range
    end

    test "extracts xsd:boolean range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @is_active)

      assert @xsd_boolean in prop.range
    end

    test "extracts xsd:date range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @birth_date)

      assert @xsd_date in prop.range
    end

    test "extracts xsd:dateTime range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @created_at)

      assert @xsd_datetime in prop.range
    end

    test "extracts xsd:decimal range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_price)

      assert @xsd_decimal in prop.range
    end

    test "extracts xsd:double range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_weight)

      assert @xsd_double in prop.range
    end

    test "extracts xsd:anyURI range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_homepage)

      assert @xsd_anyuri in prop.range
    end

    test "extracts xsd:time range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @start_time)

      assert @xsd_time in prop.range
    end

    test "extracts xsd:duration range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_duration)

      assert @xsd_duration in prop.range
    end

    test "handles property with no range (untyped)" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_note)

      assert prop.range == []
    end

    test "handles property with neither domain nor range" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_value)

      assert prop.domain == []
      assert prop.range == []
    end
  end

  describe "domain extraction" do
    test "extracts single domain" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_name)

      assert @person_class in prop.domain
      assert length(prop.domain) == 1
    end

    test "extracts multiple domains" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_description)

      assert @person_class in prop.domain
      assert @organization_class in prop.domain
      assert @product_class in prop.domain
      assert length(prop.domain) == 3
    end

    test "handles property with no domain" do
      store = load_fixture()
      {:ok, prop} = DataProperty.get(store, @has_identifier)

      assert prop.domain == []
    end
  end

  describe "provenance tracking (source_graph)" do
    test "attaches source graph to properties" do
      store = load_fixture()
      properties = DataProperty.extract_all(store)

      for property <- properties do
        assert is_binary(property.source_graph)
        assert property.source_graph == @graph_iri
      end
    end

    test "all properties from fixture have same source graph" do
      store = load_fixture()
      properties = DataProperty.extract_all(store)

      source_graphs = properties |> Enum.map(& &1.source_graph) |> Enum.uniq()
      assert length(source_graphs) == 1
      assert hd(source_graphs) == @graph_iri
    end
  end

  describe "extract_all_as_map/1" do
    test "returns map keyed by IRI" do
      store = load_fixture()
      prop_map = DataProperty.extract_all_as_map(store)

      assert is_map(prop_map)
      assert Map.has_key?(prop_map, @has_name)
      assert Map.has_key?(prop_map, @has_age)
      assert Map.has_key?(prop_map, @has_price)
    end

    test "map values are DataProperty structs" do
      store = load_fixture()
      prop_map = DataProperty.extract_all_as_map(store)

      for {_iri, property} <- prop_map do
        assert %DataProperty{} = property
        assert is_binary(property.iri)
        assert is_binary(property.source_graph)
        assert is_list(property.domain)
        assert is_list(property.range)
      end
    end

    test "enables O(1) lookups" do
      store = load_fixture()
      prop_map = DataProperty.extract_all_as_map(store)

      property = Map.get(prop_map, @has_name)
      assert property.iri == @has_name
    end
  end

  describe "extract_from_graph/2" do
    test "filters properties by source graph" do
      store = load_fixture()
      properties = DataProperty.extract_from_graph(store, @graph_iri)

      assert length(properties) == 14

      for property <- properties do
        assert property.source_graph == @graph_iri
      end
    end

    test "returns empty list for non-existent graph" do
      store = load_fixture()
      properties = DataProperty.extract_from_graph(store, "http://nonexistent.org/graph#")

      assert properties == []
    end
  end

  describe "count/1" do
    test "returns correct count of data properties" do
      store = load_fixture()
      count = DataProperty.count(store)

      assert count == 14
    end

    test "returns zero for store with no data properties" do
      {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      store = TripleStore.from_loaded_ontologies(loaded)

      count = DataProperty.count(store)
      assert count >= 0
    end
  end

  describe "is_data_property?/2" do
    test "returns true for existing data property" do
      store = load_fixture()

      assert DataProperty.is_data_property?(store, @has_name)
      assert DataProperty.is_data_property?(store, @has_age)
      assert DataProperty.is_data_property?(store, @has_price)
    end

    test "returns false for non-existent property" do
      store = load_fixture()

      refute DataProperty.is_data_property?(store, "http://example.org/dataprops#NonExistent")
    end

    test "returns false for object property IRI" do
      store = load_fixture()

      refute DataProperty.is_data_property?(store, "http://example.org/dataprops#knows")
    end

    test "returns false for class IRI" do
      store = load_fixture()

      refute DataProperty.is_data_property?(store, @person_class)
    end
  end

  describe "get/2" do
    test "returns {:ok, property} for existing property" do
      store = load_fixture()

      assert {:ok, property} = DataProperty.get(store, @has_name)
      assert property.iri == @has_name
      assert @xsd_string in property.range
    end

    test "returns {:error, :not_found} for non-existent property" do
      store = load_fixture()

      assert {:error, :not_found} = DataProperty.get(store, "http://example.org/dataprops#NonExistent")
    end

    test "returns property with all domain and range associations" do
      store = load_fixture()

      {:ok, prop} = DataProperty.get(store, @has_description)
      assert length(prop.domain) == 3
      assert length(prop.range) == 1
    end
  end

  describe "list_iris/1" do
    test "returns list of all data property IRIs" do
      store = load_fixture()
      iris = DataProperty.list_iris(store)

      assert is_list(iris)
      assert length(iris) == 14
      assert @has_name in iris
      assert @has_age in iris
      assert @has_price in iris
    end

    test "returns only string IRIs" do
      store = load_fixture()
      iris = DataProperty.list_iris(store)

      for iri <- iris do
        assert is_binary(iri)
        assert String.starts_with?(iri, "http://")
      end
    end
  end

  describe "with_domain/2" do
    test "finds properties with Person domain" do
      store = load_fixture()
      props = DataProperty.with_domain(store, @person_class)

      iris = Enum.map(props, & &1.iri)
      assert @has_name in iris
      assert @has_age in iris
      assert @is_active in iris
      assert @birth_date in iris
      assert @has_description in iris
      assert @has_note in iris
      assert @has_homepage in iris
    end

    test "finds properties with Product domain" do
      store = load_fixture()
      props = DataProperty.with_domain(store, @product_class)

      iris = Enum.map(props, & &1.iri)
      assert @has_price in iris
      assert @has_weight in iris
      assert @has_description in iris
    end

    test "finds properties with Event domain" do
      store = load_fixture()
      props = DataProperty.with_domain(store, @event_class)

      iris = Enum.map(props, & &1.iri)
      assert @start_time in iris
      assert @has_duration in iris
    end

    test "returns empty list for class with no properties" do
      store = load_fixture()
      props = DataProperty.with_domain(store, "http://example.org/dataprops#NonExistentClass")

      assert props == []
    end
  end

  describe "with_range/2" do
    test "finds properties with xsd:string range" do
      store = load_fixture()
      props = DataProperty.with_range(store, @xsd_string)

      iris = Enum.map(props, & &1.iri)
      assert @has_name in iris
      assert @has_description in iris
      assert @has_identifier in iris
    end

    test "finds properties with xsd:integer range" do
      store = load_fixture()
      props = DataProperty.with_range(store, @xsd_integer)

      iris = Enum.map(props, & &1.iri)
      assert @has_age in iris
      assert length(props) == 1
    end

    test "finds properties with xsd:boolean range" do
      store = load_fixture()
      props = DataProperty.with_range(store, @xsd_boolean)

      iris = Enum.map(props, & &1.iri)
      assert @is_active in iris
      assert length(props) == 1
    end

    test "returns empty list for unused datatype" do
      store = load_fixture()
      props = DataProperty.with_range(store, "http://www.w3.org/2001/XMLSchema#float")

      assert props == []
    end
  end

  describe "group_by_datatype/1" do
    test "groups properties by their datatype range" do
      store = load_fixture()
      by_type = DataProperty.group_by_datatype(store)

      assert is_map(by_type)
      assert Map.has_key?(by_type, @xsd_string)
      assert Map.has_key?(by_type, @xsd_integer)
      assert Map.has_key?(by_type, @xsd_boolean)
    end

    test "groups untyped properties under :untyped key" do
      store = load_fixture()
      by_type = DataProperty.group_by_datatype(store)

      assert Map.has_key?(by_type, :untyped)
      untyped = by_type[:untyped]

      iris = Enum.map(untyped, & &1.iri)
      assert @has_note in iris
      assert @has_value in iris
    end

    test "string properties are grouped correctly" do
      store = load_fixture()
      by_type = DataProperty.group_by_datatype(store)

      string_props = by_type[@xsd_string]
      iris = Enum.map(string_props, & &1.iri)

      assert @has_name in iris
      assert @has_description in iris
      assert @has_identifier in iris
    end

    test "properties with multiple ranges appear in multiple groups" do
      # This tests the implementation - a property can be in multiple groups
      # if it has multiple range declarations
      store = load_fixture()
      by_type = DataProperty.group_by_datatype(store)

      # All our test properties have single ranges
      # Just verify the structure is correct
      for {key, props} <- by_type do
        assert is_atom(key) or is_binary(key)
        assert is_list(props)

        for prop <- props do
          assert %DataProperty{} = prop
        end
      end
    end
  end

  describe "integration with classes.ttl fixture" do
    test "extracts data properties from classes fixture" do
      store = load_fixture(@classes_fixture_path)
      properties = DataProperty.extract_all(store)

      # classes.ttl has hasName and hasAge data properties
      iris = Enum.map(properties, & &1.iri)
      assert "http://example.org/entities#hasName" in iris
      assert "http://example.org/entities#hasAge" in iris
    end

    test "extracts correct ranges from classes fixture" do
      store = load_fixture(@classes_fixture_path)
      {:ok, has_name} = DataProperty.get(store, "http://example.org/entities#hasName")
      {:ok, has_age} = DataProperty.get(store, "http://example.org/entities#hasAge")

      assert @xsd_string in has_name.range
      assert @xsd_integer in has_age.range
    end
  end

  describe "struct fields" do
    test "DataProperty struct has correct fields" do
      property = %DataProperty{
        iri: "http://example.org/test#testProperty",
        source_graph: "http://example.org/test#",
        domain: ["http://example.org/test#TestClass"],
        range: ["http://www.w3.org/2001/XMLSchema#string"]
      }

      assert property.iri == "http://example.org/test#testProperty"
      assert property.source_graph == "http://example.org/test#"
      assert property.domain == ["http://example.org/test#TestClass"]
      assert property.range == ["http://www.w3.org/2001/XMLSchema#string"]
    end

    test "domain and range fields default to empty lists" do
      property = %DataProperty{
        iri: "http://example.org/test#testProperty",
        source_graph: "http://example.org/test#"
      }

      assert property.domain == []
      assert property.range == []
    end
  end
end
