defmodule OntoView.Ontology.TripleStore.BlankNodeStabilizer do
  @moduledoc """
  Stabilizes blank node identifiers across all loaded ontologies.

  ## Problem Statement

  RDF.ex generates non-deterministic blank node IDs during Turtle parsing.
  While these IDs are unique within a single parse, they have two critical
  limitations:

  1. **Non-determinism**: The same file parsed twice generates different IDs
  2. **Collision risk**: Multiple ontologies can generate identical IDs

  ## Solution

  This module implements global blank node stabilization using a hybrid
  provenance + incremental counter strategy:

  - Format: `"{ontology_iri}#_bn{counter}"`
  - Example: `"http://example.org/ont#_bn0001"`

  ## Subtask Coverage

  - Task 1.2.2.1: Detect blank nodes
  - Task 1.2.2.2: Generate stable internal identifiers
  - Task 1.2.2.3: Preserve blank node reference consistency

  ## Architecture

  Three-stage pipeline:

  1. **Detect**: Scan all triples, extract blank node IDs grouped by ontology
  2. **Generate**: Create stable IDs using provenance + counter
  3. **Apply**: Replace original IDs with stable IDs in all triple positions

  ## Uniqueness Guarantees

  - **Within ontology**: Counter ensures uniqueness
  - **Across ontologies**: Ontology IRI prefix ensures uniqueness
  - **Reference consistency**: Mapping table ensures same source ID → same stable ID

  Part of Task 1.2.2 — Blank Node Stabilization
  """

  alias OntoView.Ontology.TripleStore.Triple

  @doc """
  Stabilizes all blank node identifiers in the given triples.

  This is the main entry point that orchestrates the three-stage pipeline:
  detect → generate → apply.

  ## Task Coverage

  Implements complete Task 1.2.2 by coordinating all subtasks.

  ## Parameters

  - `triples` - List of Triple.t() structs (may contain unstable blank node IDs)

  ## Returns

  List of Triple.t() structs with stabilized blank node IDs.

  ## Examples

      iex> triples = [
      ...>   %Triple{
      ...>     subject: {:iri, "http://example.org/Subject"},
      ...>     predicate: {:iri, "http://example.org/hasValue"},
      ...>     object: {:blank, "b1"},
      ...>     graph: "http://example.org/ont#"
      ...>   }
      ...> ]
      iex> stabilized = BlankNodeStabilizer.stabilize(triples)
      iex> [triple] = stabilized
      iex> {:blank, stable_id} = triple.object
      iex> String.contains?(stable_id, "#_bn")
      true
      iex> String.starts_with?(stable_id, "http://example.org/ont#")
      true
  """
  @spec stabilize([Triple.t()]) :: [Triple.t()]
  def stabilize(triples) when is_list(triples) do
    # Stage 1: Detect blank nodes grouped by ontology (Task 1.2.2.1)
    blank_nodes_by_ontology = detect_blank_nodes(triples)

    # Stage 2: Generate stable IDs (Task 1.2.2.2)
    id_mappings = generate_stable_ids(blank_nodes_by_ontology)

    # Stage 3: Apply stable IDs (Task 1.2.2.3)
    apply_stable_ids(triples, id_mappings)
  end

  # Private functions

  # Task 1.2.2.1: Detect blank nodes
  # Scans all triples and extracts blank node IDs grouped by ontology graph
  @spec detect_blank_nodes([Triple.t()]) :: %{String.t() => MapSet.t(String.t())}
  defp detect_blank_nodes(triples) do
    Enum.reduce(triples, %{}, fn triple, acc ->
      ontology = triple.graph

      # Collect blank node IDs from subject, predicate (rare), and object
      blank_ids =
        [triple.subject, triple.predicate, triple.object]
        |> Enum.filter(&match?({:blank, _}, &1))
        |> Enum.map(fn {:blank, id} -> id end)

      # Add to set for this ontology
      if blank_ids == [] do
        acc
      else
        Map.update(
          acc,
          ontology,
          MapSet.new(blank_ids),
          fn existing -> Enum.reduce(blank_ids, existing, &MapSet.put(&2, &1)) end
        )
      end
    end)
  end

  # Task 1.2.2.2: Generate stable internal identifiers
  # Creates mapping from original blank node IDs to stable IDs
  # Format: "{ontology_iri}#_bn{counter}"
  @spec generate_stable_ids(%{String.t() => MapSet.t(String.t())}) :: %{
          String.t() => %{String.t() => String.t()}
        }
  defp generate_stable_ids(blank_nodes_by_ontology) do
    Map.new(blank_nodes_by_ontology, fn {ontology_iri, blank_node_ids} ->
      # Sort blank node IDs for deterministic ordering
      sorted_ids = Enum.sort(MapSet.to_list(blank_node_ids))

      # Generate stable IDs with zero-padded counter
      id_mapping =
        sorted_ids
        |> Enum.with_index(1)
        |> Map.new(fn {original_id, counter} ->
          stable_id = "#{ontology_iri}_bn#{String.pad_leading(Integer.to_string(counter), 4, "0")}"
          {original_id, stable_id}
        end)

      {ontology_iri, id_mapping}
    end)
  end

  # Task 1.2.2.3: Preserve blank node reference consistency
  # Replaces original blank node IDs with stable IDs in all triple positions
  @spec apply_stable_ids([Triple.t()], %{String.t() => %{String.t() => String.t()}}) :: [
          Triple.t()
        ]
  defp apply_stable_ids(triples, id_mappings) do
    Enum.map(triples, fn triple ->
      ontology = triple.graph
      mapping = Map.get(id_mappings, ontology, %{})

      %Triple{
        triple
        | subject: stabilize_term(triple.subject, mapping),
          predicate: stabilize_term(triple.predicate, mapping),
          object: stabilize_term(triple.object, mapping)
      }
    end)
  end

  # Helper: Stabilize a single triple term (subject, predicate, or object)
  defp stabilize_term({:blank, original_id}, mapping) do
    case Map.get(mapping, original_id) do
      nil -> {:blank, original_id}
      stable_id -> {:blank, stable_id}
    end
  end

  defp stabilize_term(other_term, _mapping), do: other_term
end
