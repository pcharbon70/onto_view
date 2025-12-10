defmodule OntoView.Ontology do
  @moduledoc """
  The Ontology context.

  Provides the public interface for loading, parsing, and querying
  OWL/RDF ontologies expressed in Turtle format.
  """

  alias OntoView.Ontology.{Loader, ImportResolver}

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
end
