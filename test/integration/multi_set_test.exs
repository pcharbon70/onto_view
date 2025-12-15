defmodule OntoView.Integration.MultiSetTest do
  use ExUnit.Case, async: false

  alias OntoView.OntologyHub

  # Task 0.99.1 — Multi-Set Loading Validation
  #
  # These tests validate that the OntologyHub can load and manage multiple
  # independent ontology sets concurrently without interference.

  describe "Multi-Set Loading (0.99.1)" do
    setup do
      # Configure 3 different ontology sets using available fixtures
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "set_alpha",
          name: "Alpha Ontology Set",
          description: "First test ontology set",
          homepage_url: "http://example.org/alpha",
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
          set_id: "set_beta",
          name: "Beta Ontology Set",
          description: "Second test ontology set",
          homepage_url: "http://example.org/beta",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/custom_prefixes.ttl",
              default: true
            ]
          ],
          auto_load: false,
          priority: 2
        ],
        [
          set_id: "set_gamma",
          name: "Gamma Ontology Set",
          description: "Third test ontology set",
          homepage_url: "http://example.org/gamma",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/blank_nodes.ttl",
              default: true
            ]
          ],
          auto_load: false,
          priority: 3
        ]
      ])

      # Restart OntologyHub to pick up new config
      :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
      {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

      :ok
    end

    test "0.99.1.1 - Load 3+ different sets concurrently" do
      # Spawn concurrent tasks to load all 3 sets simultaneously
      tasks =
        ["set_alpha", "set_beta", "set_gamma"]
        |> Enum.map(fn set_id ->
          Task.async(fn ->
            OntologyHub.get_set(set_id, "v1.0")
          end)
        end)

      # Await all tasks
      results = Enum.map(tasks, &Task.await(&1, 10_000))

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _set} -> true
               _error -> false
             end)

      # Verify all 3 sets are loaded
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 3

      # Verify we can retrieve each set
      {:ok, alpha} = OntologyHub.get_set("set_alpha", "v1.0")
      {:ok, beta} = OntologyHub.get_set("set_beta", "v1.0")
      {:ok, gamma} = OntologyHub.get_set("set_gamma", "v1.0")

      assert alpha.set_id == "set_alpha"
      assert beta.set_id == "set_beta"
      assert gamma.set_id == "set_gamma"
    end

    test "0.99.1.2 - Verify each set has independent triple stores" do
      # Load all 3 sets
      {:ok, alpha} = OntologyHub.get_set("set_alpha", "v1.0")
      {:ok, beta} = OntologyHub.get_set("set_beta", "v1.0")
      {:ok, gamma} = OntologyHub.get_set("set_gamma", "v1.0")

      # Verify each has its own triple store
      assert alpha.triple_store != nil
      assert beta.triple_store != nil
      assert gamma.triple_store != nil

      # Verify triple stores are different objects (not shared)
      refute alpha.triple_store == beta.triple_store
      refute beta.triple_store == gamma.triple_store
      refute alpha.triple_store == gamma.triple_store

      # Verify each triple store has different content
      # (by checking triple counts - different fixtures have different sizes)
      alpha_count = OntoView.Ontology.TripleStore.count(alpha.triple_store)
      beta_count = OntoView.Ontology.TripleStore.count(beta.triple_store)
      gamma_count = OntoView.Ontology.TripleStore.count(gamma.triple_store)

      # All should have triples
      assert alpha_count > 0
      assert beta_count > 0
      assert gamma_count > 0

      # At least some should have different counts (different fixtures)
      counts = [alpha_count, beta_count, gamma_count]
      unique_counts = Enum.uniq(counts)
      assert length(unique_counts) >= 2, "Expected at least 2 different triple counts"
    end

    test "0.99.1.3 - Verify set isolation (changes in one don't affect others)" do
      # Load all 3 sets
      {:ok, alpha_v1} = OntologyHub.get_set("set_alpha", "v1.0")
      {:ok, beta_v1} = OntologyHub.get_set("set_beta", "v1.0")
      {:ok, gamma_v1} = OntologyHub.get_set("set_gamma", "v1.0")

      # Get initial triple counts
      alpha_count_before = OntoView.Ontology.TripleStore.count(alpha_v1.triple_store)
      beta_count_before = OntoView.Ontology.TripleStore.count(beta_v1.triple_store)
      gamma_count_before = OntoView.Ontology.TripleStore.count(gamma_v1.triple_store)

      # Reload alpha set (simulating a change/refresh)
      :ok = OntologyHub.reload_set("set_alpha", "v1.0")

      # Get all sets again
      {:ok, alpha_v2} = OntologyHub.get_set("set_alpha", "v1.0")
      {:ok, beta_v2} = OntologyHub.get_set("set_beta", "v1.0")
      {:ok, gamma_v2} = OntologyHub.get_set("set_gamma", "v1.0")

      # Verify alpha was reloaded (timestamp changed)
      assert DateTime.compare(alpha_v2.loaded_at, alpha_v1.loaded_at) == :gt

      # Verify beta and gamma were NOT reloaded (timestamps unchanged)
      assert beta_v2.loaded_at == beta_v1.loaded_at
      assert gamma_v2.loaded_at == gamma_v1.loaded_at

      # Verify triple counts remain the same for all sets
      alpha_count_after = OntoView.Ontology.TripleStore.count(alpha_v2.triple_store)
      beta_count_after = OntoView.Ontology.TripleStore.count(beta_v2.triple_store)
      gamma_count_after = OntoView.Ontology.TripleStore.count(gamma_v2.triple_store)

      assert alpha_count_after == alpha_count_before
      assert beta_count_after == beta_count_before
      assert gamma_count_after == gamma_count_before

      # Verify each set still has independent triple stores
      refute alpha_v2.triple_store == beta_v2.triple_store
      refute beta_v2.triple_store == gamma_v2.triple_store
      refute alpha_v2.triple_store == gamma_v2.triple_store
    end

    test "multiple sets can be queried independently without interference" do
      # Load all sets
      {:ok, _} = OntologyHub.get_set("set_alpha", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_beta", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_gamma", "v1.0")

      # Query each set multiple times in random order
      for _ <- 1..10 do
        set_id = Enum.random(["set_alpha", "set_beta", "set_gamma"])
        {:ok, set} = OntologyHub.get_set(set_id, "v1.0")
        assert set.set_id == set_id
        assert set.triple_store != nil
      end

      # Verify all sets still loaded and cache is working
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 3
      assert stats.cache_hit_count > 0
    end

    test "sets maintain isolation even under concurrent access" do
      # Load all sets
      {:ok, _} = OntologyHub.get_set("set_alpha", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_beta", "v1.0")
      {:ok, _} = OntologyHub.get_set("set_gamma", "v1.0")

      # Spawn 100 concurrent tasks accessing different sets randomly
      tasks =
        1..100
        |> Enum.map(fn i ->
          Task.async(fn ->
            set_id = Enum.at(["set_alpha", "set_beta", "set_gamma"], rem(i, 3))
            OntologyHub.get_set(set_id, "v1.0")
          end)
        end)

      # Await all tasks
      results = Enum.map(tasks, &Task.await(&1, 10_000))

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _set} -> true
               _error -> false
             end)

      # Group results by set_id and verify correctness
      results_by_set =
        results
        |> Enum.map(fn {:ok, set} -> set.set_id end)
        |> Enum.frequencies()

      # Each set should have been accessed multiple times
      assert results_by_set["set_alpha"] > 0
      assert results_by_set["set_beta"] > 0
      assert results_by_set["set_gamma"] > 0

      # Verify GenServer is still operational
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 3
    end
  end
end
