defmodule OntoViewWeb.ResolveController do
  @moduledoc """
  Controller for IRI resolution and content negotiation.

  This controller implements W3C Linked Data best practices for dereferenceable
  IRIs. It resolves an IRI to its containing ontology set and redirects to the
  appropriate documentation view based on content negotiation.

  ## Content Negotiation

  - `text/html` → Redirect to documentation view
  - `text/turtle` → Redirect to TTL export (future)
  - `application/json` → Return JSON metadata (future)

  ## Route
  GET /resolve?iri=<url-encoded-iri>

  ## Example

      GET /resolve?iri=http%3A%2F%2Fexample.org%2FMyClass
      Accept: text/html
      → 303 See Other
      Location: /sets/elixir/v1.17/docs/classes/<encoded-iri>

  Part of Task 0.2.5 — Content Negotiation Endpoint
  """

  use OntoViewWeb, :controller

  alias OntoView.OntologyHub

  @doc """
  Resolves an IRI to its documentation view.

  Currently implements basic resolution with HTML redirect. Full content
  negotiation support will be added in Task 0.2.5.

  ## Parameters
  - `iri` - URL-encoded IRI to resolve

  ## Returns
  - 303 redirect to documentation view if IRI found
  - 404 with error message if IRI not found
  """
  def resolve(conn, %{"iri" => iri}) do
    case OntologyHub.resolve_iri(iri) do
      {:ok, result} ->
        # Build documentation URL
        # For now, redirect to docs landing page
        # Full entity-specific routing will be in Phase 2
        docs_url = ~p"/sets/#{result.set_id}/#{result.version}/docs"

        conn
        |> put_status(:see_other)
        |> redirect(external: docs_url)

      {:error, :iri_not_found} ->
        conn
        |> put_flash(:error, "IRI '#{iri}' not found in any loaded ontology set")
        |> redirect(to: ~p"/sets")
    end
  end

  def resolve(conn, _params) do
    conn
    |> put_flash(:error, "Missing 'iri' query parameter")
    |> redirect(to: ~p"/sets")
  end
end
