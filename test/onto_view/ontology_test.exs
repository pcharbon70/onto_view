defmodule OntoView.OntologyTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology
  alias OntoView.FixtureHelpers

  describe "load_file/2 delegation" do
    test "successfully loads a valid Turtle file" do
      path = FixtureHelpers.fixture_path("valid_simple.ttl")

      assert {:ok, ontology} = Ontology.load_file(path)
      assert ontology.path == Path.expand(path)
      assert is_map(ontology.graph)
    end

    test "returns error for non-existent file" do
      assert {:error, :file_not_found} = Ontology.load_file("nonexistent.ttl")
    end

    test "accepts options and passes them through" do
      path = FixtureHelpers.fixture_path("valid_simple.ttl")

      assert {:ok, ontology} = Ontology.load_file(path, base_iri: "http://custom.org/ont#")
      assert ontology.base_iri == "http://custom.org/ont#"
    end
  end

  describe "load_file!/2 delegation" do
    test "returns result directly on success" do
      path = FixtureHelpers.fixture_path("valid_simple.ttl")

      ontology = Ontology.load_file!(path)
      assert ontology.path == Path.expand(path)
      assert is_map(ontology.graph)
    end

    test "raises on error" do
      assert_raise RuntimeError, fn ->
        Ontology.load_file!("nonexistent.ttl")
      end
    end

    test "accepts options and passes them through" do
      path = FixtureHelpers.fixture_path("valid_simple.ttl")

      ontology = Ontology.load_file!(path, base_iri: "http://custom.org/ont#")
      assert ontology.base_iri == "http://custom.org/ont#"
    end
  end

  describe "load_with_imports/2 delegation" do
    test "successfully loads ontology with imports" do
      path = FixtureHelpers.imports_fixture("root.ttl")

      assert {:ok, result} = Ontology.load_with_imports(path)
      assert is_map(result.dataset)
      assert is_map(result.ontologies)
      assert is_map(result.import_chain)
      assert map_size(result.ontologies) > 1
    end

    test "returns error for non-existent file" do
      assert {:error, :file_not_found} = Ontology.load_with_imports("nonexistent.ttl")
    end

    test "returns error for circular dependencies" do
      path = FixtureHelpers.cycles_fixture("cycle_a.ttl")

      assert {:error, {:circular_dependency, _trace}} = Ontology.load_with_imports(path)
    end

    test "accepts options and passes them through" do
      path = FixtureHelpers.imports_fixture("root.ttl")

      assert {:ok, result} = Ontology.load_with_imports(path, max_depth: 5)
      assert is_map(result.ontologies)
    end

    test "respects max_depth option" do
      path = FixtureHelpers.imports_fixture("root.ttl")

      assert {:error, {:max_depth_exceeded, 0}} = Ontology.load_with_imports(path, max_depth: 0)
    end
  end

  describe "load_with_imports!/2 delegation" do
    test "returns result directly on success" do
      path = FixtureHelpers.imports_fixture("root.ttl")

      result = Ontology.load_with_imports!(path)
      assert is_map(result.dataset)
      assert is_map(result.ontologies)
      assert is_map(result.import_chain)
    end

    test "raises on file not found" do
      assert_raise RuntimeError, fn ->
        Ontology.load_with_imports!("nonexistent.ttl")
      end
    end

    test "raises on circular dependency" do
      path = FixtureHelpers.cycles_fixture("cycle_a.ttl")

      assert_raise RuntimeError, fn ->
        Ontology.load_with_imports!(path)
      end
    end

    test "accepts options and passes them through" do
      path = FixtureHelpers.imports_fixture("root.ttl")

      result = Ontology.load_with_imports!(path, max_depth: 5)
      assert is_map(result.ontologies)
    end

    test "raises on max_depth exceeded" do
      path = FixtureHelpers.imports_fixture("root.ttl")

      assert_raise RuntimeError, fn ->
        Ontology.load_with_imports!(path, max_depth: 0)
      end
    end
  end
end
