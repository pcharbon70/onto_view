defmodule OntoView.Ontology.ImportResolver do
  @moduledoc """
  Resolves and loads owl:imports statements recursively.

  This module extends the basic file loading capability to support
  recursive import resolution, building complete ontology dependency chains
  while preserving provenance information.

  Implements cycle detection to identify and report circular import dependencies
  with diagnostic traces showing the exact circular path.

  Part of Task 1.1.2 — Resolve `owl:imports` Recursively
  Part of Task 1.1.3 — Import Cycle Detection
  """

  require Logger

  alias OntoView.Ontology.Loader

  # Common OWL/RDF IRIs as module attributes (optimization: avoids runtime creation)
  @owl_ontology RDF.iri("http://www.w3.org/2002/07/owl#Ontology")
  @owl_imports RDF.iri("http://www.w3.org/2002/07/owl#imports")

  @type import_chain :: %{
          root_iri: String.t(),
          imports: [import_node()],
          depth: non_neg_integer()
        }

  @type import_node :: %{
          iri: String.t(),
          path: Path.t(),
          imports: [String.t()],
          depth: non_neg_integer()
        }

  @type loaded_ontologies :: %{
          dataset: RDF.Dataset.t(),
          ontologies: %{String.t() => ontology_metadata()},
          import_chain: import_chain()
        }

  @type ontology_metadata :: %{
          iri: String.t(),
          path: Path.t(),
          base_iri: String.t(),
          prefix_map: %{String.t() => String.t()},
          imports: [String.t()],
          graph: RDF.Graph.t(),
          triple_count: non_neg_integer(),
          loaded_at: DateTime.t(),
          depth: non_neg_integer()
        }

  @type iri_resolver :: %{
          mappings: %{String.t() => Path.t()},
          base_dir: Path.t()
        }

  @type cycle_trace :: %{
          cycle_detected_at: String.t(),
          import_path: [String.t()],
          cycle_length: non_neg_integer(),
          human_readable: String.t()
        }

  # Internal context struct for import resolution recursion
  # Reduces parameter count from 9 to 2 in load_recursively
  defmodule ImportContext do
    @moduledoc false

    @type t :: %__MODULE__{
            resolver: map(),
            visited: MapSet.t(String.t()),
            depth: non_neg_integer(),
            limits: map(),
            acc: map(),
            root_iri: String.t() | nil,
            path: [String.t()],
            total_imports: non_neg_integer()
          }

    defstruct [
      :resolver,
      :visited,
      :depth,
      :limits,
      :acc,
      :root_iri,
      :path,
      :total_imports
    ]
  end

  @doc """
  Loads an ontology with all its recursive imports.

  ## Parameters

  - `file_path` - Path to root ontology file
  - `opts` - Options:
    - `:iri_resolver` - Custom IRI → path mapping
    - `:base_dir` - Base directory for resolving imports (defaults to file's directory)
    - `:max_depth` - Maximum import depth (default: 10)

  ## Returns

  - `{:ok, loaded_ontologies}` - All ontologies loaded with provenance
  - `{:error, {:circular_dependency, cycle_trace}}` - Circular import detected
  - `{:error, reason}` - Other error during loading

  ## Examples

      iex> ImportResolver.load_with_imports("priv/ontologies/root.ttl")
      {:ok, %{
        dataset: %RDF.Dataset{},
        ontologies: %{"http://example.org/root#" => %{...}},
        import_chain: %{root_iri: "http://example.org/root#", ...}
      }}

      iex> ImportResolver.load_with_imports("priv/ontologies/circular.ttl")
      {:error, {:circular_dependency, %{
        cycle_detected_at: "http://example.org/A#",
        import_path: ["http://example.org/A#", "http://example.org/B#", "http://example.org/A#"],
        cycle_length: 2,
        human_readable: "http://example.org/A# → http://example.org/B# → [CYCLE START] http://example.org/A#"
      }}}
  """
  @spec load_with_imports(Path.t(), keyword()) ::
          {:ok, loaded_ontologies()} | {:error, term()}
  def load_with_imports(file_path, opts \\ []) do
    # Get configuration values
    config = Application.get_env(:onto_view, :ontology_loader, [])
    max_depth = Keyword.get(opts, :max_depth, Keyword.get(config, :max_depth, 10))
    max_total_imports = Keyword.get(opts, :max_total_imports, Keyword.get(config, :max_total_imports, 100))
    max_imports_per_ontology = Keyword.get(opts, :max_imports_per_ontology, Keyword.get(config, :max_imports_per_ontology, 20))

    base_dir = Keyword.get(opts, :base_dir, Path.dirname(file_path))
    visited = MapSet.new()
    path = []

    # Resource limits configuration
    limits = %{
      max_depth: max_depth,
      max_total_imports: max_total_imports,
      max_imports_per_ontology: max_imports_per_ontology
    }

    with {:ok, root} <- Loader.load_file(file_path, opts),
         {:ok, resolver} <- build_iri_resolver(base_dir, opts) do
      ctx = %ImportContext{
        resolver: resolver,
        visited: visited,
        depth: 0,
        limits: limits,
        acc: %{},
        root_iri: nil,
        path: path,
        total_imports: 1
      }

      load_recursively(root, ctx)
    end
  end

  @doc """
  Loads an ontology with all its recursive imports, raising on error.

  Same as `load_with_imports/2` but raises an exception on error.

  ## Parameters

  - `file_path` - Path to root ontology file
  - `opts` - Same options as `load_with_imports/2`

  ## Returns

  - `loaded_ontologies` - All ontologies loaded with provenance

  ## Raises

  - `RuntimeError` - On any error including circular dependencies, resource limits, etc.

  ## Examples

      iex> ImportResolver.load_with_imports!("priv/ontologies/valid.ttl")
      %{
        dataset: %RDF.Dataset{...},
        ontologies: %{...},
        import_chain: %{...}
      }

      iex> ImportResolver.load_with_imports!("priv/ontologies/circular.ttl")
      ** (RuntimeError) Failed to load ontology with imports: circular_dependency
  """
  @spec load_with_imports!(Path.t(), keyword()) :: loaded_ontologies()
  def load_with_imports!(file_path, opts \\ []) do
    case load_with_imports(file_path, opts) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise "Failed to load ontology with imports: #{inspect(reason)}"
    end
  end

  # Task 1.1.2.1: Parse owl:imports triples
  @doc """
  Extracts owl:imports statements from an RDF graph.

  Returns a list of import IRIs found in the graph.
  """
  @spec extract_imports(RDF.Graph.t()) :: {:ok, [String.t()]}
  def extract_imports(graph) do
    imports =
      graph
      |> RDF.Graph.descriptions()
      |> Enum.filter(&has_type?(&1, @owl_ontology))
      |> Enum.flat_map(&extract_import_iris(&1, @owl_imports))
      |> Enum.uniq()

    {:ok, imports}
  end

  # Private helper functions

  defp load_recursively(ontology, %ImportContext{} = ctx) do
    cond do
      ctx.depth > ctx.limits.max_depth ->
        {:error, {:max_depth_exceeded, ctx.limits.max_depth}}

      ctx.total_imports > ctx.limits.max_total_imports ->
        Logger.warning("Maximum total imports (#{ctx.limits.max_total_imports}) exceeded")
        {:error, {:max_total_imports_exceeded, ctx.total_imports, ctx.limits.max_total_imports}}

      true ->
        iri = ontology.base_iri
        new_path = ctx.path ++ [iri]
        new_visited = MapSet.put(ctx.visited, iri)

        # Track root IRI (first ontology loaded)
        actual_root_iri = ctx.root_iri || iri

        # Add current ontology to accumulator
        ontology_meta = build_ontology_metadata(ontology, ctx.depth)
        new_acc = Map.put(ctx.acc, iri, ontology_meta)

        # Extract and process imports
        {:ok, import_iris} = extract_imports(ontology.graph)

        # Check per-ontology import limit
        import_count = length(import_iris)
        if import_count > ctx.limits.max_imports_per_ontology do
          Logger.warning(
            "Ontology #{iri} has #{import_count} imports, exceeding limit of #{ctx.limits.max_imports_per_ontology}"
          )

          {:error, {:max_imports_per_ontology_exceeded, iri, import_count, ctx.limits.max_imports_per_ontology}}
        else
          # Task 1.1.3.1: Check for cycles in the import list BEFORE filtering
          cycle_iris = Enum.filter(import_iris, &(&1 in new_path))

          if cycle_iris != [] do
            # Cycle detected - report the first one
            [cycle_iri | _] = cycle_iris
            trace = build_cycle_trace(new_path, cycle_iri)
            Logger.error("Circular dependency detected: #{trace.human_readable}")
            {:error, {:circular_dependency, trace}}
          else
            # Filter out already visited IRIs (for diamond pattern optimization)
            unvisited_imports =
              import_iris
              |> Enum.reject(&MapSet.member?(new_visited, &1))

            # Create updated context for recursive calls
            new_ctx = %ImportContext{
              resolver: ctx.resolver,
              visited: new_visited,
              depth: ctx.depth + 1,
              limits: ctx.limits,
              acc: new_acc,
              root_iri: actual_root_iri,
              path: new_path,
              total_imports: ctx.total_imports
            }

            # Load imports recursively
            case load_imports(unvisited_imports, new_ctx) do
              {:ok, final_acc, _final_total} ->
                # Only build final result at root level (depth 0)
                if ctx.depth == 0 do
                  build_final_result(final_acc, actual_root_iri)
                else
                  {:ok, final_acc, ctx.total_imports + length(unvisited_imports)}
                end

              error ->
                error
            end
          end
        end
    end
  end

  defp load_imports([], %ImportContext{} = ctx) do
    {:ok, ctx.acc, ctx.total_imports}
  end

  defp load_imports([import_iri | rest], %ImportContext{} = ctx) do
    case resolve_and_load_import(import_iri, ctx) do
      {:ok, new_acc, new_total} ->
        # Create updated context with new accumulator and total
        new_ctx = %ImportContext{ctx | acc: new_acc, total_imports: new_total}

        # Recursively process remaining imports
        case load_imports(rest, new_ctx) do
          {:ok, final_acc, final_total} ->
            {:ok, final_acc, final_total}

          {:error, {:circular_dependency, _trace}} = full_error ->
            full_error

          other_error ->
            other_error
        end

      {:error, {:circular_dependency, _trace}} = full_error ->
        # Task 1.1.3.2: Abort load on cycle detection
        full_error

      {:error, {:max_depth_exceeded, _}} = full_error ->
        # Propagate resource limit errors
        full_error

      {:error, {:max_total_imports_exceeded, _, _}} = full_error ->
        # Propagate resource limit errors
        full_error

      {:error, {:max_imports_per_ontology_exceeded, _, _, _}} = full_error ->
        # Propagate resource limit errors
        full_error

      {:error, reason} ->
        Logger.warning("Failed to load import #{import_iri}: #{inspect(reason)}")
        # Continue with other imports (but increment total for failed attempts)
        new_ctx = %ImportContext{ctx | total_imports: ctx.total_imports + 1}
        load_imports(rest, new_ctx)
    end
  end

  defp resolve_and_load_import(import_iri, %ImportContext{} = ctx) do
    case resolve_import_iri(import_iri, ctx.resolver) do
      {:ok, file_path} ->
        case Loader.load_file(file_path) do
          {:ok, ontology} ->
            # Create updated context with incremented total_imports
            new_ctx = %ImportContext{ctx | total_imports: ctx.total_imports + 1}
            load_recursively(ontology, new_ctx)

          error ->
            error
        end

      error ->
        error
    end
  end

  # Task 1.1.2.2: IRI Resolution
  defp resolve_import_iri(iri, resolver) do
    cond do
      # Strategy 1: File URI (with path traversal protection)
      String.starts_with?(iri, "file://") ->
        path = String.replace_prefix(iri, "file://", "")
        absolute_path = Path.expand(path)
        allowed_base = Path.expand(resolver.base_dir)

        # Validate path stays within allowed base directory
        if String.starts_with?(absolute_path, allowed_base <> "/") or absolute_path == allowed_base do
          {:ok, absolute_path}
        else
          Logger.warning("Unauthorized file access attempt blocked: #{iri} -> #{absolute_path}")
          {:error, {:unauthorized_path, "File URI outside allowed directory"}}
        end

      # Strategy 2: Explicit mapping
      Map.has_key?(resolver.mappings, iri) ->
        {:ok, resolver.mappings[iri]}

      # Strategy 3: Convention-based
      true ->
        convention_based_resolve(iri, resolver.base_dir)
    end
  end

  defp convention_based_resolve(iri, base_dir) do
    # Extract potential filename from IRI
    filename_candidates =
      [
        extract_filename_from_iri(iri),
        extract_fragment_from_iri(iri)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&generate_filename_variants/1)

    # Search for matching files
    filename_candidates
    |> Enum.map(&Path.join(base_dir, &1))
    |> Enum.find(&File.exists?/1)
    |> case do
      nil -> {:error, {:iri_not_resolved, iri}}
      path -> {:ok, path}
    end
  end

  defp extract_filename_from_iri(iri) do
    iri
    |> String.replace(~r/#$/, "")
    |> String.split("/")
    |> List.last()
  end

  defp extract_fragment_from_iri(iri) do
    case String.split(iri, "#") do
      [_, fragment] when fragment != "" -> fragment
      _ -> nil
    end
  end

  defp generate_filename_variants(base_name) do
    [
      "#{base_name}.ttl",
      "#{String.downcase(base_name)}.ttl"
    ]
  end

  defp build_iri_resolver(base_dir, opts) do
    mappings = Keyword.get(opts, :iri_resolver, %{})

    resolver = %{
      mappings: mappings,
      base_dir: base_dir
    }

    {:ok, resolver}
  end

  # Task 1.1.2.4: Build ontology metadata with imports
  defp build_ontology_metadata(ontology, depth) do
    {:ok, imports} = extract_imports(ontology.graph)

    %{
      iri: ontology.base_iri,
      path: ontology.path,
      base_iri: ontology.base_iri,
      prefix_map: ontology.prefix_map,
      imports: imports,
      graph: ontology.graph,
      triple_count: RDF.Graph.triple_count(ontology.graph),
      loaded_at: ontology.loaded_at,
      depth: depth
    }
  end

  # Task 1.1.2.3 & 1.1.2.4: Build final result with dataset and import chain
  defp build_final_result(ontologies_map, root_iri) do
    with {:ok, dataset} <- build_provenance_dataset(ontologies_map),
         {:ok, import_chain} <- build_import_chain(ontologies_map, root_iri) do
      {:ok,
       %{
         dataset: dataset,
         ontologies: ontologies_map,
         import_chain: import_chain
       }}
    end
  end

  # Task 1.1.2.4: Build RDF.Dataset with named graphs for provenance
  defp build_provenance_dataset(ontologies_map) do
    dataset =
      ontologies_map
      |> Enum.reduce(RDF.Dataset.new(), fn {iri, metadata}, acc ->
        # Use cached graph from metadata (optimization: eliminates file reloading)
        graph_name = RDF.iri(iri)
        RDF.Dataset.add(acc, metadata.graph, graph_name: graph_name)
      end)

    {:ok, dataset}
  end

  # Task 1.1.2.3: Build import chain structure
  defp build_import_chain(ontologies_map, root_iri) do
    imports =
      ontologies_map
      |> Enum.map(fn {iri, metadata} ->
        %{
          iri: iri,
          path: metadata.path,
          imports: metadata.imports,
          depth: metadata.depth
        }
      end)
      |> Enum.sort_by(& &1.depth)

    max_depth =
      imports
      |> Enum.map(& &1.depth)
      |> Enum.max(fn -> 0 end)

    {:ok,
     %{
       root_iri: root_iri,
       imports: imports,
       depth: max_depth
     }}
  end

  defp has_type?(description, type_iri) do
    types = RDF.Description.get(description, RDF.type(), [])
    types_list = if is_list(types), do: types, else: [types]
    type_iri in types_list
  end

  defp extract_import_iris(description, owl_imports) do
    description
    |> RDF.Description.get(owl_imports, [])
    |> List.wrap()
    |> Enum.filter(&match?(%RDF.IRI{}, &1))
    |> Enum.map(&to_string/1)
  end

  # Task 1.1.3.3: Build diagnostic dependency trace
  @spec build_cycle_trace([String.t()], String.t()) :: cycle_trace()
  defp build_cycle_trace(path, iri) do
    full_path = path ++ [iri]
    cycle_start_index = Enum.find_index(path, &(&1 == iri))

    %{
      cycle_detected_at: iri,
      import_path: full_path,
      cycle_length: length(path) - cycle_start_index,
      human_readable: format_cycle_trace(full_path, cycle_start_index)
    }
  end

  @spec format_cycle_trace([String.t()], non_neg_integer()) :: String.t()
  defp format_cycle_trace(path, cycle_start) do
    path
    |> Enum.with_index()
    |> Enum.map_join("", fn {iri, idx} ->
      marker = if idx == cycle_start, do: "[CYCLE START] ", else: ""
      arrow = if idx > 0, do: " → ", else: ""
      "#{arrow}#{marker}#{iri}"
    end)
  end
end
