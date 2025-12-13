defmodule OntoView.OntologyHub.SetConfiguration do
  @moduledoc """
  Configuration metadata for an ontology set.

  This lightweight struct contains only metadata about an ontology set (e.g., Elixir,
  Ecto, Phoenix), not the actual loaded triples. It enables fast startup and set
  browsing without loading heavyweight triple stores.

  A set configuration defines multiple versions of related ontologies, allowing users
  to switch between versions (e.g., Elixir v1.17 vs v1.18) or compare them side-by-side.

  ## Fields

  - `set_id` - Unique identifier (e.g., "elixir", "ecto")
  - `display` - UI display configuration (name, description, links)
  - `versions` - List of available versions
  - `default_version` - Default version string
  - `auto_load` - Whether to load automatically at startup
  - `priority` - Loading priority (lower = higher priority)

  ## Usage

      config = %SetConfiguration{
        set_id: "elixir",
        display: %{name: "Elixir Core Ontology"},
        versions: [],
        default_version: "v1.17"
      }
      config.set_id
      # => "elixir"

  Part of Task 0.1.1.2 — Define SetConfiguration struct
  """

  alias OntoView.OntologyHub.VersionConfiguration

  @type set_id :: String.t()

  @typedoc """
  UI display configuration for the set.

  Fields:
  - `name`: Human-readable name (e.g., "Elixir Core Ontology")
  - `description`: Longer description for UI
  - `homepage_url`: Link to project homepage
  - `icon_url`: Optional icon for UI display
  """
  @type display_config :: %{
          name: String.t(),
          description: String.t() | nil,
          homepage_url: String.t() | nil,
          icon_url: String.t() | nil
        }

  @type t :: %__MODULE__{
          set_id: set_id(),
          display: display_config(),
          versions: [VersionConfiguration.t()],
          default_version: String.t(),
          auto_load: boolean(),
          priority: non_neg_integer()
        }

  defstruct [
    :set_id,
    :display,
    :versions,
    :default_version,
    auto_load: false,
    priority: 100
  ]

  @doc """
  Parses a SetConfiguration from Application config.

  ## Config Format

      [
        set_id: "elixir",
        name: "Elixir Core Ontology",
        description: "Core concepts for Elixir",
        homepage_url: "https://elixir-lang.org",
        icon_url: "https://elixir-lang.org/images/logo.png",
        versions: [
          [version: "v1.17", root_path: "priv/ontologies/elixir/v1.17.ttl", default: true],
          [version: "v1.18", root_path: "priv/ontologies/elixir/v1.18.ttl"]
        ],
        auto_load: true,
        priority: 1
      ]

  ## Returns

  - `{:ok, SetConfiguration.t()}` on success
  - `{:error, reason}` if config is invalid

  ## Examples

      iex> config = [
      ...>   set_id: "elixir",
      ...>   name: "Elixir",
      ...>   versions: [[version: "v1.17", root_path: "test.ttl", default: true]]
      ...> ]
      iex> {:ok, sc} = SetConfiguration.from_config(config)
      iex> sc.set_id
      "elixir"
      iex> sc.default_version
      "v1.17"
  """
  @spec from_config(keyword()) :: {:ok, t()} | {:error, term()}
  def from_config(config) when is_list(config) do
    with {:ok, set_id} <- fetch_required(config, :set_id),
         {:ok, name} <- fetch_required(config, :name),
         {:ok, version_configs} <- parse_versions(config),
         {:ok, default_version} <- determine_default_version(version_configs) do
      display = %{
        name: name,
        description: Keyword.get(config, :description),
        homepage_url: Keyword.get(config, :homepage_url),
        icon_url: Keyword.get(config, :icon_url)
      }

      set_config = %__MODULE__{
        set_id: set_id,
        display: display,
        versions: version_configs,
        default_version: default_version,
        auto_load: Keyword.get(config, :auto_load, false),
        priority: Keyword.get(config, :priority, 100)
      }

      {:ok, set_config}
    end
  end

  @doc """
  Same as from_config/1 but raises on error.

  ## Examples

      iex> config = [set_id: "elixir", name: "Elixir", versions: [[version: "v1", root_path: "test.ttl"]]]
      iex> sc = SetConfiguration.from_config!(config)
      iex> sc.set_id
      "elixir"
  """
  @spec from_config!(keyword()) :: t()
  def from_config!(config) do
    case from_config(config) do
      {:ok, set_config} -> set_config
      {:error, reason} -> raise ArgumentError, "Invalid set configuration: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the VersionConfiguration for the default version.

  ## Examples

      iex> config = SetConfiguration.from_config!([
      ...>   set_id: "test",
      ...>   name: "Test",
      ...>   versions: [
      ...>     [version: "v1", root_path: "test.ttl", default: true],
      ...>     [version: "v2", root_path: "test2.ttl"]
      ...>   ]
      ...> ])
      iex> default = SetConfiguration.get_default_version(config)
      iex> default.version
      "v1"
  """
  @spec get_default_version(t()) :: VersionConfiguration.t() | nil
  def get_default_version(%__MODULE__{versions: versions, default_version: default_version}) do
    Enum.find(versions, fn v -> v.version == default_version end)
  end

  @doc """
  Returns the VersionConfiguration for a specific version.

  ## Examples

      iex> config = SetConfiguration.from_config!([
      ...>   set_id: "test",
      ...>   name: "Test",
      ...>   versions: [
      ...>     [version: "v1", root_path: "test.ttl"],
      ...>     [version: "v2", root_path: "test2.ttl"]
      ...>   ]
      ...> ])
      iex> version = SetConfiguration.get_version(config, "v2")
      iex> version.version
      "v2"

      iex> config = SetConfiguration.from_config!([
      ...>   set_id: "test",
      ...>   name: "Test",
      ...>   versions: [[version: "v1", root_path: "test.ttl"]]
      ...> ])
      iex> SetConfiguration.get_version(config, "v999")
      nil
  """
  @spec get_version(t(), String.t()) :: VersionConfiguration.t() | nil
  def get_version(%__MODULE__{versions: versions}, version_string) do
    Enum.find(versions, fn v -> v.version == version_string end)
  end

  @doc """
  Lists all version strings for this set.

  ## Examples

      iex> config = SetConfiguration.from_config!([
      ...>   set_id: "test",
      ...>   name: "Test",
      ...>   versions: [
      ...>     [version: "v1", root_path: "test.ttl"],
      ...>     [version: "v2", root_path: "test2.ttl"]
      ...>   ]
      ...> ])
      iex> SetConfiguration.list_version_strings(config)
      ["v1", "v2"]
  """
  @spec list_version_strings(t()) :: [String.t()]
  def list_version_strings(%__MODULE__{versions: versions}) do
    Enum.map(versions, & &1.version)
  end

  # Private Helpers

  defp fetch_required(config, key) do
    case Keyword.fetch(config, key) do
      {:ok, value} when is_binary(value) and byte_size(value) > 0 ->
        {:ok, value}

      {:ok, _} ->
        {:error, {:invalid_value, key}}

      :error ->
        {:error, :"missing_#{key}"}
    end
  end

  defp parse_versions(config) do
    case Keyword.get(config, :versions) do
      nil ->
        {:error, :missing_versions}

      [] ->
        {:error, :empty_versions}

      versions when is_list(versions) ->
        versions
        |> Enum.reduce_while({:ok, []}, fn version_kw, {:ok, acc} ->
          case VersionConfiguration.from_config(version_kw) do
            {:ok, version_config} -> {:cont, {:ok, [version_config | acc]}}
            {:error, reason} -> {:halt, {:error, {:version_parse_error, reason}}}
          end
        end)
        |> case do
          {:ok, version_configs} -> {:ok, Enum.reverse(version_configs)}
          error -> error
        end

      _ ->
        {:error, :invalid_versions_format}
    end
  end

  defp determine_default_version(version_configs) do
    # Look for explicit default: true
    case Enum.find(version_configs, & &1.default) do
      %VersionConfiguration{version: version} ->
        {:ok, version}

      nil ->
        # Fall back to first version
        case version_configs do
          [%VersionConfiguration{version: version} | _] -> {:ok, version}
          [] -> {:error, :no_versions}
        end
    end
  end
end
