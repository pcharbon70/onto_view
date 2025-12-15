defmodule OntoViewWeb.SetController do
  @moduledoc """
  Controller for browsing available ontology sets and their versions.

  This controller provides two main views:
  - `index/2` - Lists all available ontology sets
  - `show/2` - Shows versions for a specific ontology set
  """

  use OntoViewWeb, :controller

  alias OntoView.OntologyHub

  @doc """
  Lists all available ontology sets.

  Shows metadata for each set including name, description, available versions,
  and loaded status. Users can select a set to view its versions.

  ## Route
  GET /sets
  """
  def index(conn, _params) do
    sets = OntologyHub.list_sets()
    render(conn, :index, sets: sets)
  end

  @doc """
  Shows all versions for a specific ontology set.

  Displays version list with metadata, default version indicator, and loaded
  status. Users can select a version to view its documentation.

  ## Route
  GET /sets/:set_id

  ## Parameters
  - `set_id` - Ontology set identifier (e.g., "elixir")
  """
  def show(conn, %{"set_id" => set_id}) do
    case OntologyHub.list_versions(set_id) do
      {:ok, versions} ->
        # Get set configuration for display
        sets = OntologyHub.list_sets()
        set_info = Enum.find(sets, &(&1.set_id == set_id))

        # Remember this set in session (Task 0.4.5)
        conn = put_session(conn, :last_set_id, set_id)

        render(conn, :show,
          set_id: set_id,
          set_info: set_info,
          versions: versions
        )

      {:error, :set_not_found} ->
        conn
        |> put_flash(:error, "Ontology set '#{set_id}' not found")
        |> redirect(to: ~p"/sets")
    end
  end
end
