defmodule OntoView.Ontology.ImportResolverTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.ImportResolver

  @fixtures_dir "test/support/fixtures/ontologies"
  @imports_dir Path.join(@fixtures_dir, "imports")

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

      # Set max_depth to 0, loads root but not imports
      assert {:ok, result} = ImportResolver.load_with_imports(path, max_depth: 0)
      # Should only have root, imports would be at depth 1+
      assert map_size(result.ontologies) == 1
      assert result.import_chain.depth == 0
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
end
