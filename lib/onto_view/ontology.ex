defmodule OntoView.Ontology do
  @moduledoc """
  The Ontology context.

  Provides the public interface for loading, parsing, and querying
  OWL/RDF ontologies expressed in Turtle format.
  """

  alias OntoView.Ontology.{Loader, ImportResolver, TripleStore}

  @doc """
  Loads an ontology file from the filesystem.

  See `OntoView.Ontology.Loader.load_file/2` for details.
  """
  defdelegate load_file(path, opts \\ []), to: Loader

  @doc """
  Loads an ontology file, raising on error.

  See `OntoView.Ontology.Loader.load_file!/2` for details.
  """
  defdelegate load_file!(path, opts \\ []), to: Loader

  @doc """
  Loads an ontology with all its recursive imports.

  See `OntoView.Ontology.ImportResolver.load_with_imports/2` for details.
  """
  defdelegate load_with_imports(path, opts \\ []), to: ImportResolver

  @doc """
  Loads an ontology with all its recursive imports, raising on error.

  See `OntoView.Ontology.ImportResolver.load_with_imports!/2` for details.
  """
  defdelegate load_with_imports!(path, opts \\ []), to: ImportResolver

  @doc """
  Builds a canonical triple store from loaded ontologies.

  Extracts all RDF triples from the loaded ontology dataset and converts
  them to a normalized, queryable format. This provides the foundation
  for OWL entity extraction (Section 1.3).

  See `OntoView.Ontology.TripleStore.from_loaded_ontologies/1` for details.

  Part of Task 1.2.1 — RDF Triple Parsing
  """
  defdelegate build_triple_store(loaded_ontologies),
    to: TripleStore,
    as: :from_loaded_ontologies
end
