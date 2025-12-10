defmodule OntoView.Ontology.LoaderTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Loader

  @fixtures_dir "test/support/fixtures/ontologies"

  describe "load_file/2" do
    test "successfully loads a valid Turtle file" do
      path = Path.join(@fixtures_dir, "valid_simple.ttl")

      assert {:ok, ontology} = Loader.load_file(path)
      assert ontology.path == Path.expand(path)
      assert is_binary(ontology.base_iri)
      assert is_map(ontology.prefix_map)
      assert %RDF.Graph{} = ontology.graph
      assert %DateTime{} = ontology.loaded_at
    end

    test "extracts base IRI from owl:Ontology declaration" do
      path = Path.join(@fixtures_dir, "valid_simple.ttl")

      assert {:ok, ontology} = Loader.load_file(path)
      assert ontology.base_iri == "http://example.org/elixir/core#"
    end

    test "extracts prefix mappings from Turtle @prefix declarations" do
      path = Path.join(@fixtures_dir, "custom_prefixes.ttl")

      assert {:ok, ontology} = Loader.load_file(path)
      assert Map.has_key?(ontology.prefix_map, "elixir")
      assert Map.has_key?(ontology.prefix_map, "owl")
      assert Map.has_key?(ontology.prefix_map, "custom")
    end

    test "returns error for non-existent file" do
      assert {:error, :file_not_found} = Loader.load_file("nonexistent.ttl")
    end

    test "returns error for malformed Turtle syntax" do
      path = Path.join(@fixtures_dir, "invalid_syntax.ttl")

      assert {:error, {error_type, message}} = Loader.load_file(path)
      assert error_type in [:parse_error, :io_error]
      assert is_binary(message)
    end

    test "handles empty Turtle file gracefully" do
      path = Path.join(@fixtures_dir, "empty.ttl")

      # Empty is valid, just logs warning
      assert {:ok, ontology} = Loader.load_file(path)
      assert RDF.Graph.triple_count(ontology.graph) == 0
    end

    test "generates default base IRI if none found" do
      path = Path.join(@fixtures_dir, "no_base_iri.ttl")

      assert {:ok, ontology} = Loader.load_file(path)
      assert ontology.base_iri =~ ~r/^http:\/\/example\.org\/ontology\/\d+$/
    end

    test "respects base_iri option override" do
      path = Path.join(@fixtures_dir, "valid_simple.ttl")
      custom_iri = "http://custom.example.org/ontology#"

      assert {:ok, ontology} = Loader.load_file(path, base_iri: custom_iri)
      assert ontology.base_iri == custom_iri
    end

    test "returns error for directory path" do
      assert {:error, {:not_a_file, _}} = Loader.load_file(@fixtures_dir)
    end

    test "warns but continues if file lacks .ttl extension" do
      # Create temporary file without .ttl extension
      tmp_path =
        Path.join(System.tmp_dir!(), "test_ontology_#{:erlang.unique_integer([:positive])}")

      source = Path.join(@fixtures_dir, "valid_simple.ttl")
      File.cp!(source, tmp_path)

      assert {:ok, _ontology} = Loader.load_file(tmp_path)

      File.rm!(tmp_path)
    end
  end

  describe "load_file!/2" do
    test "returns ontology on success" do
      path = Path.join(@fixtures_dir, "valid_simple.ttl")

      assert %{path: _, base_iri: _, prefix_map: _, graph: _, loaded_at: _} =
               Loader.load_file!(path)
    end

    test "raises on error" do
      assert_raise RuntimeError, fn ->
        Loader.load_file!("nonexistent.ttl")
      end
    end
  end

  describe "concurrent loading" do
    test "can load multiple files in parallel" do
      paths =
        [
          "valid_simple.ttl",
          "custom_prefixes.ttl",
          "no_base_iri.ttl"
        ]
        |> Enum.map(&Path.join(@fixtures_dir, &1))

      tasks =
        Enum.map(paths, fn path ->
          Task.async(fn -> Loader.load_file(path) end)
        end)

      results = Task.await_many(tasks)

      assert length(results) == 3
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end
  end

  describe "metadata extraction" do
    test "counts triples correctly" do
      path = Path.join(@fixtures_dir, "valid_simple.ttl")

      assert {:ok, ontology} = Loader.load_file(path)
      # valid_simple.ttl has 1 ontology + 2 classes + 1 subClassOf = at least 4 triples
      assert RDF.Graph.triple_count(ontology.graph) >= 4
    end

    test "extracts filename correctly" do
      path = Path.join(@fixtures_dir, "valid_simple.ttl")

      assert {:ok, ontology} = Loader.load_file(path)
      # Note: metadata.filename is not exposed in the public API yet
      # This would require updating the return structure
      assert ontology.path =~ ~r/valid_simple\.ttl$/
    end
  end
end
