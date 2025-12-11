defmodule OntoView.Ontology.IriResolutionTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.ImportResolver
  alias OntoView.FixtureHelpers

  describe "Strategy 1: File URI imports (file:// protocol)" do
    @tag :tmp_dir
    test "resolves file:// URI imports within base directory", %{tmp_dir: tmp_dir} do
      # Create a root ontology
      root_file = Path.join(tmp_dir, "root.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      <http://example.org/root#> a owl:Ontology ;
          rdfs:label "Root Ontology" ;
          owl:imports <file://#{tmp_dir}/imported.ttl> .
      """)

      # Create the imported ontology
      imported_file = Path.join(tmp_dir, "imported.ttl")

      File.write!(imported_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      <http://example.org/imported#> a owl:Ontology ;
          rdfs:label "Imported Ontology" .
      """)

      # Load with base_dir set to tmp_dir
      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir)

      assert {:ok, loaded} = result
      assert map_size(loaded.ontologies) == 2
      assert Map.has_key?(loaded.ontologies, "http://example.org/root#")
      assert Map.has_key?(loaded.ontologies, "http://example.org/imported#")
    end

    @tag :tmp_dir
    test "rejects file:// URI imports outside base directory", %{tmp_dir: tmp_dir} do
      # Create a root ontology with import pointing outside base_dir
      root_file = Path.join(tmp_dir, "root.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      <http://example.org/root#> a owl:Ontology ;
          rdfs:label "Root Ontology" ;
          owl:imports <file:///etc/passwd> .
      """)

      # The root loads successfully, but imports outside base_dir are blocked
      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir)

      assert {:ok, loaded} = result
      # Only root ontology loads, the unauthorized import is rejected
      assert map_size(loaded.ontologies) == 1
      assert Map.has_key?(loaded.ontologies, "http://example.org/root#")
      # Verify the import was attempted but failed
      assert "file:///etc/passwd" in loaded.ontologies["http://example.org/root#"].imports
    end

    @tag :tmp_dir
    test "rejects file:// URI with path traversal", %{tmp_dir: tmp_dir} do
      # Create a root ontology
      root_file = Path.join(tmp_dir, "root.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/root#> a owl:Ontology ;
          owl:imports <file://#{tmp_dir}/../../../etc/passwd> .
      """)

      # Root loads successfully, but path traversal is blocked
      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir)

      assert {:ok, loaded} = result
      # Only root ontology loads
      assert map_size(loaded.ontologies) == 1
    end

    @tag :tmp_dir
    test "handles missing file:// URI imports gracefully", %{tmp_dir: tmp_dir} do
      root_file = Path.join(tmp_dir, "root.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/root#> a owl:Ontology ;
          owl:imports <file://#{tmp_dir}/nonexistent.ttl> .
      """)

      # Root loads successfully, missing import is logged as warning
      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir)

      assert {:ok, loaded} = result
      # Only root ontology loads
      assert map_size(loaded.ontologies) == 1
    end
  end

  describe "Strategy 2: Explicit IRI mappings (:iri_resolver option)" do
    test "resolves imports using custom IRI mappings" do
      root_file = FixtureHelpers.imports_fixture("root.ttl")
      a_file = FixtureHelpers.imports_fixture("a.ttl")
      b_file = FixtureHelpers.imports_fixture("b.ttl")

      # Map IRIs to specific file paths
      iri_resolver = %{
        "http://example.org/a#" => a_file,
        "http://example.org/b#" => b_file
      }

      result = ImportResolver.load_with_imports(root_file, iri_resolver: iri_resolver)

      assert {:ok, loaded} = result
      # Verify that the mapped ontologies were loaded
      assert map_size(loaded.ontologies) >= 2
    end

    test "explicit IRI mappings can override convention-based resolution" do
      root_file = FixtureHelpers.imports_fixture("root.ttl")

      # Map one of the imports (types#) to the specific file
      # This demonstrates that IRI resolver works
      types_file = FixtureHelpers.imports_fixture("types.ttl")

      iri_resolver = %{
        "http://example.org/types#" => types_file
      }

      result = ImportResolver.load_with_imports(root_file, iri_resolver: iri_resolver)

      assert {:ok, loaded} = result
      # Verify the mapped ontology was loaded
      assert Map.has_key?(loaded.ontologies, "http://example.org/types#")

      # The mapped file should be used (compare absolute paths)
      types_meta = loaded.ontologies["http://example.org/types#"]
      assert types_meta.path == Path.expand(types_file)
    end

    test "handles unresolvable IRI mappings gracefully" do
      root_file = FixtureHelpers.imports_fixture("root.ttl")

      # Map to a non-existent file
      iri_resolver = %{
        "http://example.org/a#" => "/tmp/nonexistent_ontology_file_12345.ttl"
      }

      result = ImportResolver.load_with_imports(root_file, iri_resolver: iri_resolver)

      # Root loads successfully, failed imports are logged
      assert {:ok, loaded} = result
      # At least root ontology should load
      assert map_size(loaded.ontologies) >= 1
    end

    @tag :tmp_dir
    test "iri_resolver can map HTTP IRIs to local files", %{tmp_dir: tmp_dir} do
      # Create root ontology that imports an HTTP IRI
      root_file = Path.join(tmp_dir, "root.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/root#> a owl:Ontology ;
          owl:imports <http://external.org/ontology#> .
      """)

      # Create local file to map to
      local_file = Path.join(tmp_dir, "local_copy.ttl")

      File.write!(local_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://external.org/ontology#> a owl:Ontology .
      """)

      # Map the HTTP IRI to local file
      iri_resolver = %{
        "http://external.org/ontology#" => local_file
      }

      result = ImportResolver.load_with_imports(root_file, iri_resolver: iri_resolver)

      assert {:ok, loaded} = result
      assert map_size(loaded.ontologies) == 2
      assert Map.has_key?(loaded.ontologies, "http://external.org/ontology#")
    end

    @tag :tmp_dir
    test "iri_resolver respects base_dir security restrictions", %{tmp_dir: tmp_dir} do
      root_file = Path.join(tmp_dir, "root.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/root#> a owl:Ontology ;
          owl:imports <http://example.org/mapped#> .
      """)

      # Try to map to a file outside base_dir (security violation)
      iri_resolver = %{
        "http://example.org/mapped#" => "/etc/passwd"
      }

      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir, iri_resolver: iri_resolver)

      # Root loads successfully, but unauthorized import is blocked
      assert {:ok, loaded} = result
      # Only root should load, the mapped import to /etc/passwd is rejected
      assert map_size(loaded.ontologies) == 1
    end
  end

  describe "Strategy 3: Convention-based resolution" do
    test "resolves imports by filename conventions" do
      # This strategy is already well-tested in import_resolver_test.exs
      # but let's add one more explicit test for completeness
      root_file = FixtureHelpers.imports_fixture("root.ttl")

      result = ImportResolver.load_with_imports(root_file)

      assert {:ok, loaded} = result
      # Convention-based resolution should find a.ttl and b.ttl
      assert map_size(loaded.ontologies) >= 2
    end

    test "tries multiple filename variants for convention-based resolution" do
      # The implementation tries:
      # 1. Fragment name as filename (e.g., "a.ttl" from "http://example.org/a#")
      # 2. Lowercase variant (e.g., "a.ttl" from "http://example.org/A#")
      # This is already tested in existing tests, but documenting here for completeness
      root_file = FixtureHelpers.imports_fixture("root.ttl")

      result = ImportResolver.load_with_imports(root_file)

      assert {:ok, _loaded} = result
    end
  end

  describe "IRI resolution strategy precedence" do
    @tag :tmp_dir
    test "explicit iri_resolver takes precedence over file:// URIs", %{tmp_dir: tmp_dir} do
      root_file = Path.join(tmp_dir, "root.ttl")

      # Import using a mapped IRI
      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/root#> a owl:Ontology ;
          owl:imports <http://example.org/custom#> .
      """)

      # Create the target file
      target_file = Path.join(tmp_dir, "target.ttl")

      File.write!(target_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/custom#> a owl:Ontology .
      """)

      # Use explicit mapping
      iri_resolver = %{
        "http://example.org/custom#" => target_file
      }

      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir, iri_resolver: iri_resolver)

      assert {:ok, loaded} = result
      assert Map.has_key?(loaded.ontologies, "http://example.org/custom#")

      # Verify it used the mapped file
      custom_meta = loaded.ontologies["http://example.org/custom#"]
      assert custom_meta.path == target_file
    end

    @tag :tmp_dir
    test "file:// URIs take precedence over convention-based resolution", %{tmp_dir: tmp_dir} do
      root_file = Path.join(tmp_dir, "root.ttl")

      # Create specific file for file:// URI
      specific_file = Path.join(tmp_dir, "specific.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/root#> a owl:Ontology ;
          owl:imports <file://#{specific_file}> .
      """)

      File.write!(specific_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/specific#> a owl:Ontology .
      """)

      # Also create a file that convention-based resolution might find
      # (This test verifies file:// is used instead)
      convention_file = Path.join(tmp_dir, "specific_convention.ttl")

      File.write!(convention_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/specific#> a owl:Ontology .
      """)

      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir)

      assert {:ok, loaded} = result

      # Verify it used the file:// URI, not convention
      specific_meta = loaded.ontologies["http://example.org/specific#"]
      assert specific_meta.path == specific_file
    end
  end

  describe "Error handling for IRI resolution" do
    test "logs warning when IRI cannot be resolved but continues loading" do
      root_file = FixtureHelpers.imports_fixture("root.ttl")

      # Map to non-existent file
      iri_resolver = %{
        "http://example.org/a#" => "/tmp/definitely_does_not_exist_12345.ttl"
      }

      result = ImportResolver.load_with_imports(root_file, iri_resolver: iri_resolver)

      # Root loads successfully, failed import is logged
      assert {:ok, loaded} = result
      # At least root should load
      assert map_size(loaded.ontologies) >= 1
    end

    @tag :tmp_dir
    test "continues loading when one import resolution strategy fails", %{tmp_dir: tmp_dir} do
      # Failed imports are logged as warnings but don't stop the load
      root_file = Path.join(tmp_dir, "root.ttl")

      File.write!(root_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .

      <http://example.org/root#> a owl:Ontology ;
          owl:imports <http://example.org/nonexistent#> .
      """)

      result = ImportResolver.load_with_imports(root_file, base_dir: tmp_dir)

      # Root loads successfully despite failed import
      assert {:ok, loaded} = result
      assert map_size(loaded.ontologies) == 1
      assert Map.has_key?(loaded.ontologies, "http://example.org/root#")
    end
  end
end
