defmodule OntoView.FixtureHelpers do
  @moduledoc """
  Helper functions for constructing test fixture paths.

  This module centralizes fixture path construction to eliminate duplication
  across test files and make it easier to reorganize fixtures if needed.
  """

  @fixtures_base "test/support/fixtures/ontologies"

  @doc """
  Returns the path to a fixture file in the base ontologies directory.

  ## Examples

      iex> OntoView.FixtureHelpers.fixture_path("simple.ttl")
      "test/support/fixtures/ontologies/simple.ttl"
  """
  def fixture_path(filename) do
    Path.join(@fixtures_base, filename)
  end

  @doc """
  Returns the path to a fixture file in the imports subdirectory.

  ## Examples

      iex> OntoView.FixtureHelpers.imports_fixture("root.ttl")
      "test/support/fixtures/ontologies/imports/root.ttl"
  """
  def imports_fixture(filename) do
    Path.join([@fixtures_base, "imports", filename])
  end

  @doc """
  Returns the path to a fixture file in the cycles subdirectory.

  ## Examples

      iex> OntoView.FixtureHelpers.cycles_fixture("cycle_a.ttl")
      "test/support/fixtures/ontologies/cycles/cycle_a.ttl"
  """
  def cycles_fixture(filename) do
    Path.join([@fixtures_base, "cycles", filename])
  end

  @doc """
  Returns the path to a fixture file in the integration subdirectory.

  ## Examples

      iex> OntoView.FixtureHelpers.integration_fixture("deep_level_0.ttl")
      "test/support/fixtures/ontologies/integration/deep_level_0.ttl"
  """
  def integration_fixture(filename) do
    Path.join([@fixtures_base, "integration", filename])
  end

  @doc """
  Returns the path to a fixture file in the resource_limits subdirectory.

  ## Examples

      iex> OntoView.FixtureHelpers.resource_limits_fixture("too_many_imports.ttl")
      "test/support/fixtures/ontologies/resource_limits/too_many_imports.ttl"
  """
  def resource_limits_fixture(filename) do
    Path.join([@fixtures_base, "resource_limits", filename])
  end

  @doc """
  Returns the base fixtures directory path.

  ## Examples

      iex> OntoView.FixtureHelpers.fixtures_dir()
      "test/support/fixtures/ontologies"
  """
  def fixtures_dir do
    @fixtures_base
  end
end
