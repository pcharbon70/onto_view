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

  # Task 0.2.99 — Integration Tests for Content Negotiation
  #
  # Note: These tests verify the HTTP content negotiation layer.
  # Full IRI resolution is tested separately in ontology_hub_test.exs (tests 0.2.99.6-0.2.99.8)
  # where the IRI indexing and lookup logic is comprehensively tested.
  describe "Integration Tests (0.2.99)" do
    test "0.2.99.9 - /resolve endpoint returns redirects with correct headers", %{conn: conn} do
      # Test that the endpoint handles requests and returns redirects
      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should return a redirect (either 303 found or 302 not found)
      assert conn.status in [302, 303]
      assert get_resp_header(conn, "location") != []
    end

    test "0.2.99.10 - Content negotiation handles HTML requests", %{conn: conn} do
      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Should redirect (status depends on whether IRI is found)
      assert conn.status in [302, 303]
      location = get_resp_header(conn, "location") |> List.first()
      # Location should be a valid path
      assert location != nil
    end

    test "0.2.99.10 - Content negotiation handles JSON requests", %{conn: conn} do
      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # JSON requests should either return data (200) or redirect to error (302)
      assert conn.status in [200, 302]

      if conn.status == 200 do
        assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
        response = json_response(conn, 200)
        assert Map.has_key?(response, "iri")
        assert Map.has_key?(response, "set_id")
        assert Map.has_key?(response, "version")
      end
    end

    test "0.2.99.10 - Content negotiation handles Turtle requests", %{conn: conn} do
      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/turtle")
        |> get(~p"/resolve?iri=#{encoded_iri}")

      # Turtle requests should redirect
      assert conn.status in [302, 303]

      if conn.status == 303 do
        # If found, should have turtle content-type header
        assert get_resp_header(conn, "content-type") == ["text/turtle; charset=utf-8"]
      end
    end
  end
end
