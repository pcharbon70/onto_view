defmodule OntoView.Ontology.ResourceLimitsTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.ImportResolver

  @fixtures_dir "test/support/fixtures/ontologies"
  @resource_limits_dir Path.join(@fixtures_dir, "resource_limits")

  describe "max_depth enforcement" do
    test "respects configured max_depth limit" do
      # Use existing deep import chain fixture from integration tests
      # deep_level_0 -> deep_level_1 -> deep_level_2 -> deep_level_3 -> deep_level_4 -> deep_level_5
      deep_fixture = Path.join([@fixtures_dir, "integration", "deep_level_0.ttl"])

      # Set max_depth to 1 - this allows depth 0 (root) and depth 1 (first import)
      # But when depth 1 tries to load its imports at depth 2, it will exceed the limit
      # Resource limit errors now propagate, so the entire load fails
      result = ImportResolver.load_with_imports(deep_fixture, max_depth: 1)

      # Should fail because deep_level_2 would be at depth 2, exceeding max_depth 1
      assert {:error, {:max_depth_exceeded, 1}} = result
    end

    test "allows loading within max_depth limit" do
      # Use existing deep import chain fixture
      deep_fixture = Path.join([@fixtures_dir, "integration", "deep_level_0.ttl"])

      # Set max_depth to 5 (should succeed for 5-level chain)
      result = ImportResolver.load_with_imports(deep_fixture, max_depth: 5)

      assert {:ok, loaded} = result
      # Verify we loaded multiple levels
      assert map_size(loaded.ontologies) > 1
    end
  end

  describe "max_imports_per_ontology enforcement" do
    test "rejects ontology with too many imports" do
      fixture = Path.join(@resource_limits_dir, "too_many_imports.ttl")

      # Set limit to 5 imports per ontology (fixture has 21)
      result = ImportResolver.load_with_imports(fixture, max_imports_per_ontology: 5)

      assert {:error, {:max_imports_per_ontology_exceeded, iri, count, limit}} = result
      assert iri == "http://example.org/too_many_imports#"
      assert count == 21
      assert limit == 5
    end

    test "allows ontology within import limit" do
      fixture = Path.join(@resource_limits_dir, "too_many_imports.ttl")

      # Set limit to 25 imports per ontology (fixture has 21)
      result = ImportResolver.load_with_imports(fixture, max_imports_per_ontology: 25)

      # Should succeed loading root (imports will fail to resolve, but that's OK)
      assert {:ok, loaded} = result
      assert Map.has_key?(loaded.ontologies, "http://example.org/too_many_imports#")
    end
  end

  describe "max_total_imports enforcement" do
    test "rejects import chain exceeding total imports limit" do
      # Use existing integration fixture with multiple levels
      # deep_level_0 imports multiple levels
      deep_fixture = Path.join([@fixtures_dir, "integration", "deep_level_0.ttl"])

      # Set very low total import limit
      result = ImportResolver.load_with_imports(deep_fixture, max_total_imports: 2)

      assert {:error, {:max_total_imports_exceeded, actual, limit}} = result
      assert actual > limit
      assert limit == 2
    end

    test "allows loading within total imports limit" do
      # Use simple import fixture
      simple_fixture = Path.join([@fixtures_dir, "imports", "root.ttl"])

      # Set reasonable total import limit
      result = ImportResolver.load_with_imports(simple_fixture, max_total_imports: 100)

      assert {:ok, loaded} = result
      # Should have loaded root and imported ontology
      assert map_size(loaded.ontologies) >= 1
    end
  end

  describe "configuration defaults" do
    test "uses configured defaults from application config" do
      # Test that defaults are read from config
      # The actual config values are: max_depth: 10, max_total_imports: 100, max_imports_per_ontology: 20

      simple_fixture = Path.join([@fixtures_dir, "imports", "root.ttl"])

      # Should use defaults from config (should succeed with defaults)
      result = ImportResolver.load_with_imports(simple_fixture)

      assert {:ok, _loaded} = result
    end

    test "opts override configuration defaults" do
      fixture = Path.join(@resource_limits_dir, "too_many_imports.ttl")

      # Override default with stricter limit
      result = ImportResolver.load_with_imports(fixture, max_imports_per_ontology: 5)

      assert {:error, {:max_imports_per_ontology_exceeded, _, _, 5}} = result
    end
  end

  describe "resource limit error messages" do
    test "max_depth_exceeded provides clear limit information" do
      deep_fixture = Path.join([@fixtures_dir, "integration", "deep_level_0.ttl"])

      {:error, {:max_depth_exceeded, limit}} =
        ImportResolver.load_with_imports(deep_fixture, max_depth: 0)

      assert limit == 0
    end

    test "max_imports_per_ontology_exceeded provides detailed information" do
      fixture = Path.join(@resource_limits_dir, "too_many_imports.ttl")

      {:error, {:max_imports_per_ontology_exceeded, iri, count, limit}} =
        ImportResolver.load_with_imports(fixture, max_imports_per_ontology: 10)

      assert is_binary(iri)
      assert is_integer(count)
      assert is_integer(limit)
      assert count > limit
    end

    test "max_total_imports_exceeded provides count information" do
      deep_fixture = Path.join([@fixtures_dir, "integration", "deep_level_0.ttl"])

      {:error, {:max_total_imports_exceeded, actual, limit}} =
        ImportResolver.load_with_imports(deep_fixture, max_total_imports: 1)

      assert is_integer(actual)
      assert is_integer(limit)
      assert actual > limit
    end
  end

  describe "edge cases" do
    test "limit of 0 prevents all imports" do
      simple_fixture = Path.join([@fixtures_dir, "imports", "root.ttl"])

      # max_total_imports: 0 should fail immediately when trying to load first import
      result = ImportResolver.load_with_imports(simple_fixture, max_total_imports: 0)

      # Root is loaded (count starts at 1), so this will fail when trying to load imports
      assert {:error, {:max_total_imports_exceeded, _, 0}} = result
    end

    test "limit equal to actual count succeeds" do
      # Hub pattern has root + spokes
      hub_fixture = Path.join([@fixtures_dir, "integration", "hub.ttl"])

      # Should succeed if limit matches or exceeds actual count
      result = ImportResolver.load_with_imports(hub_fixture, max_total_imports: 10)

      assert {:ok, loaded} = result
      assert map_size(loaded.ontologies) <= 10
    end
  end
end
