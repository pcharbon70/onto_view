defmodule OntoViewWeb.SetControllerTest do
  use OntoViewWeb.ConnCase, async: false

  alias OntoView.OntologyHub

  setup do
    # Configure test ontology sets
    Application.put_env(:onto_view, :ontology_sets, [
      [
        set_id: "test_set_1",
        name: "Test Set 1",
        description: "First test ontology set",
        homepage_url: "http://example.org/test1",
        versions: [
          [
            version: "v1.0",
            root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
            default: true
          ],
          [
            version: "v2.0",
            root_path: "test/support/fixtures/ontologies/custom_prefixes.ttl",
            default: false
          ]
        ],
        auto_load: false,
        priority: 1
      ],
      [
        set_id: "test_set_2",
        name: "Test Set 2",
        description: "Second test ontology set",
        homepage_url: "http://example.org/test2",
        versions: [
          [
            version: "v1.0",
            root_path: "test/support/fixtures/ontologies/blank_nodes.ttl",
            default: true
          ]
        ],
        auto_load: false,
        priority: 2
      ]
    ])

    # Restart OntologyHub to pick up new config
    :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
    {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

    :ok
  end

  describe "GET /sets" do
    test "lists all available ontology sets", %{conn: conn} do
      conn = get(conn, ~p"/sets")

      assert html_response(conn, 200)
      assert html = html_response(conn, 200)
      assert html =~ "Available Ontology Sets"
      assert html =~ "Test Set 1"
      assert html =~ "Test Set 2"
      assert html =~ "First test ontology set"
      assert html =~ "Second test ontology set"
    end

    test "shows version counts for each set", %{conn: conn} do
      conn = get(conn, ~p"/sets")

      html = html_response(conn, 200)
      # Test Set 1 has 2 versions
      assert html =~ "Versions:"
    end

    test "shows default version for each set", %{conn: conn} do
      conn = get(conn, ~p"/sets")

      html = html_response(conn, 200)
      assert html =~ "Default:"
      assert html =~ "v1.0"
    end

    test "shows empty state when no sets configured", %{conn: conn} do
      # Configure empty sets
      Application.put_env(:onto_view, :ontology_sets, [])
      :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
      {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

      conn = get(conn, ~p"/sets")

      html = html_response(conn, 200)
      assert html =~ "No ontology sets are currently configured"
    end
  end

  describe "GET /sets/:set_id" do
    test "shows versions for a specific set", %{conn: conn} do
      conn = get(conn, ~p"/sets/test_set_1")

      assert html = html_response(conn, 200)
      assert html =~ "Test Set 1"
      assert html =~ "Available Versions"
      assert html =~ "v1.0"
      assert html =~ "v2.0"
      assert html =~ "DEFAULT"
    end

    test "shows back link to all sets", %{conn: conn} do
      conn = get(conn, ~p"/sets/test_set_1")

      html = html_response(conn, 200)
      assert html =~ "Back to all sets"
      assert html =~ ~p"/sets"
    end

    test "shows homepage link if available", %{conn: conn} do
      conn = get(conn, ~p"/sets/test_set_1")

      html = html_response(conn, 200)
      assert html =~ "Visit homepage"
      assert html =~ "http://example.org/test1"
    end

    test "shows View Docs links for each version", %{conn: conn} do
      conn = get(conn, ~p"/sets/test_set_1")

      html = html_response(conn, 200)
      assert html =~ "View Docs"
      assert html =~ ~p"/sets/test_set_1/v1.0/docs"
      assert html =~ ~p"/sets/test_set_1/v2.0/docs"
    end

    test "redirects to /sets when set not found", %{conn: conn} do
      conn = get(conn, ~p"/sets/nonexistent")

      assert redirected_to(conn) == ~p"/sets"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Ontology set 'nonexistent' not found"
    end
  end
end
