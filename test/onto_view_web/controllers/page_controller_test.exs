defmodule OntoViewWeb.PageControllerTest do
  use OntoViewWeb.ConnCase, async: false

  alias OntoView.OntologyHub

  setup do
    # Configure test ontology set
    Application.put_env(:onto_view, :ontology_sets, [
      [
        set_id: "test_set",
        name: "Test Set",
        description: "Test set for page controller",
        versions: [
          [version: "v1.0", root_path: "test/support/fixtures/ontologies/valid_simple.ttl", default: true]
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

  describe "GET /" do
    test "renders landing page when no session", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "OntoView"
      assert html_response(conn, 200) =~ "Ontology Documentation Platform"
    end

    test "0.4.99.4 - Session remembers last-viewed set", %{conn: conn} do
      # First visit a set to populate session
      conn = get(conn, ~p"/sets/test_set")
      assert html_response(conn, 200)

      # Visit landing page - should redirect to last viewed set
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/sets/test_set"
    end

    test "redirects to last viewed set and version when both in session", %{conn: conn} do
      # Visit a specific version to populate session with both set_id and version
      # First load the set so SetResolver doesn't fail
      {:ok, _} = OntologyHub.get_set("test_set", "v1.0")

      # Create a conn with session data
      conn =
        conn
        |> init_test_session(%{last_set_id: "test_set", last_version: "v1.0"})
        |> get(~p"/")

      assert redirected_to(conn) == ~p"/sets/test_set/v1.0/docs"
    end

    test "redirects to set (not version) when only set_id in session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{last_set_id: "test_set"})
        |> get(~p"/")

      assert redirected_to(conn) == ~p"/sets/test_set"
    end
  end
end
