defmodule OntoViewWeb.PageController do
  @moduledoc """
  Controller for the landing page.

  Provides session-based set memory to redirect users to their last-viewed
  ontology set for improved UX.
  """

  use OntoViewWeb, :controller

  @doc """
  Landing page action.

  If the user has previously viewed an ontology set (stored in session),
  redirects them directly to that set. Otherwise, shows the welcome page.

  ## Route
  GET /

  ## Session Keys
  - `:last_set_id` - Last viewed ontology set ID
  - `:last_version` - Last viewed ontology version
  """
  def home(conn, _params) do
    case get_session(conn, :last_set_id) do
      nil ->
        # No previous set - show landing page
        render(conn, :home, layout: false)

      set_id ->
        # Redirect to last viewed set
        version = get_session(conn, :last_version)

        if version do
          # Redirect to docs for specific version
          redirect(conn, to: ~p"/sets/#{set_id}/#{version}/docs")
        else
          # Redirect to version selector
          redirect(conn, to: ~p"/sets/#{set_id}")
        end
    end
  end
end
