defmodule OntoView.OntologyHub.SetConfigurationTest do
  use ExUnit.Case, async: true

  alias OntoView.OntologyHub.SetConfiguration

  doctest SetConfiguration

  describe "from_config/1" do
    test "parses valid minimal configuration" do
      config = [
        set_id: "test",
        name: "Test Ontology",
        versions: [
          [version: "v1", root_path: "test.ttl"]
        ]
      ]

      assert {:ok, sc} = SetConfiguration.from_config(config)
      assert sc.set_id == "test"
      assert sc.display.name == "Test Ontology"
      assert length(sc.versions) == 1
      assert sc.default_version == "v1"
      assert sc.auto_load == false
      assert sc.priority == 100
    end

    test "parses configuration with explicit default" do
      config = [
        set_id: "test",
        name: "Test",
        versions: [
          [version: "v1", root_path: "test1.ttl"],
          [version: "v2", root_path: "test2.ttl", default: true]
        ]
      ]

      assert {:ok, sc} = SetConfiguration.from_config(config)
      assert sc.default_version == "v2"
    end

    test "uses first version as default when no explicit default" do
      config = [
        set_id: "test",
        name: "Test",
        versions: [
          [version: "v1", root_path: "test1.ttl"],
          [version: "v2", root_path: "test2.ttl"]
        ]
      ]

      assert {:ok, sc} = SetConfiguration.from_config(config)
      assert sc.default_version == "v1"
    end

    test "parses all display fields" do
      config = [
        set_id: "elixir",
        name: "Elixir Core",
        description: "Elixir ontology",
        homepage_url: "https://elixir-lang.org",
        icon_url: "https://elixir-lang.org/icon.png",
        versions: [[version: "v1", root_path: "test.ttl"]]
      ]

      assert {:ok, sc} = SetConfiguration.from_config(config)
      assert sc.display.name == "Elixir Core"
      assert sc.display.description == "Elixir ontology"
      assert sc.display.homepage_url == "https://elixir-lang.org"
      assert sc.display.icon_url == "https://elixir-lang.org/icon.png"
    end

    test "parses auto_load and priority" do
      config = [
        set_id: "test",
        name: "Test",
        versions: [[version: "v1", root_path: "test.ttl"]],
        auto_load: true,
        priority: 1
      ]

      assert {:ok, sc} = SetConfiguration.from_config(config)
      assert sc.auto_load == true
      assert sc.priority == 1
    end

    test "returns error for missing set_id" do
      config = [name: "Test", versions: [[version: "v1", root_path: "test.ttl"]]]
      assert {:error, :missing_set_id} = SetConfiguration.from_config(config)
    end

    test "returns error for missing name" do
      config = [set_id: "test", versions: [[version: "v1", root_path: "test.ttl"]]]
      assert {:error, :missing_name} = SetConfiguration.from_config(config)
    end

    test "returns error for missing versions" do
      config = [set_id: "test", name: "Test"]
      assert {:error, :missing_versions} = SetConfiguration.from_config(config)
    end

    test "returns error for empty versions list" do
      config = [set_id: "test", name: "Test", versions: []]
      assert {:error, :empty_versions} = SetConfiguration.from_config(config)
    end

    test "returns error for invalid version configuration" do
      config = [
        set_id: "test",
        name: "Test",
        versions: [
          [version: "v1"],  # Missing root_path
        ]
      ]

      assert {:error, {:version_parse_error, :missing_root_path}} = SetConfiguration.from_config(config)
    end
  end

  describe "from_config!/1" do
    test "returns struct on success" do
      config = [
        set_id: "test",
        name: "Test",
        versions: [[version: "v1", root_path: "test.ttl"]]
      ]

      sc = SetConfiguration.from_config!(config)
      assert sc.set_id == "test"
    end

    test "raises on error" do
      assert_raise ArgumentError, fn ->
        SetConfiguration.from_config!([])
      end
    end
  end

  describe "get_default_version/1" do
    test "returns version configuration marked as default" do
      config = SetConfiguration.from_config!([
        set_id: "test",
        name: "Test",
        versions: [
          [version: "v1", root_path: "test1.ttl"],
          [version: "v2", root_path: "test2.ttl", default: true]
        ]
      ])

      default = SetConfiguration.get_default_version(config)
      assert default.version == "v2"
    end

    test "returns first version when no explicit default" do
      config = SetConfiguration.from_config!([
        set_id: "test",
        name: "Test",
        versions: [
          [version: "v1", root_path: "test1.ttl"],
          [version: "v2", root_path: "test2.ttl"]
        ]
      ])

      default = SetConfiguration.get_default_version(config)
      assert default.version == "v1"
    end
  end

  describe "get_version/2" do
    setup do
      config = SetConfiguration.from_config!([
        set_id: "test",
        name: "Test",
        versions: [
          [version: "v1", root_path: "test1.ttl"],
          [version: "v2", root_path: "test2.ttl"]
        ]
      ])

      {:ok, config: config}
    end

    test "finds version by string", %{config: config} do
      version = SetConfiguration.get_version(config, "v2")
      assert version.version == "v2"
      assert version.root_path == "test2.ttl"
    end

    test "returns nil for unknown version", %{config: config} do
      assert SetConfiguration.get_version(config, "v999") == nil
    end
  end

  describe "list_version_strings/1" do
    test "returns all version strings" do
      config = SetConfiguration.from_config!([
        set_id: "test",
        name: "Test",
        versions: [
          [version: "v1", root_path: "test1.ttl"],
          [version: "v2", root_path: "test2.ttl"],
          [version: "latest", root_path: "latest.ttl"]
        ]
      ])

      versions = SetConfiguration.list_version_strings(config)
      assert versions == ["v1", "v2", "latest"]
    end
  end
end
