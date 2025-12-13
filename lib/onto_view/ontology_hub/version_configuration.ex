defmodule OntoView.OntologyHub.VersionConfiguration do
  @moduledoc """
  Configuration for a specific version of an ontology set.

  Represents metadata about a single version (e.g., "v1.17", "v1.18") of an ontology
  set without loading the actual ontology files. This lightweight struct enables fast
  startup and version browsing.

  ## Fields

  - `version` - Version string (e.g., "v1.17", "latest")
  - `root_path` - Path to the root TTL file for this version
  - `base_dir` - Optional base directory for resolving relative imports
  - `default` - Whether this is the default version for the set
  - `release_metadata` - Release information for UI display

  ## Usage

      iex> config = %VersionConfiguration{
      ...>   version: "v1.17",
      ...>   root_path: "priv/ontologies/elixir/v1.17.ttl",
      ...>   default: true
      ...> }
      iex> config.version
      "v1.17"

  Part of Task 0.1.1.2 — Define SetConfiguration struct
  """

  @type version :: String.t()

  @typedoc """
  Release metadata for the version.

  Fields:
  - `released_at`: Official release date
  - `release_notes_url`: Link to release notes/changelog
  - `deprecated`: Whether this version is deprecated
  - `stability`: Version stability level
  """
  @type release_metadata :: %{
          released_at: Date.t() | nil,
          release_notes_url: String.t() | nil,
          deprecated: boolean(),
          stability: :stable | :beta | :alpha
        }

  @type t :: %__MODULE__{
          version: version(),
          root_path: Path.t(),
          base_dir: Path.t() | nil,
          default: boolean(),
          release_metadata: release_metadata()
        }

  defstruct [
    :version,
    :root_path,
    :base_dir,
    default: false,
    release_metadata: %{
      released_at: nil,
      release_notes_url: nil,
      deprecated: false,
      stability: :stable
    }
  ]

  @doc """
  Parses a VersionConfiguration from a configuration keyword list.

  ## Config Format

      [
        version: "v1.17",
        root_path: "priv/ontologies/elixir/v1.17.ttl",
        base_dir: "priv/ontologies/elixir",
        default: true,
        stability: :stable,
        released_at: ~D[2024-06-12],
        release_notes_url: "https://github.com/elixir-lang/elixir/releases/tag/v1.17.0"
      ]

  ## Returns

  - `{:ok, VersionConfiguration.t()}` on success
  - `{:error, reason}` if required fields are missing or invalid

  ## Examples

      iex> config = [version: "v1.17", root_path: "test.ttl"]
      iex> {:ok, vc} = VersionConfiguration.from_config(config)
      iex> vc.version
      "v1.17"

      iex> VersionConfiguration.from_config([])
      {:error, :missing_version}
  """
  @spec from_config(keyword()) :: {:ok, t()} | {:error, term()}
  def from_config(config) when is_list(config) do
    with {:ok, version} <- fetch_required(config, :version),
         {:ok, root_path} <- fetch_required(config, :root_path) do
      release_metadata = %{
        released_at: Keyword.get(config, :released_at),
        release_notes_url: Keyword.get(config, :release_notes_url),
        deprecated: Keyword.get(config, :deprecated, false),
        stability: Keyword.get(config, :stability, :stable)
      }

      version_config = %__MODULE__{
        version: version,
        root_path: root_path,
        base_dir: Keyword.get(config, :base_dir),
        default: Keyword.get(config, :default, false),
        release_metadata: release_metadata
      }

      {:ok, version_config}
    end
  end

  @doc """
  Same as from_config/1 but raises on error.

  ## Examples

      iex> config = [version: "v1.17", root_path: "test.ttl"]
      iex> vc = VersionConfiguration.from_config!(config)
      iex> vc.version
      "v1.17"
  """
  @spec from_config!(keyword()) :: t()
  def from_config!(config) do
    case from_config(config) do
      {:ok, version_config} -> version_config
      {:error, reason} -> raise ArgumentError, "Invalid version configuration: #{inspect(reason)}"
    end
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
end
