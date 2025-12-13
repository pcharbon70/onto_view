defmodule OntoView.OntologyHub.VersionConfigurationTest do
  use ExUnit.Case, async: true

  alias OntoView.OntologyHub.VersionConfiguration

  doctest VersionConfiguration

  describe "from_config/1" do
    test "parses valid minimal configuration" do
      config = [
        version: "v1.17",
        root_path: "priv/ontologies/test.ttl"
      ]

      assert {:ok, vc} = VersionConfiguration.from_config(config)
      assert vc.version == "v1.17"
      assert vc.root_path == "priv/ontologies/test.ttl"
      assert vc.default == false
      assert vc.release_metadata.stability == :stable
    end

    test "parses configuration with all fields" do
      config = [
        version: "v1.18",
        root_path: "priv/ontologies/test.ttl",
        base_dir: "priv/ontologies",
        default: true,
        stability: :beta,
        released_at: ~D[2024-06-12],
        release_notes_url: "https://example.com/releases",
        deprecated: true
      ]

      assert {:ok, vc} = VersionConfiguration.from_config(config)
      assert vc.version == "v1.18"
      assert vc.default == true
      assert vc.base_dir == "priv/ontologies"
      assert vc.release_metadata.stability == :beta
      assert vc.release_metadata.released_at == ~D[2024-06-12]
      assert vc.release_metadata.deprecated == true
    end

    test "returns error for missing version" do
      config = [root_path: "test.ttl"]
      assert {:error, :missing_version} = VersionConfiguration.from_config(config)
    end

    test "returns error for missing root_path" do
      config = [version: "v1"]
      assert {:error, :missing_root_path} = VersionConfiguration.from_config(config)
    end

    test "returns error for empty version string" do
      config = [version: "", root_path: "test.ttl"]
      assert {:error, {:invalid_value, :version}} = VersionConfiguration.from_config(config)
    end

    test "returns error for empty root_path string" do
      config = [version: "v1", root_path: ""]
      assert {:error, {:invalid_value, :root_path}} = VersionConfiguration.from_config(config)
    end
  end

  describe "from_config!/1" do
    test "returns struct on success" do
      config = [version: "v1", root_path: "test.ttl"]
      vc = VersionConfiguration.from_config!(config)
      assert vc.version == "v1"
    end

    test "raises on error" do
      assert_raise ArgumentError, fn ->
        VersionConfiguration.from_config!([])
      end
    end
  end
end
