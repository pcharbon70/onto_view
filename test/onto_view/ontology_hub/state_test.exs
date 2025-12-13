defmodule OntoView.OntologyHub.StateTest do
  use ExUnit.Case, async: true

  alias OntoView.OntologyHub.{State, SetConfiguration, OntologySet}

  doctest State

  defp sample_config do
    SetConfiguration.from_config!([
      set_id: "test",
      name: "Test",
      versions: [[version: "v1", root_path: "test.ttl"]]
    ])
  end

  defp sample_ontology_set do
    %OntologySet{
      set_id: "test",
      version: "v1",
      triple_store: %OntoView.Ontology.TripleStore{},
      ontologies: %{},
      stats: %{triple_count: 100, ontology_count: 1, class_count: nil, property_count: nil, individual_count: nil},
      loaded_at: DateTime.utc_now(),
      last_accessed: DateTime.utc_now(),
      access_count: 0
    }
  end

  describe "new/2" do
    test "initializes with configurations" do
      configs = [sample_config()]
      state = State.new(configs)

      assert map_size(state.configurations) == 1
      assert state.configurations["test"] == hd(configs)
    end

    test "sets default cache strategy and limit" do
      state = State.new([])

      assert state.cache_strategy == :lru
      assert state.cache_limit == 5
    end

    test "accepts custom cache options" do
      state = State.new([], cache_strategy: :lfu, cache_limit: 10)

      assert state.cache_strategy == :lfu
      assert state.cache_limit == 10
    end

    test "initializes metrics with start timestamp" do
      state = State.new([])

      assert state.metrics.cache_hit_count == 0
      assert state.metrics.cache_miss_count == 0
      assert state.metrics.load_count == 0
      assert state.metrics.eviction_count == 0
      assert is_struct(state.metrics.started_at, DateTime)
    end
  end

  describe "record_cache_hit/3" do
    test "increments cache hit count" do
      set = sample_ontology_set()
      state = %State{
        loaded_sets: %{{"test", "v1"} => set},
        metrics: %{cache_hit_count: 5, cache_miss_count: 2, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}
      }

      updated = State.record_cache_hit(state, "test", "v1")
      assert updated.metrics.cache_hit_count == 6
    end

    test "updates set access metadata" do
      set = sample_ontology_set()
      state = %State{
        loaded_sets: %{{"test", "v1"} => set},
        metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}
      }

      updated = State.record_cache_hit(state, "test", "v1")
      updated_set = updated.loaded_sets[{"test", "v1"}]

      assert updated_set.access_count == 1
    end
  end

  describe "record_cache_miss/1" do
    test "increments cache miss count" do
      state = %State{
        metrics: %{cache_hit_count: 10, cache_miss_count: 2, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}
      }

      updated = State.record_cache_miss(state)
      assert updated.metrics.cache_miss_count == 3
    end
  end

  describe "record_load/1" do
    test "increments load count" do
      state = %State{
        metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 5, eviction_count: 0, started_at: DateTime.utc_now()}
      }

      updated = State.record_load(state)
      assert updated.metrics.load_count == 6
    end
  end

  describe "record_eviction/1" do
    test "increments eviction count" do
      state = %State{
        metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 0, eviction_count: 3, started_at: DateTime.utc_now()}
      }

      updated = State.record_eviction(state)
      assert updated.metrics.eviction_count == 4
    end
  end

  describe "add_loaded_set/2" do
    test "adds set to loaded_sets" do
      state = %State{cache_limit: 5, loaded_sets: %{}}
      set = sample_ontology_set()

      updated = State.add_loaded_set(state, set)

      assert map_size(updated.loaded_sets) == 1
      assert updated.loaded_sets[{"test", "v1"}] == set
    end

    test "evicts when at capacity" do
      # Create state with 2 sets at capacity (limit: 2)
      set1 = %{sample_ontology_set() | set_id: "set1", version: "v1", access_count: 5}
      set2 = %{sample_ontology_set() | set_id: "set2", version: "v1", access_count: 10}

      state = %State{
        cache_limit: 2,
        cache_strategy: :lfu,
        loaded_sets: %{
          {"set1", "v1"} => set1,
          {"set2", "v1"} => set2
        },
        metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}
      }

      # Add third set (should evict set1 with lower access count)
      set3 = %{sample_ontology_set() | set_id: "set3", version: "v1"}
      updated = State.add_loaded_set(state, set3)

      assert map_size(updated.loaded_sets) == 2
      assert updated.loaded_sets[{"set3", "v1"}] == set3
      assert updated.loaded_sets[{"set2", "v1"}] == set2
      refute Map.has_key?(updated.loaded_sets, {"set1", "v1"})
      assert updated.metrics.eviction_count == 1
    end
  end

  describe "remove_set/3" do
    test "removes set from cache" do
      set = sample_ontology_set()
      state = %State{loaded_sets: %{{"test", "v1"} => set}}

      updated = State.remove_set(state, "test", "v1")
      assert map_size(updated.loaded_sets) == 0
    end
  end

  describe "cache_hit_rate/1" do
    test "computes correct hit rate" do
      state = %State{
        metrics: %{cache_hit_count: 87, cache_miss_count: 13, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}
      }

      assert State.cache_hit_rate(state) == 0.87
    end

    test "returns 0.0 for no accesses" do
      state = %State{
        metrics: %{cache_hit_count: 0, cache_miss_count: 0, load_count: 0, eviction_count: 0, started_at: DateTime.utc_now()}
      }

      assert State.cache_hit_rate(state) == 0.0
    end
  end

  describe "loaded_count/1" do
    test "returns number of loaded sets" do
      set1 = %{sample_ontology_set() | set_id: "a"}
      set2 = %{sample_ontology_set() | set_id: "b"}

      state = %State{
        loaded_sets: %{
          {"a", "v1"} => set1,
          {"b", "v2"} => set2
        }
      }

      assert State.loaded_count(state) == 2
    end

    test "returns 0 for empty cache" do
      state = %State{loaded_sets: %{}}
      assert State.loaded_count(state) == 0
    end
  end
end
