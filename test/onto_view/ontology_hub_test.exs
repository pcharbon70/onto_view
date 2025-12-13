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
end
