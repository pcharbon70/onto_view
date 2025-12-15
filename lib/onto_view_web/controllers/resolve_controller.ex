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
  Resolves an IRI to its documentation view with content negotiation.

  Implements W3C Linked Data best practices by inspecting the Accept header
  and returning appropriate responses:
  - text/html: 303 redirect to documentation view
  - text/turtle: 303 redirect to TTL export endpoint
  - application/json: JSON metadata response

  ## Parameters
  - `iri` - URL-encoded IRI to resolve

  ## Returns
  - 303 redirect to appropriate view based on Accept header if IRI found
  - JSON response for application/json requests
  - Redirect with error message if IRI not found
  """
  def resolve(conn, %{"iri" => iri}) do
    case OntologyHub.resolve_iri(iri) do
      {:ok, result} ->
        handle_content_negotiation(conn, result)

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

  # Private Functions

  @doc false
  defp handle_content_negotiation(conn, result) do
    accept_header = get_req_header(conn, "accept") |> List.first() || "text/html"

    cond do
      # JSON response - return metadata directly
      String.contains?(accept_header, "application/json") ->
        handle_json_response(conn, result)

      # Turtle/RDF - redirect to TTL export endpoint
      String.contains?(accept_header, "text/turtle") or
      String.contains?(accept_header, "application/rdf+xml") ->
        handle_turtle_redirect(conn, result)

      # HTML (default) - redirect to documentation view
      true ->
        handle_html_redirect(conn, result)
    end
  end

  @doc false
  defp handle_html_redirect(conn, result) do
    # Build documentation URL
    # For now, redirect to docs landing page
    # Full entity-specific routing will be in Phase 2
    docs_url = ~p"/sets/#{result.set_id}/#{result.version}/docs"

    conn
    |> put_status(303)
    |> put_resp_header("location", docs_url)
    |> send_resp(303, "")
  end

  @doc false
  defp handle_turtle_redirect(conn, result) do
    # Redirect to TTL export endpoint
    # This endpoint will be implemented in Phase 5 (Export functionality)
    # For now, return placeholder URL
    ttl_url = "/sets/#{result.set_id}/#{result.version}/export.ttl"

    conn
    |> put_status(303)
    |> put_resp_header("content-type", "text/turtle; charset=utf-8")
    |> put_resp_header("location", ttl_url)
    |> send_resp(303, "")
  end

  @doc false
  defp handle_json_response(conn, result) do
    # Get base URL from connection
    base_url = OntoViewWeb.Endpoint.url()

    # Return JSON metadata about the resolved IRI
    json(conn, %{
      iri: result.iri,
      set_id: result.set_id,
      version: result.version,
      entity_type: result.entity_type,
      documentation_url: "#{base_url}/sets/#{result.set_id}/#{result.version}/docs",
      ttl_export_url: "#{base_url}/sets/#{result.set_id}/#{result.version}/export.ttl"
    })
  end
end
