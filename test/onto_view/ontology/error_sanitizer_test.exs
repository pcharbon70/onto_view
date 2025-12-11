defmodule OntoView.Ontology.ErrorSanitizerTest do
  use ExUnit.Case, async: true
  doctest OntoView.Ontology.ErrorSanitizer

  alias OntoView.Ontology.ErrorSanitizer

  describe "sanitize_error/1" do
    test "passes through success tuples unchanged" do
      result = {:ok, %{some: :data}}
      assert ErrorSanitizer.sanitize_error(result) == result
    end

    test "sanitizes simple error atoms" do
      assert ErrorSanitizer.sanitize_error({:error, :file_not_found}) ==
               {:error, :file_not_found}
    end

    test "sanitizes unauthorized_path errors" do
      error = {:error, {:unauthorized_path, "File /opt/secrets/data.ttl outside allowed directory"}}

      result = ErrorSanitizer.sanitize_error(error)

      assert {:error, {:unauthorized_path, message}} = result
      assert message == "File path outside allowed directory"
      refute String.contains?(message, "/opt/secrets")
    end

    test "sanitizes symlink_detected errors" do
      error = {:error, {:symlink_detected, "Symlink at /home/user/link points to /etc/passwd"}}

      result = ErrorSanitizer.sanitize_error(error)

      assert {:error, {:symlink_detected, message}} = result
      refute String.contains?(message, "/home/user")
      refute String.contains?(message, "/etc/passwd")
    end

    test "sanitizes file_too_large errors with embedded paths" do
      error = {:error, {:file_too_large, "File /var/data/huge.ttl exceeds 10MB limit"}}

      result = ErrorSanitizer.sanitize_error(error)

      assert {:error, {:file_too_large, message}} = result
      refute String.contains?(message, "/var/data/huge.ttl")
      assert String.contains?(message, "[path]")
    end

    test "sanitizes not_a_file errors" do
      error = {:error, {:not_a_file, "Path /tmp/directory is a directory"}}

      result = ErrorSanitizer.sanitize_error(error)

      assert {:error, {:not_a_file, message}} = result
      assert message == "Path is not a regular file"
    end

    test "sanitizes io_error with embedded paths" do
      error = {:error, {:io_error, "Cannot read /secret/file.ttl: permission denied"}}

      result = ErrorSanitizer.sanitize_error(error)

      assert {:error, {:io_error, message}} = result
      refute String.contains?(message, "/secret/file.ttl")
    end
  end

  describe "sanitize_reason/1 - path removal" do
    test "removes absolute Unix paths" do
      reason = "Failed to load /opt/onto_view/data/ontology.ttl"

      result = ErrorSanitizer.sanitize_reason(reason)

      refute String.contains?(result, "/opt/onto_view")
      assert String.contains?(result, "[path]")
    end

    test "removes home directory paths" do
      reason = "Error in ~/projects/ontologies/test.ttl"

      result = ErrorSanitizer.sanitize_reason(reason)

      refute String.contains?(result, "~/projects")
      assert String.contains?(result, "[path]")
    end

    test "removes relative path traversal" do
      reason = "Attempted to access ../../etc/passwd"

      result = ErrorSanitizer.sanitize_reason(reason)

      refute String.contains?(result, "../../etc/passwd")
      assert String.contains?(result, "[path]")
    end

    test "removes multiple paths in same message" do
      reason = "Cannot copy /source/file.ttl to /dest/file.ttl"

      result = ErrorSanitizer.sanitize_reason(reason)

      refute String.contains?(result, "/source")
      refute String.contains?(result, "/dest")
      # Should have two [path] replacements
      assert String.match?(result, ~r/\[path\].*\[path\]/)
    end
  end

  describe "sanitize_reason/1 - error types" do
    test "preserves circular dependency traces" do
      trace = %{
        cycle_detected_at: "http://example.org/A#",
        import_path: ["http://example.org/A#", "http://example.org/B#"],
        cycle_length: 2,
        human_readable: "A → B → A"
      }

      result = ErrorSanitizer.sanitize_reason({:circular_dependency, trace})

      assert {:circular_dependency, ^trace} = result
    end

    test "preserves resource limit errors" do
      assert ErrorSanitizer.sanitize_reason({:max_depth_exceeded, 10}) ==
               {:max_depth_exceeded, 10}

      assert ErrorSanitizer.sanitize_reason({:max_total_imports_exceeded, 101, 100}) ==
               {:max_total_imports_exceeded, 101, 100}

      assert ErrorSanitizer.sanitize_reason({:max_imports_per_ontology_exceeded, "http://ex.org#", 25, 20}) ==
               {:max_imports_per_ontology_exceeded, "http://ex.org#", 25, 20}
    end

    test "preserves IRIs in iri_not_resolved errors" do
      # HTTP IRIs are safe - they're ontology content
      result = ErrorSanitizer.sanitize_reason({:iri_not_resolved, "http://example.org/ontology#"})

      assert {:iri_not_resolved, "http://example.org/ontology#"} = result
    end

    test "sanitizes file-like IRIs in iri_not_resolved errors" do
      # File-like IRIs should be sanitized
      result = ErrorSanitizer.sanitize_reason({:iri_not_resolved, "/opt/data/ontology.ttl"})

      assert {:iri_not_resolved, "IRI could not be resolved"} = result
    end
  end

  describe "looks_like_file_path?/1" do
    test "detects absolute paths" do
      assert_file_path_detected("/absolute/path")
      assert_file_path_detected("/")
      assert_file_path_detected("/opt/data")
    end

    test "detects home directory paths" do
      assert_file_path_detected("~/path")
      assert_file_path_detected("~user/path")
    end

    test "detects relative paths" do
      assert_file_path_detected("../parent")
      assert_file_path_detected("./current")
    end

    test "detects Windows paths" do
      assert_file_path_detected("C:\\Windows\\System32")
      assert_file_path_detected("\\\\network\\share")
    end

    test "does not detect URLs as paths" do
      refute_file_path_detected("http://example.org/ontology#")
      refute_file_path_detected("https://example.org/data")
      refute_file_path_detected("ftp://server.com/file")
    end

    test "does not detect URNs as paths" do
      refute_file_path_detected("urn:isbn:0-123-45678-9")
      refute_file_path_detected("urn:uuid:550e8400-e29b-41d4-a716-446655440000")
    end
  end

  describe "parse error sanitization" do
    test "sanitizes parse errors with paths in message" do
      error = {:parse_error, "Syntax error in /tmp/test.ttl at line 5"}

      result = ErrorSanitizer.sanitize_reason(error)

      assert {:parse_error, message} = result
      refute String.contains?(message, "/tmp/test.ttl")
    end

    test "sanitizes parse errors with map details" do
      error = {:parse_error, %{file: "/tmp/bad.ttl", line: 10, message: "Unexpected token"}}

      result = ErrorSanitizer.sanitize_reason(error)

      assert {:parse_error, details} = result
      assert is_map(details)
      refute String.contains?(details.file, "/tmp")
    end
  end

  describe "edge cases" do
    test "handles nil gracefully" do
      assert ErrorSanitizer.sanitize_error(nil) == nil
    end

    test "handles unknown error formats" do
      unknown = {:error, {:custom_error, :some, :data}}
      assert ErrorSanitizer.sanitize_error(unknown) == unknown
    end

    test "handles empty strings" do
      assert ErrorSanitizer.sanitize_reason("") == ""
    end

    test "handles messages with no paths" do
      message = "Invalid syntax: missing prefix declaration"
      assert ErrorSanitizer.sanitize_reason(message) == message
    end
  end

  # Helper functions
  defp assert_file_path_detected(path) do
    iri_error = {:iri_not_resolved, path}
    result = ErrorSanitizer.sanitize_reason(iri_error)
    assert {:iri_not_resolved, "IRI could not be resolved"} = result,
           "Expected #{path} to be detected as file path"
  end

  defp refute_file_path_detected(iri) do
    iri_error = {:iri_not_resolved, iri}
    result = ErrorSanitizer.sanitize_reason(iri_error)
    assert {:iri_not_resolved, ^iri} = result,
           "Expected #{iri} NOT to be detected as file path"
  end
end
