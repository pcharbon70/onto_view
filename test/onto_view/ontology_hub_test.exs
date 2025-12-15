defmodule OntoView.OntologyHubTest do
  use ExUnit.Case, async: false

  alias OntoView.OntologyHub

  # Basic GenServer lifecycle tests for Task 0.1.99
  # More comprehensive tests will be added in Tasks 0.2.x and 0.3.x

  describe "GenServer lifecycle (0.1.99.1)" do
    test "starts successfully with empty config" do
      # Temporarily override config
      Application.put_env(:onto_view, :ontology_sets, [])

      assert {:ok, pid} = start_supervised(OntologyHub)
      assert Process.alive?(pid)
    end

    test "starts successfully with valid config" do
      config = [
        [
          set_id: "test",
          name: "Test Ontology",
          versions: [
            [version: "v1", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]
          ],
          auto_load: false  # Don't auto-load in tests
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      assert {:ok, pid} = start_supervised(OntologyHub)
      assert Process.alive?(pid)

      # Verify configurations were loaded
      sets = OntologyHub.list_sets()
      assert length(sets) == 1
      assert hd(sets).set_id == "test"
    end

    test "loads configurations on init" do
      config = [
        [
          set_id: "set1",
          name: "Set 1",
          versions: [[version: "v1", root_path: "test.ttl"]],
          priority: 1
        ],
        [
          set_id: "set2",
          name: "Set 2",
          versions: [[version: "v1", root_path: "test.ttl"]],
          priority: 2
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      start_supervised!(OntologyHub)
      sets = OntologyHub.list_sets()

      assert length(sets) == 2
      assert Enum.any?(sets, & &1.set_id == "set1")
      assert Enum.any?(sets, & &1.set_id == "set2")
    end
  end

  describe "Configuration loading (0.1.99.2)" do
    test "parses application config correctly" do
      config = [
        [
          set_id: "elixir",
          name: "Elixir Core Ontology",
          description: "Core concepts",
          homepage_url: "https://elixir-lang.org",
          versions: [
            [version: "v1.17", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]
          ],
          auto_load: true,
          priority: 1
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      start_supervised!(OntologyHub)
      sets = OntologyHub.list_sets()

      assert length(sets) == 1
      set = hd(sets)
      assert set.set_id == "elixir"
      assert set.name == "Elixir Core Ontology"
      assert set.description == "Core concepts"
      assert set.homepage_url == "https://elixir-lang.org"
      assert set.auto_load == true
      assert set.priority == 1
    end

    test "handles missing config gracefully" do
      Application.delete_env(:onto_view, :ontology_sets)

      assert {:ok, pid} = start_supervised(OntologyHub)
      assert Process.alive?(pid)

      sets = OntologyHub.list_sets()
      assert sets == []
    end

    test "validates all set configurations" do
      config = [
        [
          set_id: "test",
          name: "Test",
          versions: [[version: "v1", root_path: "test.ttl"]]
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      assert {:ok, _pid} = start_supervised(OntologyHub)
    end
  end

  describe "Auto-load functionality (0.1.99.3)" do
    test "auto-loads sets with auto_load: true after delay" do
      config = [
        [
          set_id: "auto_set",
          name: "Auto Load Set",
          versions: [
            [version: "v1", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]
          ],
          auto_load: true,
          priority: 1
        ],
        [
          set_id: "manual_set",
          name: "Manual Load Set",
          versions: [
            [version: "v1", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]
          ],
          auto_load: false,
          priority: 2
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      start_supervised!(OntologyHub)

      # Wait for auto-load to complete (1 second delay + processing time)
      Process.sleep(1500)

      # Check stats - auto_set should be loaded
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 1
      assert stats.load_count == 1
    end

    test "respects priority when auto-loading multiple sets" do
      config = [
        [
          set_id: "high_priority",
          name: "High Priority",
          versions: [[version: "v1", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]],
          auto_load: true,
          priority: 1
        ],
        [
          set_id: "low_priority",
          name: "Low Priority",
          versions: [[version: "v1", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]],
          auto_load: true,
          priority: 2
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      start_supervised!(OntologyHub)

      # Wait for auto-load
      Process.sleep(1500)

      stats = OntologyHub.get_stats()
      # Both should be loaded (cache limit default is 5)
      assert stats.loaded_count == 2
    end

    test "does not auto-load sets with auto_load: false" do
      config = [
        [
          set_id: "no_auto",
          name: "No Auto Load",
          versions: [[version: "v1", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]],
          auto_load: false
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      start_supervised!(OntologyHub)

      # Wait for potential auto-load
      Process.sleep(1500)

      stats = OntologyHub.get_stats()
      # Should not be loaded
      assert stats.loaded_count == 0
    end
  end

  describe "Error handling (0.1.99.4)" do
    test "GenServer remains operational after query errors" do
      Application.put_env(:onto_view, :ontology_sets, [])

      start_supervised!(OntologyHub)

      # Try to get non-existent set
      assert {:error, :set_not_found} = OntologyHub.get_set("nonexistent", "v1")

      # GenServer should still be operational
      assert OntologyHub.list_sets() == []
      assert {:error, :set_not_found} = OntologyHub.list_versions("nonexistent")
    end
  end

  describe "list_sets/0" do
    test "returns all configured sets" do
      config = [
        [set_id: "a", name: "A", versions: [[version: "v1", root_path: "test.ttl"]], priority: 2],
        [set_id: "b", name: "B", versions: [[version: "v1", root_path: "test.ttl"]], priority: 1]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      start_supervised!(OntologyHub)
      sets = OntologyHub.list_sets()

      assert length(sets) == 2
      # Should be sorted by priority
      assert hd(sets).set_id == "b"
    end
  end

  describe "list_versions/1" do
    test "lists versions for a set" do
      config = [
        [
          set_id: "test",
          name: "Test",
          versions: [
            [version: "v1", root_path: "test1.ttl"],
            [version: "v2", root_path: "test2.ttl", default: true]
          ]
        ]
      ]

      Application.put_env(:onto_view, :ontology_sets, config)

      start_supervised!(OntologyHub)
      assert {:ok, versions} = OntologyHub.list_versions("test")

      assert length(versions) == 2
      assert Enum.any?(versions, & &1.version == "v1")
      assert Enum.any?(versions, & &1.version == "v2")
      assert Enum.any?(versions, & &1.default)
    end

    test "returns error for unknown set" do
      Application.put_env(:onto_view, :ontology_sets, [])

      start_supervised!(OntologyHub)
      assert {:error, :set_not_found} = OntologyHub.list_versions("nonexistent")
    end
  end

  describe "get_stats/0" do
    test "returns cache statistics" do
      Application.put_env(:onto_view, :ontology_sets, [])

      start_supervised!(OntologyHub)
      stats = OntologyHub.get_stats()

      assert is_map(stats)
      assert stats.loaded_count == 0
      assert stats.cache_hit_count == 0
      assert stats.cache_miss_count == 0
      assert stats.cache_hit_rate == 0.0
      assert is_integer(stats.uptime_seconds)
    end
  end

  # Task 0.2.99 — Integration Tests: Loading & Querying
  describe "Loading & Querying Integration (0.2.99)" do
    setup do
      # Configure test ontology sets
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "test_set",
          name: "Test Ontology Set",
          description: "Integration test ontology",
          homepage_url: "http://example.org/test",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
              default: true
            ],
            [
              version: "v2.0",
              root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
              default: false
            ]
          ],
          auto_load: false,
          priority: 1
        ]
      ])

      # Restart OntologyHub
      :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
      {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

      :ok
    end

    test "0.2.99.1 - Load valid set successfully via get_set/2" do
      {:ok, ontology_set} = OntologyHub.get_set("test_set", "v1.0")

      assert ontology_set.set_id == "test_set"
      assert ontology_set.version == "v1.0"
      assert ontology_set.triple_store != nil
      assert is_map(ontology_set.ontologies)
      assert map_size(ontology_set.ontologies) > 0
    end

    test "0.2.99.2 - Handle load failures gracefully (missing file)" do
      # Configure set with non-existent file
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "broken_set",
          name: "Broken Set",
          versions: [[version: "v1.0", root_path: "nonexistent/file.ttl", default: true]],
          auto_load: false
        ]
      ])

      :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
      {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

      assert {:error, _reason} = OntologyHub.get_set("broken_set", "v1.0")

      # Verify GenServer is still operational
      assert Process.whereis(OntologyHub) != nil
    end

    test "0.2.99.3 - list_sets/0 returns accurate metadata" do
      sets = OntologyHub.list_sets()

      assert length(sets) == 1
      set = hd(sets)

      assert set.set_id == "test_set"
      assert set.name == "Test Ontology Set"
      assert set.description == "Integration test ontology"
      assert set.homepage_url == "http://example.org/test"
      assert length(set.versions) == 2
      assert set.default_version == "v1.0"
      assert set.priority == 1
    end

    test "0.2.99.4 - list_versions/1 shows loaded status correctly" do
      # Initially no versions loaded
      {:ok, versions} = OntologyHub.list_versions("test_set")
      assert length(versions) == 2

      v1 = Enum.find(versions, &(&1.version == "v1.0"))
      v2 = Enum.find(versions, &(&1.version == "v2.0"))

      assert v1.loaded == false
      assert v2.loaded == false

      # Load v1.0
      {:ok, _} = OntologyHub.get_set("test_set", "v1.0")

      # Check status again
      {:ok, versions_after} = OntologyHub.list_versions("test_set")
      v1_after = Enum.find(versions_after, &(&1.version == "v1.0"))
      v2_after = Enum.find(versions_after, &(&1.version == "v2.0"))

      assert v1_after.loaded == true
      assert v2_after.loaded == false
    end

    test "0.2.99.5 - reload_set/2 updates cached data" do
      # Load the set initially
      {:ok, set1} = OntologyHub.get_set("test_set", "v1.0")
      initial_load_time = set1.loaded_at

      # Wait a moment to ensure timestamp changes
      Process.sleep(10)

      # Reload the set
      assert :ok = OntologyHub.reload_set("test_set", "v1.0")

      # Get the set again to verify it was reloaded
      {:ok, set2} = OntologyHub.get_set("test_set", "v1.0")
      reloaded_time = set2.loaded_at

      # Verify it was reloaded (timestamp should be different)
      assert DateTime.compare(reloaded_time, initial_load_time) == :gt

      # Verify data is still correct
      assert set2.set_id == "test_set"
      assert set2.version == "v1.0"
      assert set2.triple_store != nil
    end

    test "0.2.99.6 - resolve_iri/1 finds IRIs in loaded sets" do
      # Load the set first
      {:ok, _} = OntologyHub.get_set("test_set", "v1.0")

      # Resolve an IRI that exists in the fixture
      iri = "http://example.org/elixir/core#Module"
      {:ok, result} = OntologyHub.resolve_iri(iri)

      assert result.iri == iri
      assert result.set_id == "test_set"
      assert result.version == "v1.0"
      assert result.entity_type == :class
    end

    test "0.2.99.7 - resolve_iri/1 returns error for unknown IRIs" do
      # Load the set first
      {:ok, _} = OntologyHub.get_set("test_set", "v1.0")

      # Try to resolve an IRI that doesn't exist
      iri = "http://example.org/nonexistent#Thing"
      assert {:error, :iri_not_found} = OntologyHub.resolve_iri(iri)
    end

    test "0.2.99.8 - resolve_iri/1 selects latest version for multi-version IRIs" do
      # Load both versions
      {:ok, _} = OntologyHub.get_set("test_set", "v1.0")
      {:ok, _} = OntologyHub.get_set("test_set", "v2.0")

      # Resolve an IRI - should get v2.0 (latest)
      iri = "http://example.org/elixir/core#Module"
      {:ok, result} = OntologyHub.resolve_iri(iri)

      assert result.version == "v2.0"
    end
  end
end
