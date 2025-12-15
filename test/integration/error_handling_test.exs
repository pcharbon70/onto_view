defmodule OntoView.Integration.ErrorHandlingTest do
  use OntoViewWeb.ConnCase, async: false

  alias OntoView.OntologyHub
  alias Phoenix.Flash

  # Task 0.99.4 — Error Handling & Recovery
  #
  # These tests validate that the system handles errors gracefully without
  # crashing the GenServer, provides appropriate error messages to users,
  # and remains operational after encountering various error conditions.

  describe "Error Handling & Recovery (0.99.4)" do
    setup do
      # Configure ontology sets including one with invalid TTL file
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "error_test_valid",
          name: "Valid Test Set",
          description: "Valid ontology for error handling tests",
          homepage_url: "http://example.org/valid",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
              default: true
            ]
          ],
          auto_load: false,
          priority: 1
        ],
        [
          set_id: "error_test_invalid",
          name: "Invalid Test Set",
          description: "Invalid ontology for error handling tests",
          homepage_url: "http://example.org/invalid",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/invalid_syntax.ttl",
              default: true
            ]
          ],
          auto_load: false,
          priority: 2
        ],
        [
          set_id: "error_test_missing",
          name: "Missing File Test Set",
          description: "Set with non-existent TTL file",
          homepage_url: "http://example.org/missing",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/nonexistent_file.ttl",
              default: true
            ]
          ],
          auto_load: false,
          priority: 3
        ]
      ])

      # Restart OntologyHub with test configuration
      :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
      {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

      :ok
    end

    test "0.99.4.1 - Invalid set_id returns 404 redirect", %{conn: conn} do
      # Try to access non-existent set via set browser
      conn = get(conn, "/sets/totally_nonexistent_set")
      assert redirected_to(conn, 302) == "/sets"
      assert Flash.get(conn.assigns.flash, :error) =~ "Ontology set 'totally_nonexistent_set' not found"

      # Try to access non-existent set via docs route
      conn = get(build_conn(), "/sets/another_fake_set/v1.0/docs")
      assert redirected_to(conn, 302) == "/sets"
      assert Flash.get(conn.assigns.flash, :error) =~ "Ontology set 'another_fake_set' not found"

      # Verify GenServer is still operational
      sets = OntologyHub.list_sets()
      assert is_list(sets)
      stats = OntologyHub.get_stats()
      assert stats != nil
    end

    test "0.99.4.2 - Invalid version returns 404 redirect", %{conn: conn} do
      # Try to access non-existent version of valid set
      conn = get(conn, "/sets/error_test_valid/v999.0/docs")
      assert redirected_to(conn, 302) == "/sets/error_test_valid"
      assert Flash.get(conn.assigns.flash, :error) =~ "Version 'v999.0' not found"

      # Try another invalid version format
      conn = get(build_conn(), "/sets/error_test_valid/invalid_version/docs")
      assert redirected_to(conn, 302) == "/sets/error_test_valid"
      assert Flash.get(conn.assigns.flash, :error) =~ "Version 'invalid_version' not found"

      # Verify GenServer is still operational
      sets = OntologyHub.list_sets()
      assert is_list(sets)
      stats = OntologyHub.get_stats()
      assert stats != nil
    end

    test "0.99.4.3 - Corrupted TTL file doesn't crash GenServer", %{conn: conn} do
      # Verify GenServer is operational before attempting to load corrupted file
      initial_stats = OntologyHub.get_stats()
      assert initial_stats != nil

      # Try to load set with corrupted TTL file
      result = OntologyHub.get_set("error_test_invalid", "v1.0")

      # Should return error, not crash
      assert {:error, _reason} = result

      # Verify GenServer is still alive and operational
      final_stats = OntologyHub.get_stats()
      assert final_stats != nil

      # Should be able to make more requests
      sets = OntologyHub.list_sets()
      assert length(sets) > 0

      # Verify via web route
      conn = get(conn, "/sets/error_test_invalid/v1.0/docs")
      # Should redirect with error, not crash
      assert redirected_to(conn, 302) =~ "/sets"
    end

    test "0.99.4.4 - GenServer remains operational after load failures", %{conn: conn} do
      # Get initial stats
      initial_stats = OntologyHub.get_stats()
      assert initial_stats != nil

      # Attempt multiple failing operations
      {:error, _} = OntologyHub.get_set("error_test_invalid", "v1.0")
      {:error, _} = OntologyHub.get_set("error_test_missing", "v1.0")
      {:error, _} = OntologyHub.get_set("nonexistent_set", "v1.0")

      # GenServer should still be operational
      stats_after_failures = OntologyHub.get_stats()
      assert stats_after_failures != nil

      # Should be able to list sets
      sets = OntologyHub.list_sets()
      assert is_list(sets)
      assert length(sets) == 3  # 3 configured sets

      # Should be able to list versions
      {:ok, versions} = OntologyHub.list_versions("error_test_valid")
      assert is_list(versions)
      assert length(versions) == 1

      # Should be able to successfully load valid set
      {:ok, valid_set} = OntologyHub.get_set("error_test_valid", "v1.0")
      assert valid_set.set_id == "error_test_valid"
      assert valid_set.version == "v1.0"
      assert valid_set.triple_store != nil

      # Verify web routes still work
      conn = get(conn, "/sets")
      assert html_response(conn, 200) =~ "Valid Test Set"

      conn = get(conn, "/sets/error_test_valid/v1.0/docs")
      assert html_response(conn, 200) =~ "error_test_valid"
    end

    test "successive failures don't accumulate broken state", %{conn: conn} do
      # Attempt to load invalid set multiple times
      for _ <- 1..5 do
        result = OntologyHub.get_set("error_test_invalid", "v1.0")
        assert {:error, _} = result
      end

      # GenServer should still be responsive
      stats = OntologyHub.get_stats()
      assert stats != nil

      # Should not have loaded any invalid sets into cache
      assert stats.loaded_count == 0

      # Load a valid set
      {:ok, _valid_set} = OntologyHub.get_set("error_test_valid", "v1.0")

      # Should have exactly 1 loaded set
      stats_after_valid = OntologyHub.get_stats()
      assert stats_after_valid.loaded_count == 1

      # Web interface should still work
      conn = get(conn, "/sets/error_test_valid/v1.0/docs")
      assert html_response(conn, 200)
    end

    test "missing file doesn't crash GenServer", %{conn: conn} do
      # Try to load set with missing TTL file
      result = OntologyHub.get_set("error_test_missing", "v1.0")
      assert {:error, _reason} = result

      # GenServer should still be operational
      stats = OntologyHub.get_stats()
      assert stats != nil

      # Should be able to list sets (config still valid)
      sets = OntologyHub.list_sets()
      set_ids = Enum.map(sets, & &1.set_id)
      assert "error_test_missing" in set_ids

      # But trying to load it should consistently fail
      result2 = OntologyHub.get_set("error_test_missing", "v1.0")
      assert {:error, _} = result2

      # Web route should handle error gracefully
      conn = get(conn, "/sets/error_test_missing/v1.0/docs")
      assert redirected_to(conn, 302) =~ "/sets"
    end

    test "error in one set doesn't affect other sets", %{conn: conn} do
      # Load valid set first
      {:ok, valid_set1} = OntologyHub.get_set("error_test_valid", "v1.0")
      assert valid_set1.set_id == "error_test_valid"

      # Try to load invalid set (should fail)
      {:error, _} = OntologyHub.get_set("error_test_invalid", "v1.0")

      # Valid set should still be accessible (cache hit)
      {:ok, valid_set2} = OntologyHub.get_set("error_test_valid", "v1.0")
      assert valid_set2.set_id == "error_test_valid"
      assert valid_set2.triple_store != nil

      # Verify cache stats
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 1  # Only valid set loaded
      assert stats.cache_hit_count >= 1  # Second access hit cache

      # Web interface for valid set should work
      conn = get(conn, "/sets/error_test_valid/v1.0/docs")
      assert html_response(conn, 200) =~ "error_test_valid"
    end

    test "GenServer continues to handle requests during error", %{conn: conn} do
      # Spawn concurrent tasks: some valid, some invalid
      tasks =
        1..10
        |> Enum.map(fn i ->
          Task.async(fn ->
            if rem(i, 2) == 0 do
              # Even numbers: load valid set
              OntologyHub.get_set("error_test_valid", "v1.0")
            else
              # Odd numbers: try to load invalid set
              OntologyHub.get_set("error_test_invalid", "v1.0")
            end
          end)
        end)

      # Await all tasks
      results = Enum.map(tasks, &Task.await(&1, 10_000))

      # Should have 5 successes (even numbers)
      successes = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successes) == 5

      # Should have 5 failures (odd numbers)
      failures = Enum.filter(results, &match?({:error, _}, &1))
      assert length(failures) == 5

      # GenServer should still be operational
      stats = OntologyHub.get_stats()
      assert stats != nil
      assert stats.loaded_count == 1  # Only valid set loaded

      # Web interface should still work
      conn = get(conn, "/sets")
      assert html_response(conn, 200)
    end

    test "reload fails gracefully for invalid sets", %{conn: _conn} do
      # Can't reload a set that never loaded successfully
      result = OntologyHub.reload_set("error_test_invalid", "v1.0")

      # Should return error (set not loaded, can't reload)
      assert {:error, _} = result

      # GenServer should still be operational
      stats = OntologyHub.get_stats()
      assert stats != nil

      # Should be able to reload a valid set
      {:ok, _} = OntologyHub.get_set("error_test_valid", "v1.0")
      result2 = OntologyHub.reload_set("error_test_valid", "v1.0")
      assert :ok == result2
    end
  end
end
