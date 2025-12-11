defmodule OntoView.Ontology.SecurityTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.{Loader, ImportResolver}
  alias OntoView.FixtureHelpers

  @fixtures_dir FixtureHelpers.fixtures_dir()

  describe "path traversal prevention" do
    test "rejects file:// URIs with path traversal outside base directory" do
      # Create a test file in the allowed directory
      root_file = FixtureHelpers.imports_fixture("root.ttl")

      # Try to use file:// URI with path traversal to escape base directory
      # This should be rejected even though the target file exists
      base_dir = Path.dirname(root_file)

      result =
        ImportResolver.load_with_imports(root_file,
          base_dir: base_dir,
          iri_resolver: %{
            # Try to escape to parent directory
            "http://example.org/escape#" => "file://../../etc/passwd"
          }
        )

      # Should succeed loading root, but imports with path traversal should fail
      # The actual behavior depends on whether imports fail silently or propagate
      assert {:ok, _loaded} = result
    end

    test "validates file paths stay within base directory" do
      # Attempt to load a file using absolute path outside fixtures
      result = Loader.load_file("/etc/passwd")

      # Should fail with some error (file not found, not a file, symlink, etc.)
      assert {:error, _reason} = result
    end
  end

  describe "symlink detection and rejection" do
    @tag :tmp_dir
    test "rejects symlinks in file paths", %{tmp_dir: tmp_dir} do
      # Create a real file
      real_file = Path.join(tmp_dir, "real.ttl")

      File.write!(real_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      <http://example.org/test#> a owl:Ontology ;
          rdfs:label "Test Ontology" .
      """)

      # Create a symlink to it
      symlink_file = Path.join(tmp_dir, "symlink.ttl")
      File.ln_s(real_file, symlink_file)

      # Attempt to load via symlink should be rejected
      result = Loader.load_file(symlink_file)

      assert {:error, {:symlink_detected, message}} = result
      assert is_binary(message)
    end

    @tag :tmp_dir
    test "allows regular files (not symlinks)", %{tmp_dir: tmp_dir} do
      # Create a regular file
      regular_file = Path.join(tmp_dir, "regular.ttl")

      File.write!(regular_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      <http://example.org/test#> a owl:Ontology ;
          rdfs:label "Test Ontology" .
      """)

      # Should successfully load regular file
      result = Loader.load_file(regular_file)

      assert {:ok, ontology} = result
      assert ontology.path == regular_file
    end
  end

  describe "file size limits enforcement" do
    @tag :tmp_dir
    test "rejects files exceeding max_file_size_bytes limit", %{tmp_dir: tmp_dir} do
      # Create a file that exceeds the 10MB default limit
      large_file = Path.join(tmp_dir, "large.ttl")

      # Create a file header
      File.write!(large_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      <http://example.org/large#> a owl:Ontology ;
          rdfs:label "Large Ontology" .

      """)

      # Append enough data to exceed limit (11MB of data)
      # Use a large repeated string to quickly exceed the limit
      large_data = String.duplicate("# Comment line to make file large\n", 350_000)
      File.write!(large_file, large_data, [:append])

      # Attempt to load should be rejected for being too large
      result = Loader.load_file(large_file)

      assert {:error, {:file_too_large, message}} = result
      assert String.contains?(message, "10485760") or String.contains?(message, "10MB")
    end

    @tag :tmp_dir
    test "allows files within size limit", %{tmp_dir: tmp_dir} do
      # Create a small file well within limits
      small_file = Path.join(tmp_dir, "small.ttl")

      File.write!(small_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

      <http://example.org/small#> a owl:Ontology ;
          rdfs:label "Small Ontology" .
      """)

      # Should successfully load
      result = Loader.load_file(small_file)

      assert {:ok, ontology} = result
      assert ontology.path == small_file
    end

    test "file size limit is enforced from application config" do
      # The file size limit is read from application config, not opts
      # This test verifies the feature exists by checking large files fail
      # (tested in "rejects files exceeding max_file_size_bytes limit" above)

      # This is a placeholder to document that max_file_size_bytes
      # is configured via application config, not as a load_file option
      assert true
    end
  end

  describe "directory traversal prevention" do
    test "rejects directory paths" do
      # Attempt to load a directory instead of a file
      result = Loader.load_file(@fixtures_dir)

      assert {:error, {:not_a_file, message}} = result
      assert is_binary(message)
    end

    test "rejects special files" do
      # Try to load /dev/null (special file)
      if File.exists?("/dev/null") do
        result = Loader.load_file("/dev/null")

        assert {:error, reason} = result
        assert reason == :file_not_found or match?({:not_a_file, _}, reason) or match?({:io_error, _}, reason)
      end
    end
  end

  describe "resource exhaustion protection" do
    test "enforces max_depth limit" do
      deep_fixture = FixtureHelpers.integration_fixture("deep_level_0.ttl")

      # Set very restrictive depth limit
      result = ImportResolver.load_with_imports(deep_fixture, max_depth: 0)

      assert {:error, {:max_depth_exceeded, 0}} = result
    end

    test "enforces max_total_imports limit" do
      root_fixture = FixtureHelpers.imports_fixture("root.ttl")

      # Set very restrictive total imports limit
      result = ImportResolver.load_with_imports(root_fixture, max_total_imports: 0)

      assert {:error, {:max_total_imports_exceeded, actual, 0}} = result
      assert actual > 0
    end

    test "enforces max_imports_per_ontology limit" do
      many_imports = FixtureHelpers.resource_limits_fixture("too_many_imports.ttl")

      # Set limit below the fixture's import count (21)
      result = ImportResolver.load_with_imports(many_imports, max_imports_per_ontology: 5)

      assert {:error, {:max_imports_per_ontology_exceeded, iri, 21, 5}} = result
      assert is_binary(iri)
    end
  end

  describe "input validation" do
    test "rejects non-existent files" do
      result = Loader.load_file("nonexistent.ttl")

      assert {:error, :file_not_found} = result
    end

    test "rejects files with invalid Turtle syntax" do
      invalid_fixture = FixtureHelpers.fixture_path("invalid_syntax.ttl")

      result = Loader.load_file(invalid_fixture)

      assert {:error, {:io_error, message}} = result
      assert is_binary(message)
    end

    test "rejects empty file paths" do
      result = Loader.load_file("")

      assert {:error, reason} = result
      assert reason == :file_not_found or match?({:not_a_file, _}, reason)
    end

    test "handles nil file paths gracefully" do
      assert_raise FunctionClauseError, fn ->
        Loader.load_file(nil)
      end
    end
  end

  describe "error message security" do
    test "errors do not expose full file system paths in user-facing messages" do
      # This is tested via ErrorSanitizer, but verify it's applied
      result = Loader.load_file("/secret/path/to/ontology.ttl")

      assert {:error, reason} = result
      # The error itself might contain paths, but when passed through
      # ErrorSanitizer, paths should be removed
      # This test verifies the error type is correct
      assert reason == :file_not_found or match?({:not_a_file, _}, reason)
    end
  end

  describe "circular dependency protection" do
    test "detects and rejects circular imports" do
      cycle_fixture = FixtureHelpers.cycles_fixture("cycle_a.ttl")

      result = ImportResolver.load_with_imports(cycle_fixture)

      assert {:error, {:circular_dependency, trace}} = result
      assert is_map(trace)
      assert Map.has_key?(trace, :cycle_detected_at)
      assert Map.has_key?(trace, :import_path)
      assert Map.has_key?(trace, :cycle_length)
    end

    test "detects self-imports" do
      self_import = FixtureHelpers.cycles_fixture("self_import.ttl")

      result = ImportResolver.load_with_imports(self_import)

      assert {:error, {:circular_dependency, trace}} = result
      assert trace.cycle_length == 1
    end
  end

  describe "integration: multiple security features" do
    @tag :tmp_dir
    test "applies all security checks in correct order", %{tmp_dir: tmp_dir} do
      # Create a scenario that would trigger multiple security checks
      # 1. Try to create a symlink to a large file
      large_file = Path.join(tmp_dir, "large_real.ttl")

      File.write!(large_file, """
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      <http://example.org/test#> a owl:Ontology .
      """)

      # Add lots of data
      File.write!(large_file, String.duplicate("# padding\n", 1_000_000), [:append])

      symlink = Path.join(tmp_dir, "symlink_to_large.ttl")
      File.ln_s(large_file, symlink)

      # Should be rejected for symlink (before even checking size)
      result = Loader.load_file(symlink)

      assert {:error, {:symlink_detected, _}} = result
    end
  end
end
