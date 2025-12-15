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
        auto_load: true,
        priority: 1
      ]
    ])

    # Restart OntologyHub to pick up new config
    :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
    {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

    # Wait for auto-load to complete
    Process.sleep(1100)

    :ok
  end

  describe "GET /resolve" do
    test "redirects when IRI not found (no sets loaded)", %{conn: conn} do
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
end
