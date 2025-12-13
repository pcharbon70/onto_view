defmodule OntoView.OntologyHub.OntologySetTest do
  use ExUnit.Case, async: true

  alias OntoView.OntologyHub.OntologySet
  alias OntoView.Ontology.{ImportResolver, TripleStore}

  doctest OntologySet

  describe "new/4" do
    test "creates valid OntologySet from Phase 1 structures" do
      # Use Phase 1 test fixture
      fixture_path = "test/support/fixtures/ontologies/valid_simple.ttl"

      assert {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      set = OntologySet.new("test", "v1", loaded, store)

      assert set.set_id == "test"
      assert set.version == "v1"
      assert is_struct(set.triple_store, TripleStore)
      assert is_map(set.ontologies)
      assert set.access_count == 0
      assert set.stats.triple_count > 0
      assert set.stats.ontology_count > 0
    end

    test "initializes cache metadata correctly" do
      fixture_path = "test/support/fixtures/ontologies/valid_simple.ttl"
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      set = OntologySet.new("test", "v1", loaded, store)

      assert set.access_count == 0
      assert is_struct(set.loaded_at, DateTime)
      assert is_struct(set.last_accessed, DateTime)
      assert DateTime.compare(set.loaded_at, set.last_accessed) == :eq
    end

    test "computes stats from triple store" do
      fixture_path = "test/support/fixtures/ontologies/valid_simple.ttl"
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      set = OntologySet.new("test", "v1", loaded, store)

      assert set.stats.triple_count == TripleStore.count(store)
      assert set.stats.ontology_count == map_size(loaded.ontologies)
      # Phase 1.3+ fields are nil for now
      assert set.stats.class_count == nil
      assert set.stats.property_count == nil
      assert set.stats.individual_count == nil
    end
  end

  describe "record_access/1" do
    setup do
      fixture_path = "test/support/fixtures/ontologies/valid_simple.ttl"
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)
      set = OntologySet.new("test", "v1", loaded, store)
      {:ok, set: set}
    end

    test "increments access count", %{set: set} do
      updated = OntologySet.record_access(set)
      assert updated.access_count == 1

      updated = OntologySet.record_access(updated)
      assert updated.access_count == 2
    end

    test "updates last_accessed timestamp", %{set: set} do
      # Sleep briefly to ensure timestamp difference
      Process.sleep(10)
      updated = OntologySet.record_access(set)

      assert DateTime.compare(updated.last_accessed, set.last_accessed) == :gt
    end

    test "returns new struct (immutable)", %{set: set} do
      updated = OntologySet.record_access(set)

      assert set.access_count == 0
      assert updated.access_count == 1
      refute set == updated
    end
  end

  describe "triple_count/1" do
    test "returns stats.triple_count" do
      fixture_path = "test/support/fixtures/ontologies/valid_simple.ttl"
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)
      set = OntologySet.new("test", "v1", loaded, store)

      count = OntologySet.triple_count(set)
      assert is_integer(count)
      assert count > 0
      assert count == set.stats.triple_count
    end
  end

  describe "ontology_count/1" do
    test "returns stats.ontology_count" do
      fixture_path = "test/support/fixtures/ontologies/valid_simple.ttl"
      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)
      set = OntologySet.new("test", "v1", loaded, store)

      count = OntologySet.ontology_count(set)
      assert is_integer(count)
      assert count > 0
      assert count == set.stats.ontology_count
    end
  end
end
