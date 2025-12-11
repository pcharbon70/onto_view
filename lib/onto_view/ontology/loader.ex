defmodule OntoView.Ontology.Loader do
  @moduledoc """
  Loads and validates Turtle (.ttl) ontology files.

  This module handles:
  - File existence and readability validation
  - Turtle file parsing via RDF.ex
  - Extraction of file metadata (path, base IRI, prefix map)

  Part of Task 1.1.1 — Load Root Ontology Files
  """

  require Logger

  # Common OWL/RDF IRIs as module attributes (optimization: avoids runtime creation)
  @owl_ontology RDF.iri("http://www.w3.org/2002/07/owl#Ontology")

  defmodule LoadedOntology do
    @moduledoc """
    Struct representing a successfully loaded ontology file.

    Provides better type safety and pattern matching compared to plain maps.
    """

    @type t :: %__MODULE__{
            path: Path.t(),
            base_iri: String.t() | nil,
            prefix_map: %{String.t() => String.t()},
            graph: RDF.Graph.t(),
            loaded_at: DateTime.t()
          }

    defstruct [:path, :base_iri, :prefix_map, :graph, :loaded_at]
  end

  @type file_path :: String.t() | Path.t()
  @type loaded_ontology :: LoadedOntology.t()
  @type load_result :: {:ok, loaded_ontology()} | {:error, error_reason()}

  @typedoc """
  Error reasons for failed ontology loads.
  """
  @type error_reason ::
          :file_not_found
          | :permission_denied
          | {:not_a_file, String.t()}
          | {:parse_error, String.t()}
          | {:io_error, String.t()}

  @doc """
  Loads a Turtle ontology file from the filesystem.

  ## Parameters

  - `file_path` - Absolute or relative path to a .ttl file
  - `opts` - Optional keyword list:
    - `:base_iri` - Override base IRI (default: extract from file)
    - `:stream` - Enable streaming for large files (default: false)
    - `:validate` - Run validation checks (default: true)

  ## Returns

  - `{:ok, loaded_ontology}` - Successfully loaded ontology with metadata
  - `{:error, reason}` - Error with descriptive reason

  ## Examples

      iex> Loader.load_file("priv/ontologies/elixir-core.ttl")
      {:ok, %{
        path: "/absolute/path/to/elixir-core.ttl",
        base_iri: "http://example.org/elixir/core#",
        prefix_map: %{"elixir" => "http://example.org/elixir/core#"},
        graph: %RDF.Graph{},
        loaded_at: ~U[2025-12-10 10:00:00Z]
      }}

      iex> Loader.load_file("nonexistent.ttl")
      {:error, :file_not_found}
  """
  @spec load_file(file_path(), keyword()) :: load_result()
  def load_file(file_path, opts \\ []) do
    with {:ok, absolute_path} <- validate_file_path(file_path),
         {:ok, graph} <- parse_turtle_file(absolute_path, opts),
         {:ok, metadata} <- extract_metadata(graph, absolute_path, opts) do
      result = %LoadedOntology{
        path: absolute_path,
        base_iri: metadata.base_iri,
        prefix_map: metadata.prefix_map,
        graph: graph,
        loaded_at: DateTime.utc_now()
      }

      Logger.info("Successfully loaded ontology: #{absolute_path}")
      {:ok, result}
    else
      {:error, reason} = error ->
        Logger.error("Failed to load ontology #{file_path}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Loads a Turtle file, raising on error (bang variant).

  See `load_file/2` for details.
  """
  @spec load_file!(file_path(), keyword()) :: loaded_ontology()
  def load_file!(file_path, opts \\ []) do
    case load_file(file_path, opts) do
      {:ok, ontology} -> ontology
      {:error, reason} -> raise "Failed to load ontology: #{inspect(reason)}"
    end
  end

  # Private helper functions

  # Task 1.1.1.2: Validate file existence and readability
  defp validate_file_path(file_path) do
    absolute_path = Path.expand(file_path)

    cond do
      not File.exists?(absolute_path) ->
        {:error, :file_not_found}

      symlink?(absolute_path) ->
        Logger.warning("Symlink detected and rejected: #{absolute_path}")
        {:error, {:symlink_detected, "Symlinks are not allowed for security"}}

      not File.regular?(absolute_path) ->
        {:error, {:not_a_file, "Path is a directory or special file"}}

      not has_ttl_extension?(absolute_path) ->
        Logger.warning("File does not have .ttl extension: #{absolute_path}")
        check_file_readable(absolute_path)

      true ->
        check_file_readable(absolute_path)
    end
  end

  defp symlink?(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :symlink}} -> true
      _ -> false
    end
  end

  defp check_file_readable(path) do
    max_size = Application.get_env(:onto_view, :ontology_loader)[:max_file_size_bytes]

    with {:ok, %File.Stat{size: size}} <- File.stat(path),
         :ok <- validate_file_size(size, max_size),
         {:ok, _contents} <- File.read(path) do
      {:ok, path}
    else
      {:error, :eacces} -> {:error, :permission_denied}
      {:error, {:file_too_large, _}} = error -> error
      {:error, reason} -> {:error, {:io_error, inspect(reason)}}
    end
  end

  defp validate_file_size(size, max_size) do
    if size > max_size do
      Logger.warning("File exceeds size limit: #{size} bytes (max: #{max_size})")
      {:error, {:file_too_large, "File exceeds #{max_size} bytes limit (got #{size} bytes)"}}
    else
      :ok
    end
  end

  defp has_ttl_extension?(path) do
    ext = Path.extname(path)
    ext == ".ttl" or ext == ".gz"
  end

  # Task 1.1.1.1: Implement .ttl file reader
  defp parse_turtle_file(absolute_path, opts) do
    # Configure RDF.Turtle reader options
    read_opts = [
      stream: Keyword.get(opts, :stream, false)
    ]

    case RDF.Turtle.read_file(absolute_path, read_opts) do
      {:ok, %RDF.Graph{} = graph} ->
        validate_graph_not_empty(graph, absolute_path)

      {:error, %_{} = error} when is_exception(error) ->
        {:error, {:parse_error, Exception.message(error)}}

      {:error, reason} ->
        {:error, {:io_error, inspect(reason)}}
    end
  end

  defp validate_graph_not_empty(graph, path) do
    case RDF.Graph.triple_count(graph) do
      0 ->
        Logger.warning("Loaded empty graph from #{path}")
        {:ok, graph}

      count ->
        Logger.debug("Loaded #{count} triples from #{path}")
        {:ok, graph}
    end
  end

  # Task 1.1.1.3: Register file metadata (path, base IRI, prefix map)
  defp extract_metadata(graph, path, opts) do
    base_iri = extract_base_iri(graph, opts)
    prefix_map = extract_prefix_map(graph)

    metadata = %{
      base_iri: base_iri,
      prefix_map: prefix_map,
      statement_count: RDF.Graph.triple_count(graph),
      filename: Path.basename(path)
    }

    {:ok, metadata}
  end

  defp extract_base_iri(graph, opts) do
    # Priority:
    # 1. Explicit override from opts[:base_iri]
    # 2. owl:Ontology IRI from graph
    # 3. Default base IRI pattern

    if Keyword.has_key?(opts, :base_iri) do
      opts[:base_iri]
    else
      find_ontology_iri(graph) || generate_default_base_iri()
    end
  end

  defp find_ontology_iri(graph) do
    # Query for owl:Ontology declaration
    # SELECT ?ontology WHERE { ?ontology a owl:Ontology }

    graph
    |> RDF.Graph.descriptions()
    |> Enum.find_value(fn description ->
      types = RDF.Description.get(description, RDF.type(), [])
      types_list = if is_list(types), do: types, else: [types]

      if @owl_ontology in types_list do
        case description.subject do
          %RDF.IRI{} = iri -> to_string(iri)
          %RDF.BlankNode{} -> nil
          other -> to_string(other)
        end
      end
    end)
  end

  defp extract_prefix_map(%RDF.Graph{prefixes: prefixes}) do
    # Extract prefix declarations from graph metadata
    # RDF.ex stores these automatically when parsing Turtle

    prefixes
    |> Map.new(fn {prefix, iri} ->
      {to_string(prefix), to_string(iri)}
    end)
  end

  defp generate_default_base_iri do
    "http://example.org/ontology/#{:erlang.unique_integer([:positive])}"
  end
end
