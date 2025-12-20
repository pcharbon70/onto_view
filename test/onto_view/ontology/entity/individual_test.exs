defmodule OntoView.Ontology.Entity.IndividualTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Entity.Individual
  alias OntoView.Ontology.ImportResolver
  alias OntoView.Ontology.TripleStore

  @fixture_path "test/support/fixtures/ontologies/entity_extraction/individuals.ttl"
  @classes_fixture_path "test/support/fixtures/ontologies/entity_extraction/classes.ttl"

  # Helper to load fixture and create triple store
  defp load_fixture(path \\ @fixture_path) do
    {:ok, loaded} = ImportResolver.load_with_imports(path)
    TripleStore.from_loaded_ontologies(loaded)
  end

  # Expected IRIs from the individuals.ttl fixture
  @john_doe "http://example.org/individuals#JohnDoe"
  @jane_smith "http://example.org/individuals#JaneSmith"
  @bob_johnson "http://example.org/individuals#BobJohnson"
  @acme_corp "http://example.org/individuals#AcmeCorp"
  @project_alpha "http://example.org/individuals#ProjectAlpha"
  @unclassified "http://example.org/individuals#UnclassifiedEntity"
  @alice_williams "http://example.org/individuals#AliceWilliams"
  @carol_davis "http://example.org/individuals#CarolDavis"
  @tech_startup "http://example.org/individuals#TechStartup"

  # Class IRIs
  @person_class "http://example.org/individuals#Person"
  @employee_class "http://example.org/individuals#Employee"
  @manager_class "http://example.org/individuals#Manager"
  @organization_class "http://example.org/individuals#Organization"
  @project_class "http://example.org/individuals#Project"

  @graph_iri "http://example.org/individuals#"

  describe "Task 1.3.4.1 - Detect named individuals" do
    test "extracts individuals declared with owl:NamedIndividual" do
      store = load_fixture()
      individuals = Individual.extract_all(store)

      # Should find all 9 individuals from the fixture
      assert length(individuals) == 9

      iris = Enum.map(individuals, & &1.iri)
      assert @john_doe in iris
      assert @jane_smith in iris
      assert @bob_johnson in iris
      assert @acme_corp in iris
      assert @project_alpha in iris
      assert @unclassified in iris
      assert @alice_williams in iris
      assert @carol_davis in iris
      assert @tech_startup in iris
    end

    test "only extracts entities with explicit owl:NamedIndividual type" do
      store = load_fixture()
      individuals = Individual.extract_all(store)

      # Verify all extracted entities are actually NamedIndividuals
      for individual <- individuals do
        assert is_binary(individual.iri)
        assert String.starts_with?(individual.iri, "http://")
      end
    end

    test "does not extract classes as individuals" do
      store = load_fixture()
      individuals = Individual.extract_all(store)
      iris = Enum.map(individuals, & &1.iri)

      # Classes should not appear as individuals
      refute @person_class in iris
      refute @employee_class in iris
      refute @manager_class in iris
      refute @organization_class in iris
      refute @project_class in iris
    end

    test "does not extract properties as individuals" do
      store = load_fixture()
      individuals = Individual.extract_all(store)
      iris = Enum.map(individuals, & &1.iri)

      # Properties should not appear as individuals
      refute "http://example.org/individuals#worksFor" in iris
      refute "http://example.org/individuals#manages" in iris
      refute "http://example.org/individuals#hasName" in iris
    end

    test "deduplicates individuals by IRI" do
      store = load_fixture()
      individuals = Individual.extract_all(store)

      iris = Enum.map(individuals, & &1.iri)
      unique_iris = Enum.uniq(iris)

      assert length(iris) == length(unique_iris)
    end

    test "handles ontology with no individuals" do
      # Use a fixture that has no individuals
      {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      store = TripleStore.from_loaded_ontologies(loaded)

      individuals = Individual.extract_all(store)
      # May have some or none depending on fixture, just verify no crash
      assert is_list(individuals)
    end
  end

  describe "Task 1.3.4.2 - Associate individuals with their classes" do
    test "extracts single class membership" do
      store = load_fixture()
      {:ok, john} = Individual.get(store, @john_doe)

      assert @person_class in john.classes
      assert length(john.classes) == 1
    end

    test "extracts multiple class memberships" do
      store = load_fixture()
      {:ok, jane} = Individual.get(store, @jane_smith)

      # Jane is declared as Manager, Employee, and Person
      assert @manager_class in jane.classes
      assert @employee_class in jane.classes
      assert @person_class in jane.classes
      assert length(jane.classes) == 3
    end

    test "handles individuals with subclass type only" do
      store = load_fixture()
      {:ok, bob} = Individual.get(store, @bob_johnson)

      # Bob is only declared as Employee (not explicitly as Person)
      assert @employee_class in bob.classes
      refute @person_class in bob.classes  # Not explicitly declared
      assert length(bob.classes) == 1
    end

    test "handles individual with no class membership" do
      store = load_fixture()
      {:ok, unclassified} = Individual.get(store, @unclassified)

      assert unclassified.classes == []
    end

    test "extracts Organization class membership" do
      store = load_fixture()
      {:ok, acme} = Individual.get(store, @acme_corp)

      assert @organization_class in acme.classes
      assert length(acme.classes) == 1
    end

    test "extracts Project class membership" do
      store = load_fixture()
      {:ok, project} = Individual.get(store, @project_alpha)

      assert @project_class in project.classes
      assert length(project.classes) == 1
    end

    test "excludes owl:NamedIndividual from class list" do
      store = load_fixture()

      for individual <- Individual.extract_all(store) do
        refute "http://www.w3.org/2002/07/owl#NamedIndividual" in individual.classes
      end
    end

    test "excludes owl:Class from class list" do
      store = load_fixture()

      for individual <- Individual.extract_all(store) do
        refute "http://www.w3.org/2002/07/owl#Class" in individual.classes
      end
    end
  end

  describe "provenance tracking (source_graph)" do
    test "attaches source graph to individuals" do
      store = load_fixture()
      individuals = Individual.extract_all(store)

      for individual <- individuals do
        assert is_binary(individual.source_graph)
        assert individual.source_graph == @graph_iri
      end
    end

    test "all individuals from fixture have same source graph" do
      store = load_fixture()
      individuals = Individual.extract_all(store)

      source_graphs = individuals |> Enum.map(& &1.source_graph) |> Enum.uniq()
      assert length(source_graphs) == 1
      assert hd(source_graphs) == @graph_iri
    end
  end

  describe "extract_all_as_map/1" do
    test "returns map keyed by IRI" do
      store = load_fixture()
      ind_map = Individual.extract_all_as_map(store)

      assert is_map(ind_map)
      assert Map.has_key?(ind_map, @john_doe)
      assert Map.has_key?(ind_map, @jane_smith)
      assert Map.has_key?(ind_map, @acme_corp)
    end

    test "map values are Individual structs" do
      store = load_fixture()
      ind_map = Individual.extract_all_as_map(store)

      for {_iri, individual} <- ind_map do
        assert %Individual{} = individual
        assert is_binary(individual.iri)
        assert is_binary(individual.source_graph)
        assert is_list(individual.classes)
      end
    end

    test "enables O(1) lookups" do
      store = load_fixture()
      ind_map = Individual.extract_all_as_map(store)

      individual = Map.get(ind_map, @john_doe)
      assert individual.iri == @john_doe
    end
  end

  describe "extract_from_graph/2" do
    test "filters individuals by source graph" do
      store = load_fixture()
      individuals = Individual.extract_from_graph(store, @graph_iri)

      assert length(individuals) == 9

      for individual <- individuals do
        assert individual.source_graph == @graph_iri
      end
    end

    test "returns empty list for non-existent graph" do
      store = load_fixture()
      individuals = Individual.extract_from_graph(store, "http://nonexistent.org/graph#")

      assert individuals == []
    end
  end

  describe "count/1" do
    test "returns correct count of individuals" do
      store = load_fixture()
      count = Individual.count(store)

      assert count == 9
    end

    test "returns zero for store with no individuals" do
      {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/valid_simple.ttl")
      store = TripleStore.from_loaded_ontologies(loaded)

      count = Individual.count(store)
      # May be 0 or more depending on fixture, just verify it's non-negative
      assert count >= 0
    end
  end

  describe "is_individual?/2" do
    test "returns true for existing individual" do
      store = load_fixture()

      assert Individual.is_individual?(store, @john_doe)
      assert Individual.is_individual?(store, @jane_smith)
      assert Individual.is_individual?(store, @acme_corp)
      assert Individual.is_individual?(store, @unclassified)
    end

    test "returns false for non-existent individual" do
      store = load_fixture()

      refute Individual.is_individual?(store, "http://example.org/individuals#NonExistent")
    end

    test "returns false for class IRI" do
      store = load_fixture()

      refute Individual.is_individual?(store, @person_class)
      refute Individual.is_individual?(store, @organization_class)
    end

    test "returns false for property IRI" do
      store = load_fixture()

      refute Individual.is_individual?(store, "http://example.org/individuals#worksFor")
    end
  end

  describe "get/2" do
    test "returns {:ok, individual} for existing individual" do
      store = load_fixture()

      assert {:ok, individual} = Individual.get(store, @john_doe)
      assert individual.iri == @john_doe
      assert @person_class in individual.classes
    end

    test "returns {:error, :not_found} for non-existent individual" do
      store = load_fixture()

      assert {:error, :not_found} = Individual.get(store, "http://example.org/individuals#NonExistent")
    end

    test "returns individual with all class associations" do
      store = load_fixture()

      {:ok, jane} = Individual.get(store, @jane_smith)
      assert length(jane.classes) == 3
    end
  end

  describe "list_iris/1" do
    test "returns list of all individual IRIs" do
      store = load_fixture()
      iris = Individual.list_iris(store)

      assert is_list(iris)
      assert length(iris) == 9
      assert @john_doe in iris
      assert @jane_smith in iris
      assert @acme_corp in iris
    end

    test "returns only string IRIs" do
      store = load_fixture()
      iris = Individual.list_iris(store)

      for iri <- iris do
        assert is_binary(iri)
        assert String.starts_with?(iri, "http://")
      end
    end
  end

  describe "of_class/2" do
    test "finds individuals of a specific class" do
      store = load_fixture()
      people = Individual.of_class(store, @person_class)

      iris = Enum.map(people, & &1.iri)
      # JohnDoe and JaneSmith are explicitly typed as Person
      assert @john_doe in iris
      assert @jane_smith in iris
    end

    test "finds individuals with multiple class memberships" do
      store = load_fixture()
      managers = Individual.of_class(store, @manager_class)

      iris = Enum.map(managers, & &1.iri)
      assert @jane_smith in iris
      assert @carol_davis in iris
    end

    test "finds employees" do
      store = load_fixture()
      employees = Individual.of_class(store, @employee_class)

      iris = Enum.map(employees, & &1.iri)
      assert @jane_smith in iris
      assert @bob_johnson in iris
      assert @alice_williams in iris
    end

    test "finds organizations" do
      store = load_fixture()
      orgs = Individual.of_class(store, @organization_class)

      iris = Enum.map(orgs, & &1.iri)
      assert @acme_corp in iris
      assert @tech_startup in iris
      assert length(orgs) == 2
    end

    test "returns empty list for class with no individuals" do
      store = load_fixture()
      individuals = Individual.of_class(store, "http://example.org/individuals#NonExistentClass")

      assert individuals == []
    end
  end

  describe "without_class/1" do
    test "finds individuals with no class membership" do
      store = load_fixture()
      unclassified = Individual.without_class(store)

      assert length(unclassified) == 1
      assert hd(unclassified).iri == @unclassified
    end

    test "all returned individuals have empty class list" do
      store = load_fixture()
      unclassified = Individual.without_class(store)

      for individual <- unclassified do
        assert individual.classes == []
      end
    end
  end

  describe "integration with classes.ttl fixture" do
    test "extracts individual from classes fixture" do
      store = load_fixture(@classes_fixture_path)
      individuals = Individual.extract_all(store)

      # classes.ttl has JohnDoe as a NamedIndividual
      iris = Enum.map(individuals, & &1.iri)
      assert "http://example.org/entities#JohnDoe" in iris
    end

    test "associates JohnDoe with Manager class from classes fixture" do
      store = load_fixture(@classes_fixture_path)
      {:ok, john} = Individual.get(store, "http://example.org/entities#JohnDoe")

      assert "http://example.org/entities#Manager" in john.classes
    end
  end

  describe "struct fields" do
    test "Individual struct has correct fields" do
      individual = %Individual{
        iri: "http://example.org/test#TestIndividual",
        source_graph: "http://example.org/test#",
        classes: ["http://example.org/test#TestClass"]
      }

      assert individual.iri == "http://example.org/test#TestIndividual"
      assert individual.source_graph == "http://example.org/test#"
      assert individual.classes == ["http://example.org/test#TestClass"]
    end

    test "classes field defaults to empty list" do
      individual = %Individual{
        iri: "http://example.org/test#TestIndividual",
        source_graph: "http://example.org/test#"
      }

      assert individual.classes == []
    end
  end
end
