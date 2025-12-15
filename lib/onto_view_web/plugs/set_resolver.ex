defmodule OntoViewWeb.Plugs.SetResolver do
  @moduledoc """
  Plug for resolving and loading ontology sets from route parameters.

  This plug extracts `set_id` and `version` from path parameters, loads the
  corresponding ontology set from the OntologyHub, and assigns it to the
  connection for use in controllers and LiveViews.

  ## Usage

  Add to your router pipeline:

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :put_root_layout, html: {OntoViewWeb.Layouts, :root}
        plug :protect_from_forgery
        plug :put_secure_browser_headers
        plug OntoViewWeb.Plugs.SetResolver
      end

  ## Behavior

  - If `set_id` and `version` are present in path params, loads the ontology set
  - Assigns loaded data to `conn.assigns`:
    - `:ontology_set` - Full OntologySet struct
    - `:triple_store` - TripleStore for queries
    - `:set_id` - Set identifier string
    - `:version` - Version string
  - If set not found, redirects to `/sets` with error flash
  - If no `set_id` in params (e.g., landing page), returns conn unchanged

  ## Examples

      # Route with set_id and version
      GET /sets/elixir/v1.17/docs
      # => Loads elixir v1.17, assigns to conn

      # Route without set params
      GET /
      # => Returns conn unchanged, no loading occurs
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias OntoView.OntologyHub

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    set_id = conn.path_params["set_id"]
    version = conn.path_params["version"]

    case {set_id, version} do
      {nil, _} ->
        # No set_id in path - skip resolution (landing page, etc.)
        conn

      {_, nil} ->
        # set_id without version - skip resolution (version selector page)
        conn
        |> assign(:set_id, set_id)

      {set_id, version} ->
        # Both set_id and version present - load the set
        load_and_assign_set(conn, set_id, version)
    end
  end

  # Private Functions

  defp load_and_assign_set(conn, set_id, version) do
    case OntologyHub.get_set(set_id, version) do
      {:ok, ontology_set} ->
        conn
        |> assign(:ontology_set, ontology_set)
        |> assign(:triple_store, ontology_set.triple_store)
        |> assign(:set_id, set_id)
        |> assign(:version, version)

      {:error, :set_not_found} ->
        conn
        |> put_flash(:error, "Ontology set '#{set_id}' not found")
        |> redirect(to: "/sets")
        |> halt()

      {:error, :version_not_found} ->
        conn
        |> put_flash(:error, "Version '#{version}' not found for set '#{set_id}'")
        |> redirect(to: "/sets/#{set_id}")
        |> halt()

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to load ontology set: #{inspect(reason)}")
        |> redirect(to: "/sets")
        |> halt()
    end
  end
end
