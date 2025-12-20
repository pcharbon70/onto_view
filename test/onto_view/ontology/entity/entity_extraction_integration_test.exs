defmodule OntoView.Ontology.Entity.EntityExtractionIntegrationTest do
  @moduledoc """
  Integration tests for Task 1.3.99 — OWL Entity Extraction.

  These tests verify that the complete entity extraction pipeline
  correctly identifies and extracts all OWL entity types from a
  unified ontology.

  ## Test Coverage

  - 1.3.99.1: Detects all classes correctly
  - 1.3.99.2: Detects all properties correctly (object + data)
  - 1.3.99.3: Detects all individuals correctly
  - 1.3.99.4: Prevents duplicate IRIs
  """
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Entity.Class
  alias OntoView.Ontology.Entity.ObjectProperty
  alias OntoView.Ontology.Entity.DataProperty
  alias OntoView.Ontology.Entity.Individual
  alias OntoView.Ontology.ImportResolver
  alias OntoView.Ontology.TripleStore

  @integration_fixture "test/support/fixtures/ontologies/entity_extraction/integration_complete.ttl"
  @graph_iri "http://example.org/integration#"

  # Expected counts from integration_complete.ttl
  @expected_class_count 6
  @expected_object_property_count 4
  @expected_data_property_count 5
  @expected_individual_count 5

  # Expected class IRIs
  @class_living_thing "http://example.org/integration#LivingThing"
  @class_animal "http://example.org/integration#Animal"
  @class_person "http://example.org/integration#Person"
  @class_organization "http://example.org/integration#Organization"
  @class_location "http://example.org/integration#Location"
  @class_event "http://example.org/integration#Event"

  # Expected object property IRIs
  @prop_knows "http://example.org/integration#knows"
  @prop_works_for "http://example.org/integration#worksFor"
  @prop_located_in "http://example.org/integration#locatedIn"
  @prop_participates_in "http://example.org/integration#participatesIn"

  # Expected data property IRIs
  @prop_has_name "http://example.org/integration#hasName"
  @prop_has_age "http://example.org/integration#hasAge"
  @prop_has_email "http://example.org/integration#hasEmail"
  @prop_founded_date "http://example.org/integration#foundedDate"
  @prop_is_active "http://example.org/integration#isActive"

  # Expected individual IRIs
  @ind_alice "http://example.org/integration#Alice"
  @ind_bob "http://example.org/integration#Bob"
  @ind_acme "http://example.org/integration#AcmeCorp"
  @ind_new_york "http://example.org/integration#NewYork"
  @ind_conference "http://example.org/integration#Conference2024"

  # XSD datatypes
  @xsd_string "http://www.w3.org/2001/XMLSchema#string"
  @xsd_integer "http://www.w3.org/2001/XMLSchema#integer"
  @xsd_date "http://www.w3.org/2001/XMLSchema#date"
  @xsd_boolean "http://www.w3.org/2001/XMLSchema#boolean"

  # Helper to load fixture and create triple store
  defp load_integration_fixture do
    {:ok, loaded} = ImportResolver.load_with_imports(@integration_fixture)
    TripleStore.from_loaded_ontologies(loaded)
  end

  describe "Task 1.3.99.1 - Detects all classes correctly" do
    test "extracts correct number of classes" do
      store = load_integration_fixture()
      classes = Class.extract_all(store)

      assert length(classes) == @expected_class_count
    end

    test "extracts all expected class IRIs" do
      store = load_integration_fixture()
      class_iris = Class.list_iris(store)

      assert @class_living_thing in class_iris
      assert @class_animal in class_iris
      assert @class_person in class_iris
      assert @class_organization in class_iris
      assert @class_location in class_iris
      assert @class_event in class_iris
    end

    test "all classes have correct source graph" do
      store = load_integration_fixture()
      classes = Class.extract_all(store)

      for class <- classes do
        assert class.source_graph == @graph_iri
      end
    end

    test "classes are distinct from other entity types" do
      store = load_integration_fixture()
      class_iris = Class.list_iris(store)
      object_prop_iris = ObjectProperty.list_iris(store)
      data_prop_iris = DataProperty.list_iris(store)
      individual_iris = Individual.list_iris(store)

      # No overlap between classes and properties
      for class_iri <- class_iris do
        refute class_iri in object_prop_iris, "Class #{class_iri} should not be an object property"
        refute class_iri in data_prop_iris, "Class #{class_iri} should not be a data property"
        refute class_iri in individual_iris, "Class #{class_iri} should not be an individual"
      end
    end

    test "is_class? returns true for all extracted classes" do
      store = load_integration_fixture()

      assert Class.is_class?(store, @class_living_thing)
      assert Class.is_class?(store, @class_animal)
      assert Class.is_class?(store, @class_person)
      assert Class.is_class?(store, @class_organization)
      assert Class.is_class?(store, @class_location)
      assert Class.is_class?(store, @class_event)
    end
  end

  describe "Task 1.3.99.2 - Detects all properties correctly" do
    test "extracts correct number of object properties" do
      store = load_integration_fixture()
      properties = ObjectProperty.extract_all(store)

      assert length(properties) == @expected_object_property_count
    end

    test "extracts correct number of data properties" do
      store = load_integration_fixture()
      properties = DataProperty.extract_all(store)

      assert length(properties) == @expected_data_property_count
    end

    test "extracts all expected object property IRIs" do
      store = load_integration_fixture()
      prop_iris = ObjectProperty.list_iris(store)

      assert @prop_knows in prop_iris
      assert @prop_works_for in prop_iris
      assert @prop_located_in in prop_iris
      assert @prop_participates_in in prop_iris
    end

    test "extracts all expected data property IRIs" do
      store = load_integration_fixture()
      prop_iris = DataProperty.list_iris(store)

      assert @prop_has_name in prop_iris
      assert @prop_has_age in prop_iris
      assert @prop_has_email in prop_iris
      assert @prop_founded_date in prop_iris
      assert @prop_is_active in prop_iris
    end

    test "object properties have correct domain/range" do
      store = load_integration_fixture()

      {:ok, knows} = ObjectProperty.get(store, @prop_knows)
      assert @class_person in knows.domain
      assert @class_person in knows.range

      {:ok, works_for} = ObjectProperty.get(store, @prop_works_for)
      assert @class_person in works_for.domain
      assert @class_organization in works_for.range

      {:ok, located_in} = ObjectProperty.get(store, @prop_located_in)
      assert @class_location in located_in.range

      {:ok, participates_in} = ObjectProperty.get(store, @prop_participates_in)
      assert @class_person in participates_in.domain
      assert @class_event in participates_in.range
    end

    test "data properties have correct datatype ranges" do
      store = load_integration_fixture()

      {:ok, has_name} = DataProperty.get(store, @prop_has_name)
      assert @xsd_string in has_name.range

      {:ok, has_age} = DataProperty.get(store, @prop_has_age)
      assert @xsd_integer in has_age.range

      {:ok, has_email} = DataProperty.get(store, @prop_has_email)
      assert @xsd_string in has_email.range

      {:ok, founded_date} = DataProperty.get(store, @prop_founded_date)
      assert @xsd_date in founded_date.range

      {:ok, is_active} = DataProperty.get(store, @prop_is_active)
      assert @xsd_boolean in is_active.range
    end

    test "properties are distinct from other entity types" do
      store = load_integration_fixture()
      object_prop_iris = ObjectProperty.list_iris(store)
      data_prop_iris = DataProperty.list_iris(store)
      class_iris = Class.list_iris(store)
      individual_iris = Individual.list_iris(store)

      # Object properties should not overlap with other types
      for prop_iri <- object_prop_iris do
        refute prop_iri in class_iris, "Object property #{prop_iri} should not be a class"
        refute prop_iri in data_prop_iris, "Object property #{prop_iri} should not be a data property"
        refute prop_iri in individual_iris, "Object property #{prop_iri} should not be an individual"
      end

      # Data properties should not overlap with other types
      for prop_iri <- data_prop_iris do
        refute prop_iri in class_iris, "Data property #{prop_iri} should not be a class"
        refute prop_iri in object_prop_iris, "Data property #{prop_iri} should not be an object property"
        refute prop_iri in individual_iris, "Data property #{prop_iri} should not be an individual"
      end
    end

    test "all properties have correct source graph" do
      store = load_integration_fixture()
      object_props = ObjectProperty.extract_all(store)
      data_props = DataProperty.extract_all(store)

      for prop <- object_props ++ data_props do
        assert prop.source_graph == @graph_iri
      end
    end
  end

  describe "Task 1.3.99.3 - Detects all individuals correctly" do
    test "extracts correct number of individuals" do
      store = load_integration_fixture()
      individuals = Individual.extract_all(store)

      assert length(individuals) == @expected_individual_count
    end

    test "extracts all expected individual IRIs" do
      store = load_integration_fixture()
      ind_iris = Individual.list_iris(store)

      assert @ind_alice in ind_iris
      assert @ind_bob in ind_iris
      assert @ind_acme in ind_iris
      assert @ind_new_york in ind_iris
      assert @ind_conference in ind_iris
    end

    test "individuals have correct class associations" do
      store = load_integration_fixture()

      {:ok, alice} = Individual.get(store, @ind_alice)
      assert @class_person in alice.classes

      {:ok, bob} = Individual.get(store, @ind_bob)
      assert @class_person in bob.classes

      {:ok, acme} = Individual.get(store, @ind_acme)
      assert @class_organization in acme.classes

      {:ok, new_york} = Individual.get(store, @ind_new_york)
      assert @class_location in new_york.classes

      {:ok, conference} = Individual.get(store, @ind_conference)
      assert @class_event in conference.classes
    end

    test "individuals are distinct from other entity types" do
      store = load_integration_fixture()
      individual_iris = Individual.list_iris(store)
      class_iris = Class.list_iris(store)
      object_prop_iris = ObjectProperty.list_iris(store)
      data_prop_iris = DataProperty.list_iris(store)

      for ind_iri <- individual_iris do
        refute ind_iri in class_iris, "Individual #{ind_iri} should not be a class"
        refute ind_iri in object_prop_iris, "Individual #{ind_iri} should not be an object property"
        refute ind_iri in data_prop_iris, "Individual #{ind_iri} should not be a data property"
      end
    end

    test "all individuals have correct source graph" do
      store = load_integration_fixture()
      individuals = Individual.extract_all(store)

      for individual <- individuals do
        assert individual.source_graph == @graph_iri
      end
    end

    test "of_class returns correct individuals" do
      store = load_integration_fixture()

      people = Individual.of_class(store, @class_person)
      people_iris = Enum.map(people, & &1.iri)
      assert @ind_alice in people_iris
      assert @ind_bob in people_iris
      refute @ind_acme in people_iris

      orgs = Individual.of_class(store, @class_organization)
      org_iris = Enum.map(orgs, & &1.iri)
      assert @ind_acme in org_iris
      assert length(orgs) == 1
    end
  end

  describe "Task 1.3.99.4 - Prevents duplicate IRIs" do
    test "class extraction produces no duplicate IRIs" do
      store = load_integration_fixture()
      classes = Class.extract_all(store)
      iris = Enum.map(classes, & &1.iri)

      assert length(iris) == length(Enum.uniq(iris))
    end

    test "object property extraction produces no duplicate IRIs" do
      store = load_integration_fixture()
      properties = ObjectProperty.extract_all(store)
      iris = Enum.map(properties, & &1.iri)

      assert length(iris) == length(Enum.uniq(iris))
    end

    test "data property extraction produces no duplicate IRIs" do
      store = load_integration_fixture()
      properties = DataProperty.extract_all(store)
      iris = Enum.map(properties, & &1.iri)

      assert length(iris) == length(Enum.uniq(iris))
    end

    test "individual extraction produces no duplicate IRIs" do
      store = load_integration_fixture()
      individuals = Individual.extract_all(store)
      iris = Enum.map(individuals, & &1.iri)

      assert length(iris) == length(Enum.uniq(iris))
    end

    test "entity types are mutually exclusive" do
      store = load_integration_fixture()

      class_iris = MapSet.new(Class.list_iris(store))
      object_prop_iris = MapSet.new(ObjectProperty.list_iris(store))
      data_prop_iris = MapSet.new(DataProperty.list_iris(store))
      individual_iris = MapSet.new(Individual.list_iris(store))

      # No IRI should appear in more than one category
      assert MapSet.disjoint?(class_iris, object_prop_iris)
      assert MapSet.disjoint?(class_iris, data_prop_iris)
      assert MapSet.disjoint?(class_iris, individual_iris)
      assert MapSet.disjoint?(object_prop_iris, data_prop_iris)
      assert MapSet.disjoint?(object_prop_iris, individual_iris)
      assert MapSet.disjoint?(data_prop_iris, individual_iris)
    end

    test "extract_all_as_map produces unique keys" do
      store = load_integration_fixture()

      class_map = Class.extract_all_as_map(store)
      assert map_size(class_map) == @expected_class_count

      object_prop_map = ObjectProperty.extract_all_as_map(store)
      assert map_size(object_prop_map) == @expected_object_property_count

      data_prop_map = DataProperty.extract_all_as_map(store)
      assert map_size(data_prop_map) == @expected_data_property_count

      individual_map = Individual.extract_all_as_map(store)
      assert map_size(individual_map) == @expected_individual_count
    end
  end

  describe "cross-entity queries" do
    test "can find properties by domain class" do
      store = load_integration_fixture()

      # Find all object properties with Person domain
      person_obj_props = ObjectProperty.with_domain(store, @class_person)
      obj_iris = Enum.map(person_obj_props, & &1.iri)
      assert @prop_knows in obj_iris
      assert @prop_works_for in obj_iris
      assert @prop_participates_in in obj_iris

      # Find all data properties with Person domain
      person_data_props = DataProperty.with_domain(store, @class_person)
      data_iris = Enum.map(person_data_props, & &1.iri)
      assert @prop_has_age in data_iris
      assert @prop_has_email in data_iris
    end

    test "can find properties by range" do
      store = load_integration_fixture()

      # Find object properties with Organization range
      org_props = ObjectProperty.with_range(store, @class_organization)
      org_iris = Enum.map(org_props, & &1.iri)
      assert @prop_works_for in org_iris

      # Find data properties with string range
      string_props = DataProperty.with_range(store, @xsd_string)
      string_iris = Enum.map(string_props, & &1.iri)
      assert @prop_has_name in string_iris
      assert @prop_has_email in string_iris
    end

    test "can find individuals by class membership" do
      store = load_integration_fixture()

      # All entities by type
      people = Individual.of_class(store, @class_person)
      orgs = Individual.of_class(store, @class_organization)
      locations = Individual.of_class(store, @class_location)
      events = Individual.of_class(store, @class_event)

      assert length(people) == 2
      assert length(orgs) == 1
      assert length(locations) == 1
      assert length(events) == 1
    end

    test "total entity count matches expected" do
      store = load_integration_fixture()

      total_classes = Class.count(store)
      total_object_props = ObjectProperty.count(store)
      total_data_props = DataProperty.count(store)
      total_individuals = Individual.count(store)

      assert total_classes == @expected_class_count
      assert total_object_props == @expected_object_property_count
      assert total_data_props == @expected_data_property_count
      assert total_individuals == @expected_individual_count

      total_entities = total_classes + total_object_props + total_data_props + total_individuals
      assert total_entities == 20  # 6 + 4 + 5 + 5
    end
  end

  describe "multi-ontology integration" do
    test "extracts entities from multiple fixtures combined" do
      # Load all entity extraction fixtures
      {:ok, classes_loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/classes.ttl")
      {:ok, obj_props_loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/object_properties.ttl")
      {:ok, data_props_loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/data_properties.ttl")
      {:ok, individuals_loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/entity_extraction/individuals.ttl")

      # Create individual stores
      classes_store = TripleStore.from_loaded_ontologies(classes_loaded)
      obj_props_store = TripleStore.from_loaded_ontologies(obj_props_loaded)
      data_props_store = TripleStore.from_loaded_ontologies(data_props_loaded)
      individuals_store = TripleStore.from_loaded_ontologies(individuals_loaded)

      # Each fixture should extract its primary entity type
      assert Class.count(classes_store) >= 6  # classes.ttl has multiple classes
      assert ObjectProperty.count(obj_props_store) >= 9  # object_properties.ttl has multiple properties
      assert DataProperty.count(data_props_store) >= 14  # data_properties.ttl has multiple properties
      assert Individual.count(individuals_store) >= 9  # individuals.ttl has multiple individuals
    end

    test "provenance tracking distinguishes source ontologies" do
      store = load_integration_fixture()

      # All entities from integration_complete.ttl should have the same source graph
      classes = Class.extract_from_graph(store, @graph_iri)
      obj_props = ObjectProperty.extract_from_graph(store, @graph_iri)
      data_props = DataProperty.extract_from_graph(store, @graph_iri)
      individuals = Individual.extract_from_graph(store, @graph_iri)

      assert length(classes) == @expected_class_count
      assert length(obj_props) == @expected_object_property_count
      assert length(data_props) == @expected_data_property_count
      assert length(individuals) == @expected_individual_count
    end
  end

  describe "error handling and edge cases" do
    test "handles empty ontology gracefully" do
      {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/empty.ttl")
      store = TripleStore.from_loaded_ontologies(loaded)

      assert Class.extract_all(store) == []
      assert ObjectProperty.extract_all(store) == []
      assert DataProperty.extract_all(store) == []
      assert Individual.extract_all(store) == []
    end

    test "get returns :not_found for non-existent IRIs" do
      store = load_integration_fixture()

      assert {:error, :not_found} = Class.get(store, "http://nonexistent.org/Class")
      assert {:error, :not_found} = ObjectProperty.get(store, "http://nonexistent.org/Prop")
      assert {:error, :not_found} = DataProperty.get(store, "http://nonexistent.org/Prop")
      assert {:error, :not_found} = Individual.get(store, "http://nonexistent.org/Ind")
    end

    test "is_* functions return false for non-existent IRIs" do
      store = load_integration_fixture()

      refute Class.is_class?(store, "http://nonexistent.org/Class")
      refute ObjectProperty.is_object_property?(store, "http://nonexistent.org/Prop")
      refute DataProperty.is_data_property?(store, "http://nonexistent.org/Prop")
      refute Individual.is_individual?(store, "http://nonexistent.org/Ind")
    end
  end
end
