defmodule OntoViewWeb.ResolveControllerTest do
  use OntoViewWeb.ConnCase, async: false

  alias OntoView.OntologyHub

  setup do
    # Configure test ontology set
    Application.put_env(:onto_view, :ontology_sets, [
      [
        set_id: "test_set",
        name: "Test Set",
        description: "Test set for resolve endpoint",
        homepage_url: "http://example.org/test",
        versions: [
          [
            version: "v1.0",
            root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
            default: true
          ]
        ],
        auto_load: false,
        priority: 1
      ]
    ])

    # Restart OntologyHub to pick up new config
    :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
    {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

    # Manually load the set to ensure it's available
    {:ok, _set} = OntologyHub.get_set("test_set", "v1.0")

    :ok
  end

  describe "GET /resolve - error cases" do
    test "redirects when IRI not found", %{conn: conn} do
      conn = get(conn, ~p"/resolve?iri=http://example.org/nonexistent%23")

      assert redirected_to(conn) == ~p"/sets"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "IRI 'http://example.org/nonexistent#' not found"
    end

    test "redirects when iri parameter is missing", %{conn: conn} do
      conn = get(conn, ~p"/resolve")

      assert redirected_to(conn) == ~p"/sets"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Missing 'iri' query parameter"
    end

    test "accepts URL-encoded IRIs", %{conn: conn} do
      # Test that URL-encoded IRIs are accepted (will redirect since not found)
      encoded_iri = URI.encode_www_form("http://example.org/MyClass")
      conn = get(conn, ~p"/resolve?iri=#{encoded_iri}")

      # Should redirect to /sets (not crash)
      assert redirected_to(conn) == ~p"/sets"
    end
  end

  describe "GET /resolve - content negotiation" do
    test "accepts text/html Accept header without crashing", %{conn: conn} do
      iri = "http://example.org/test"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should handle the request without crashing
      # Will redirect since IRI not found, but that's expected
      assert conn.status in [302, 303]
    end

    test "accepts application/json Accept header without crashing", %{conn: conn} do
      iri = "http://example.org/test"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should handle JSON requests
      assert conn.status in [200, 302]
    end

    test "accepts text/turtle Accept header without crashing", %{conn: conn} do
      iri = "http://example.org/test"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/turtle")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should handle turtle requests
      assert conn.status in [302, 303]
    end

    test "accepts application/rdf+xml Accept header without crashing", %{conn: conn} do
      iri = "http://example.org/test"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "application/rdf+xml")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should handle RDF/XML requests
      assert conn.status in [302, 303]
    end

    test "handles wildcard Accept header", %{conn: conn} do
      iri = "http://example.org/test"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "*/*")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should default to HTML behavior
      assert conn.status in [302, 303]
    end

    test "handles browser-like complex Accept header", %{conn: conn} do
      iri = "http://example.org/test"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should handle complex Accept headers
      assert conn.status in [302, 303]
    end
  end
end
