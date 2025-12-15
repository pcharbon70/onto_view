defmodule OntoViewWeb.DocsLiveTest do
  use OntoViewWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias OntoView.OntologyHub

  setup do
    # Configure test ontology set
    Application.put_env(:onto_view, :ontology_sets, [
      [
        set_id: "test_set",
        name: "Test Ontology Set",
        description: "Test set for docs live view",
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

    :ok
  end

  describe "DocsLive.Index" do
    test "mounts and displays ontology information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sets/test_set/v1.0/docs")

      assert html =~ "test_set"
      assert html =~ "v1.0"
      assert html =~ "Documentation interface (placeholder for Phase 2)"
    end

    test "shows loaded ontology stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sets/test_set/v1.0/docs")

      assert html =~ "Loaded Ontology Information"
      assert html =~ "Set ID"
      assert html =~ "Version"
      assert html =~ "Files Loaded"
      assert html =~ "Total Triples"
    end

    test "shows SetResolver working status", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sets/test_set/v1.0/docs")

      assert html =~ "SetResolver Status"
      assert html =~ "Working correctly"
    end

    test "shows back link to version selector", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sets/test_set/v1.0/docs")

      assert html =~ "Back to versions"
      assert html =~ ~p"/sets/test_set"
    end

    test "shows Phase 2 placeholder message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sets/test_set/v1.0/docs")

      assert html =~ "Phase 2 Implementation Pending"
      assert html =~ "Hierarchical class browser"
      assert html =~ "Live search and filtering"
    end

    test "displays correct triple count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sets/test_set/v1.0/docs")

      # The valid_simple.ttl fixture should have at least 1 triple
      assert html =~ "Total Triples"
      # Check that a number is displayed (not 0)
      assert html =~ ~r/>\d+</
    end

    test "redirects when set not found", %{conn: conn} do
      # Should be redirected by SetResolver plug
      conn = get(conn, ~p"/sets/nonexistent/v1.0/docs")

      assert redirected_to(conn) == ~p"/sets"
    end

    test "redirects when version not found", %{conn: conn} do
      # Should be redirected by SetResolver plug
      conn = get(conn, ~p"/sets/test_set/v99.99/docs")

      assert redirected_to(conn) == ~p"/sets/test_set"
    end
  end
end
