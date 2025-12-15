defmodule OntoView.Integration.CachePerformanceTest do
  use ExUnit.Case, async: false

  alias OntoView.OntologyHub

  # Task 0.99.2 — Cache Behavior Under Load
  #
  # These tests validate that the cache performs well under heavy concurrent
  # load, correctly evicts sets when reaching capacity, and can lazily reload
  # evicted sets.

  describe "Cache Performance Under Load (0.99.2)" do
    setup do
      # Configure 6 ontology sets to test cache limit (default: 5)
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "set_1",
          name: "Set 1",
          versions: [[version: "v1.0", root_path: "test/support/fixtures/ontologies/valid_simple.ttl"]],
          auto_load: false,
          priority: 1
        ],
        [
          set_id: "set_2",
          name: "Set 2",
          versions: [[version: "v1.0", root_path: "test/support/fixtures/ontologies/custom_prefixes.ttl"]],
          auto_load: false,
          priority: 2
        ],
        [
          set_id: "set_3",
          name: "Set 3",
          versions: [[version: "v1.0", root_path: "test/support/fixtures/ontologies/blank_nodes.ttl"]],
          auto_load: false,
          priority: 3
        ],
        [
          set_id: "set_4",
          name: "Set 4",
          versions: [[version: "v1.0", root_path: "test/support/fixtures/ontologies/valid_simple.ttl"]],
          auto_load: false,
          priority: 4
        ],
        [
          set_id: "set_5",
          name: "Set 5",
          versions: [[version: "v1.0", root_path: "test/support/fixtures/ontologies/custom_prefixes.ttl"]],
          auto_load: false,
          priority: 5
        ],
        [
          set_id: "set_6",
          name: "Set 6",
          versions: [[version: "v1.0", root_path: "test/support/fixtures/ontologies/blank_nodes.ttl"]],
          auto_load: false,
          priority: 6
        ]
      ])

      # Restart OntologyHub with default cache limit (5)
      :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
      {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

      :ok
    end

    test "0.99.2.1 - Simulate 100+ concurrent requests to same set (cache hit rate > 90%)" do
      # Load the set once to populate cache
      {:ok, _} = OntologyHub.get_set("set_1", "v1.0")

      # Get initial stats
      initial_stats = OntologyHub.get_stats()
      initial_hits = initial_stats.cache_hit_count
      initial_misses = initial_stats.cache_miss_count

      # Spawn 100 concurrent tasks accessing the same set
      tasks =
        1..100
        |> Enum.map(fn _ ->
          Task.async(fn ->
            OntologyHub.get_set("set_1", "v1.0")
          end)
        end)

      # Await all tasks
      results = Enum.map(tasks, &Task.await(&1, 10_000))

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, set} -> set.set_id == "set_1"
               _error -> false
             end)

      # Get final stats
      final_stats = OntologyHub.get_stats()
      new_hits = final_stats.cache_hit_count - initial_hits
      new_misses = final_stats.cache_miss_count - initial_misses

      # Calculate hit rate for this test
      total_accesses = new_hits + new_misses
      hit_rate = if total_accesses > 0, do: new_hits / total_accesses, else: 0.0

      # Verify cache hit rate > 90%
      assert hit_rate > 0.90,
             "Cache hit rate #{Float.round(hit_rate * 100, 2)}% is below 90% (hits: #{new_hits}, misses: #{new_misses})"

      # Should have 100 cache hits (all requests hit cache)
      assert new_hits == 100

      # Should have 0 cache misses (set was already loaded)
      assert new_misses == 0

      # Verify GenServer is still operational
      {:ok, set} = OntologyHub.get_set("set_1", "v1.0")
      assert set.set_id == "set_1"
    end

    test "0.99.2.2 - Trigger cache eviction by loading max_sets + 1" do
      # Default cache limit is 5
      # Load 5 sets to fill cache
      {:ok, _} = OntologyHub.get_set("set_1", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_2", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_3", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_4", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_5", "v1.0")

      # Verify cache is full
      stats_before = OntologyHub.get_stats()
      assert stats_before.loaded_count == 5
      assert stats_before.eviction_count == 0

      # Load 6th set - should trigger eviction of set_1 (LRU)
      {:ok, _} = OntologyHub.get_set("set_6", "v1.0")

      # Verify eviction occurred
      stats_after = OntologyHub.get_stats()
      assert stats_after.loaded_count == 5, "Cache should still have 5 sets"
      assert stats_after.eviction_count == 1, "Should have evicted 1 set"

      # Verify set_6 is now loaded
      {:ok, set6} = OntologyHub.get_set("set_6", "v1.0")
      assert set6.set_id == "set_6"
    end

    test "0.99.2.3 - Verify evicted set can be reloaded lazily" do
      # Load 5 sets to fill cache
      {:ok, _} = OntologyHub.get_set("set_1", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_2", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_3", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_4", "v1.0")
      Process.sleep(10)
      {:ok, _} = OntologyHub.get_set("set_5", "v1.0")

      stats_before_eviction = OntologyHub.get_stats()
      load_count_before = stats_before_eviction.load_count

      # Load 6th set - should evict set_1 (LRU)
      {:ok, _} = OntologyHub.get_set("set_6", "v1.0")

      stats_after_eviction = OntologyHub.get_stats()
      assert stats_after_eviction.eviction_count == 1

      # Try to access set_1 again - should reload it (lazy reload)
      {:ok, set1_reloaded} = OntologyHub.get_set("set_1", "v1.0")

      # Verify it was reloaded successfully
      assert set1_reloaded.set_id == "set_1"
      assert set1_reloaded.triple_store != nil
      assert set1_reloaded.version == "v1.0"

      # Verify load_count increased (indicates reload from disk)
      stats_after_reload = OntologyHub.get_stats()
      assert stats_after_reload.load_count > load_count_before

      # Cache should still be at limit
      assert stats_after_reload.loaded_count == 5

      # Another set should have been evicted to make room for set_1
      assert stats_after_reload.eviction_count == 2
    end

    test "cache handles sustained high load with multiple sets" do
      # Load initial 3 sets
      {:ok, _} = OntologyHub.get_set("set_1", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_2", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_3", "v1.0")

      initial_stats = OntologyHub.get_stats()

      # Simulate sustained load: 300 requests across 3 sets
      tasks =
        1..300
        |> Enum.map(fn i ->
          Task.async(fn ->
            set_id = "set_#{rem(i, 3) + 1}"
            OntologyHub.get_set(set_id, "v1.0")
          end)
        end)

      # Await all tasks
      results = Enum.map(tasks, &Task.await(&1, 15_000))

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _set} -> true
               _error -> false
             end)

      # Verify cache metrics
      final_stats = OntologyHub.get_stats()

      # Calculate hit rate for sustained load
      new_hits = final_stats.cache_hit_count - initial_stats.cache_hit_count
      new_misses = final_stats.cache_miss_count - initial_stats.cache_miss_count
      total_accesses = new_hits + new_misses

      hit_rate = if total_accesses > 0, do: new_hits / total_accesses, else: 0.0

      # With 3 pre-loaded sets, hit rate should be very high
      assert hit_rate > 0.95,
             "Hit rate #{Float.round(hit_rate * 100, 2)}% should be > 95% for pre-loaded sets"

      # Verify GenServer still operational
      assert final_stats.loaded_count <= 5
    end

    test "cache eviction respects LRU policy under load" do
      # Load 5 sets with delays to establish access order
      {:ok, _} = OntologyHub.get_set("set_1", "v1.0")
      Process.sleep(20)
      {:ok, _} = OntologyHub.get_set("set_2", "v1.0")
      Process.sleep(20)
      {:ok, _} = OntologyHub.get_set("set_3", "v1.0")
      Process.sleep(20)
      {:ok, _} = OntologyHub.get_set("set_4", "v1.0")
      Process.sleep(20)
      {:ok, _} = OntologyHub.get_set("set_5", "v1.0")

      # Access set_2, set_3, set_4, set_5 (not set_1)
      # This makes set_1 the least recently used
      {:ok, _} = OntologyHub.get_set("set_2", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_3", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_4", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_5", "v1.0")

      stats_before = OntologyHub.get_stats()
      load_count_before = stats_before.load_count

      # Load set_6 - should evict set_1 (LRU)
      {:ok, _} = OntologyHub.get_set("set_6", "v1.0")

      # Verify set_1 was evicted by trying to access it
      {:ok, _} = OntologyHub.get_set("set_1", "v1.0")

      stats_after = OntologyHub.get_stats()

      # load_count should have increased (set_1 was reloaded from disk)
      assert stats_after.load_count > load_count_before
    end

    test "cache performance remains stable over time" do
      # Pre-load 3 sets
      {:ok, _} = OntologyHub.get_set("set_1", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_2", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_3", "v1.0")

      # Run 5 rounds of 50 requests each
      hit_rates =
        1..5
        |> Enum.map(fn _round ->
          initial_stats = OntologyHub.get_stats()

          # 50 requests per round
          tasks =
            1..50
            |> Enum.map(fn i ->
              Task.async(fn ->
                set_id = "set_#{rem(i, 3) + 1}"
                OntologyHub.get_set(set_id, "v1.0")
              end)
            end)

          Enum.map(tasks, &Task.await(&1, 10_000))

          final_stats = OntologyHub.get_stats()
          new_hits = final_stats.cache_hit_count - initial_stats.cache_hit_count
          new_misses = final_stats.cache_miss_count - initial_stats.cache_miss_count
          total = new_hits + new_misses

          if total > 0, do: new_hits / total, else: 0.0
        end)

      # All rounds should have high hit rates
      assert Enum.all?(hit_rates, fn rate -> rate > 0.90 end),
             "All rounds should maintain >90% hit rate: #{inspect(hit_rates)}"

      # Hit rates should be stable (not degrading)
      first_rate = List.first(hit_rates)
      last_rate = List.last(hit_rates)
      assert last_rate >= first_rate * 0.95, "Performance should remain stable"
    end
  end
end
