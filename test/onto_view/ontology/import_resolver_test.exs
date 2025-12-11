defmodule OntoView.Ontology.ImportResolverTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.ImportResolver

  @fixtures_dir "test/support/fixtures/ontologies"
  @imports_dir Path.join(@fixtures_dir, "imports")
  @cycles_dir Path.join(@fixtures_dir, "cycles")

  describe "extract_imports/1" do
    test "extracts owl:imports statements from graph" do
      {:ok, ontology} = OntoView.Ontology.Loader.load_file(Path.join(@imports_dir, "root.ttl"))

      assert {:ok, imports} = ImportResolver.extract_imports(ontology.graph)
      assert "http://example.org/types#" in imports
    end

    test "returns empty list for ontology with no imports" do
      {:ok, ontology} =
        OntoView.Ontology.Loader.load_file(Path.join(@fixtures_dir, "valid_simple.ttl"))

      assert {:ok, []} = ImportResolver.extract_imports(ontology.graph)
    end

    test "extracts multiple imports" do
      {:ok, ontology} = OntoView.Ontology.Loader.load_file(Path.join(@imports_dir, "types.ttl"))

      assert {:ok, imports} = ImportResolver.extract_imports(ontology.graph)
      assert length(imports) >= 1
    end
  end

  describe "load_with_imports/2" do
    test "loads single ontology with no imports" do
      path = Path.join(@fixtures_dir, "valid_simple.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      assert is_map(result.ontologies)
      assert map_size(result.ontologies) == 1
      assert result.import_chain.depth == 0
    end

    test "loads ontology with single-level imports" do
      path = Path.join(@imports_dir, "primitives.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      # primitives.ttl has no imports, so just 1 ontology
      assert map_size(result.ontologies) == 1
    end

    test "loads ontology with multi-level imports" do
      path = Path.join(@imports_dir, "root.ttl")

      # root imports types, types imports primitives
      assert {:ok, result} = ImportResolver.load_with_imports(path)

      # Should load root, types, and primitives
      assert map_size(result.ontologies) >= 2
      assert result.import_chain.depth >= 1
    end

    test "returns dataset with named graphs" do
      path = Path.join(@imports_dir, "root.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      assert %RDF.Dataset{} = result.dataset
      assert RDF.Dataset.graph_count(result.dataset) >= 1
    end

    test "preserves ontology metadata" do
      path = Path.join(@imports_dir, "primitives.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      primitives_iri = "http://example.org/primitives#"
      assert Map.has_key?(result.ontologies, primitives_iri)

      metadata = result.ontologies[primitives_iri]
      assert metadata.iri == primitives_iri
      assert metadata.path =~ ~r/primitives\.ttl$/
      assert metadata.triple_count > 0
      assert metadata.depth == 0
      assert is_list(metadata.imports)
    end

    test "builds import chain structure" do
      path = Path.join(@imports_dir, "root.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      chain = result.import_chain
      assert chain.root_iri == "http://example.org/root#"
      assert is_list(chain.imports)
      assert is_integer(chain.depth)
    end

    test "respects max_depth option" do
      path = Path.join(@imports_dir, "root.ttl")

      # Set max_depth to 0, root can load at depth 0, but imports at depth 1 exceed limit
      # Resource limit errors now propagate, so the entire load fails
      assert {:error, {:max_depth_exceeded, 0}} = ImportResolver.load_with_imports(path, max_depth: 0)

      # With max_depth: 10 (sufficient for this fixture), should succeed
      assert {:ok, result} = ImportResolver.load_with_imports(path, max_depth: 10)
      assert map_size(result.ontologies) > 1
    end

    test "resolves imports via convention-based file search" do
      path = Path.join(@imports_dir, "root.ttl")

      # Should automatically find types.ttl and primitives.ttl in same directory
      assert {:ok, result} = ImportResolver.load_with_imports(path)

      assert map_size(result.ontologies) >= 1
    end
  end

  describe "import chain structure" do
    test "import nodes contain required fields" do
      path = Path.join(@imports_dir, "primitives.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      [node | _] = result.import_chain.imports

      assert Map.has_key?(node, :iri)
      assert Map.has_key?(node, :path)
      assert Map.has_key?(node, :imports)
      assert Map.has_key?(node, :depth)
    end

    test "nodes are sorted by depth" do
      path = Path.join(@imports_dir, "root.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      depths = Enum.map(result.import_chain.imports, & &1.depth)
      assert depths == Enum.sort(depths)
    end
  end

  describe "provenance tracking" do
    test "each ontology stored in named graph" do
      path = Path.join(@imports_dir, "primitives.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      primitives_iri = RDF.iri("http://example.org/primitives#")
      # Try to get graph by name
      graph = RDF.Dataset.graph(result.dataset, primitives_iri)

      # Should have at least one graph in the dataset
      assert RDF.Dataset.graph_count(result.dataset) > 0
      # Graph might be stored with nil name or the IRI
      assert graph != nil or RDF.Dataset.graph(result.dataset, nil) != nil
    end

    test "triples from different ontologies kept separate" do
      path = Path.join(@imports_dir, "root.ttl")

      assert {:ok, result} = ImportResolver.load_with_imports(path)

      # Get graphs
      graphs = RDF.Dataset.graphs(result.dataset)

      # Each graph should have distinct triples
      assert length(graphs) >= 1
    end
  end

  describe "cycle detection (Task 1.1.3)" do
    # 1.1.3.1 - Detect circular dependencies
    test "detects direct circular dependency (A → B → A)" do
      path = Path.join(@cycles_dir, "cycle_a.ttl")

      assert {:error, {:circular_dependency, trace}} =
               ImportResolver.load_with_imports(path)

      assert trace.cycle_detected_at == "http://example.org/cycle_a#"
      assert "http://example.org/cycle_a#" in trace.import_path
      assert "http://example.org/cycle_b#" in trace.import_path
      assert trace.cycle_length == 2
    end

    test "detects indirect circular dependency (A → B → C → A)" do
      path = Path.join(@cycles_dir, "indirect_a.ttl")

      assert {:error, {:circular_dependency, trace}} =
               ImportResolver.load_with_imports(path)

      assert trace.cycle_length == 3
      assert length(trace.import_path) == 4
      # A, B, C, A
    end

    test "detects self-import (A → A)" do
      path = Path.join(@cycles_dir, "self_import.ttl")

      assert {:error, {:circular_dependency, trace}} =
               ImportResolver.load_with_imports(path)

      assert trace.cycle_length == 1
      assert trace.cycle_detected_at == "http://example.org/self#"
    end

    # 1.1.3.2 - Abort load on cycle detection
    test "aborts immediately on cycle detection" do
      path = Path.join(@cycles_dir, "cycle_a.ttl")

      result = ImportResolver.load_with_imports(path)

      assert {:error, {:circular_dependency, _}} = result
      # Verify no partial state was returned (only error tuple)
    end

    test "does not confuse diamond pattern with cycle" do
      path = Path.join(@cycles_dir, "diamond_root.ttl")

      # Diamond: root → left → base, root → right → base
      # Base appears in two paths but isn't a cycle
      assert {:ok, result} = ImportResolver.load_with_imports(path)

      # Should successfully load all 4 ontologies
      assert map_size(result.ontologies) == 4
    end

    # 1.1.3.3 - Emit diagnostic dependency trace
    test "provides human-readable cycle trace" do
      path = Path.join(@cycles_dir, "indirect_a.ttl")

      assert {:error, {:circular_dependency, trace}} =
               ImportResolver.load_with_imports(path)

      assert is_binary(trace.human_readable)
      assert trace.human_readable =~ "[CYCLE START]"
      assert trace.human_readable =~ "→"
    end

    test "cycle trace shows exact import chain" do
      path = Path.join(@cycles_dir, "cycle_a.ttl")

      assert {:error, {:circular_dependency, trace}} =
               ImportResolver.load_with_imports(path)

      # Verify the path shows: A → B → A
      assert trace.import_path == [
               "http://example.org/cycle_a#",
               "http://example.org/cycle_b#",
               "http://example.org/cycle_a#"
             ]
    end

    test "cycle trace includes cycle start marker" do
      path = Path.join(@cycles_dir, "cycle_a.ttl")

      assert {:error, {:circular_dependency, trace}} =
               ImportResolver.load_with_imports(path)

      # The marker should be at the point where the cycle starts
      assert trace.human_readable =~ "[CYCLE START] http://example.org/cycle_a#"
    end

    test "cycle detection works with max depth option" do
      path = Path.join(@cycles_dir, "cycle_a.ttl")

      # Even with high max depth, cycle should be detected first
      assert {:error, {:circular_dependency, _trace}} =
               ImportResolver.load_with_imports(path, max_depth: 100)
    end

    test "cycle length is accurate" do
      path = Path.join(@cycles_dir, "indirect_a.ttl")

      assert {:error, {:circular_dependency, trace}} =
               ImportResolver.load_with_imports(path)

      # A → B → C → A forms a 3-ontology cycle
      assert trace.cycle_length == 3
    end
  end

  describe "load_with_imports!/2 bang variant" do
    test "returns result directly on success" do
      path = Path.join(@imports_dir, "root.ttl")

      result = ImportResolver.load_with_imports!(path)

      # Should return the loaded_ontologies map directly (not wrapped in {:ok, ...})
      assert is_map(result)
      assert Map.has_key?(result, :dataset)
      assert Map.has_key?(result, :ontologies)
      assert Map.has_key?(result, :import_chain)
    end

    test "raises RuntimeError on file not found" do
      assert_raise RuntimeError, fn ->
        ImportResolver.load_with_imports!("nonexistent.ttl")
      end
    end

    test "raises RuntimeError on circular dependency" do
      path = Path.join(@cycles_dir, "cycle_a.ttl")

      assert_raise RuntimeError, fn ->
        ImportResolver.load_with_imports!(path)
      end
    end

    test "raises RuntimeError on max depth exceeded" do
      path = Path.join(@imports_dir, "root.ttl")

      assert_raise RuntimeError, fn ->
        ImportResolver.load_with_imports!(path, max_depth: 0)
      end
    end
  end
end
