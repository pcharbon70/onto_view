defmodule OntoView.Integration.WebNavigationTest do
  use OntoViewWeb.ConnCase, async: false

  alias OntoView.OntologyHub
  alias Phoenix.Flash

  # Task 0.99.3 — End-to-End Web Navigation
  #
  # These tests validate the complete user journey from landing page through
  # set selection, version selection, and documentation viewing, ensuring
  # SetResolver loads the correct set at each step and session memory works
  # correctly across page reloads.

  describe "End-to-End Web Navigation (0.99.3)" do
    setup do
      # Configure 2 ontology sets with multiple versions for navigation testing
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "nav_set_alpha",
          name: "Navigation Test Alpha",
          description: "First test ontology for navigation",
          homepage_url: "http://example.org/alpha",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
              default: false
            ],
            [
              version: "v2.0",
              root_path: "test/support/fixtures/ontologies/custom_prefixes.ttl",
              default: true
            ]
          ],
          auto_load: false,
          priority: 1
        ],
        [
          set_id: "nav_set_beta",
          name: "Navigation Test Beta",
          description: "Second test ontology for navigation",
          homepage_url: "http://example.org/beta",
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

      # Restart OntologyHub with test configuration
      :ok = Supervisor.terminate_child(OntoView.Supervisor, OntologyHub)
      {:ok, _} = Supervisor.restart_child(OntoView.Supervisor, OntologyHub)

      :ok
    end

    test "0.99.3.1 - Navigate from landing → set browser → version selector → docs", %{
      conn: conn
    } do
      # Step 1: Landing page (no session history)
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "OntoView"

      # Step 2: Navigate to set browser (/sets)
      conn = get(conn, "/sets")
      assert html_response(conn, 200) =~ "Navigation Test Alpha"
      assert html_response(conn, 200) =~ "Navigation Test Beta"
      assert html_response(conn, 200) =~ "nav_set_alpha"
      assert html_response(conn, 200) =~ "nav_set_beta"

      # Step 3: Select a specific set to view versions (/sets/nav_set_alpha)
      conn = get(conn, "/sets/nav_set_alpha")
      response = html_response(conn, 200)
      assert response =~ "Navigation Test Alpha"
      assert response =~ "v1.0"
      assert response =~ "v2.0"

      # Verify session remembers set_id
      assert get_session(conn, :last_set_id) == "nav_set_alpha"

      # Step 4: Select a version and navigate to docs (/sets/nav_set_alpha/v1.0/docs)
      conn = get(conn, "/sets/nav_set_alpha/v1.0/docs")
      assert html_response(conn, 200) =~ "nav_set_alpha"
      assert html_response(conn, 200) =~ "v1.0"
      assert html_response(conn, 200) =~ "Documentation interface"

      # Verify session remembers both set_id and version
      assert get_session(conn, :last_set_id) == "nav_set_alpha"
      assert get_session(conn, :last_version) == "v1.0"
    end

    test "0.99.3.2 - Verify SetResolver loads correct set at each step", %{conn: conn} do
      # Navigate directly to docs page (SetResolver should load the set)
      conn1 = get(conn, "/sets/nav_set_alpha/v1.0/docs")
      response1 = html_response(conn1, 200)

      # Verify SetResolver loaded the correct set (via session)
      assert get_session(conn1, :last_set_id) == "nav_set_alpha"
      assert get_session(conn1, :last_version) == "v1.0"

      # Verify page displays correct content
      assert response1 =~ "nav_set_alpha"
      assert response1 =~ "v1.0"
      assert response1 =~ "SetResolver Status"
      assert response1 =~ "Working correctly"

      # Navigate to different version
      conn2 = get(conn, "/sets/nav_set_alpha/v2.0/docs")
      response2 = html_response(conn2, 200)

      # Verify SetResolver loaded the different version
      assert get_session(conn2, :last_set_id) == "nav_set_alpha"
      assert get_session(conn2, :last_version) == "v2.0"
      assert response2 =~ "v2.0"

      # Navigate to different set
      conn3 = get(conn, "/sets/nav_set_beta/v1.0/docs")
      response3 = html_response(conn3, 200)

      # Verify SetResolver loaded the different set
      assert get_session(conn3, :last_set_id) == "nav_set_beta"
      assert get_session(conn3, :last_version) == "v1.0"
      assert response3 =~ "nav_set_beta"
      assert response3 =~ "v1.0"
    end

    test "0.99.3.3 - Verify session memory works across page reloads", %{conn: conn} do
      # Visit a specific set+version to establish session memory
      conn = get(conn, "/sets/nav_set_alpha/v2.0/docs")
      assert html_response(conn, 200)

      # Verify session was set
      assert get_session(conn, :last_set_id) == "nav_set_alpha"
      assert get_session(conn, :last_version) == "v2.0"

      # Navigate back to landing page - should redirect to last viewed set
      conn = get(conn, "/")
      assert redirected_to(conn, 302) == "/sets/nav_set_alpha/v2.0/docs"

      # Follow the redirect
      conn = get(conn, "/sets/nav_set_alpha/v2.0/docs")
      assert html_response(conn, 200) =~ "nav_set_alpha"
      assert html_response(conn, 200) =~ "v2.0"

      # Visit a different set+version
      conn = get(conn, "/sets/nav_set_beta/v1.0/docs")
      assert html_response(conn, 200)

      # Verify session updated
      assert get_session(conn, :last_set_id) == "nav_set_beta"
      assert get_session(conn, :last_version) == "v1.0"

      # Navigate to landing again - should redirect to new last viewed set
      conn = get(conn, "/")
      assert redirected_to(conn, 302) == "/sets/nav_set_beta/v1.0/docs"

      # Follow the redirect
      conn = get(conn, "/sets/nav_set_beta/v1.0/docs")
      assert html_response(conn, 200) =~ "nav_set_beta"
      assert html_response(conn, 200) =~ "v1.0"
    end

    test "navigation flow with invalid set_id returns 404 redirect", %{conn: conn} do
      # Try to access non-existent set
      conn = get(conn, "/sets/nonexistent_set")
      assert redirected_to(conn, 302) == "/sets"
      assert Flash.get(conn.assigns.flash, :error) =~ "Ontology set 'nonexistent_set' not found"
    end

    test "navigation flow with invalid version returns 404 redirect", %{conn: conn} do
      # Try to access non-existent version
      conn = get(conn, "/sets/nav_set_alpha/v99.0/docs")
      assert redirected_to(conn, 302) == "/sets/nav_set_alpha"
      assert Flash.get(conn.assigns.flash, :error) =~ "Version 'v99.0' not found"
    end

    test "session memory persists across multiple navigation actions", %{conn: conn} do
      # Start with no session
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "OntoView"

      # Browse to set browser
      conn = get(conn, "/sets")
      assert html_response(conn, 200)

      # View version selector (sets session with set_id only)
      conn = get(conn, "/sets/nav_set_alpha")
      assert get_session(conn, :last_set_id) == "nav_set_alpha"

      # Session should not have version yet
      assert get_session(conn, :last_version) == nil

      # Navigate to docs (sets both set_id and version)
      conn = get(conn, "/sets/nav_set_alpha/v1.0/docs")
      assert get_session(conn, :last_set_id) == "nav_set_alpha"
      assert get_session(conn, :last_version) == "v1.0"

      # Go back to landing - should redirect to full path
      conn = get(conn, "/")
      assert redirected_to(conn, 302) == "/sets/nav_set_alpha/v1.0/docs"

      # Navigate to different version of same set
      conn = get(conn, "/sets/nav_set_alpha/v2.0/docs")

      # Session should update to new version
      assert get_session(conn, :last_set_id) == "nav_set_alpha"
      assert get_session(conn, :last_version) == "v2.0"

      # Landing redirect should point to new version
      conn = get(conn, "/")
      assert redirected_to(conn, 302) == "/sets/nav_set_alpha/v2.0/docs"
    end

    test "SetResolver assigns all required data to connection", %{conn: conn} do
      # Navigate to docs page
      conn = get(conn, "/sets/nav_set_alpha/v1.0/docs")
      response = html_response(conn, 200)

      # Verify session contains correct data (proves SetResolver worked)
      assert get_session(conn, :last_set_id) == "nav_set_alpha"
      assert get_session(conn, :last_version) == "v1.0"

      # Verify page displays SetResolver success indicator
      assert response =~ "SetResolver Status"
      assert response =~ "Working correctly"

      # Verify correct set and version displayed
      assert response =~ "nav_set_alpha"
      assert response =~ "v1.0"

      # Verify triple count is displayed (proves triple_store was assigned)
      assert response =~ "Total Triples"
      assert response =~ ~r/\d+/  # Contains a number

      # Verify files loaded count is displayed (proves ontology_set was assigned)
      assert response =~ "Files Loaded"
    end

    test "navigation between different sets maintains cache performance", %{conn: conn} do
      # Get initial cache stats
      initial_stats = OntologyHub.get_stats()

      # Navigate to first set
      conn = get(conn, "/sets/nav_set_alpha/v1.0/docs")
      assert html_response(conn, 200)

      # Navigate to second set
      conn = get(conn, "/sets/nav_set_beta/v1.0/docs")
      assert html_response(conn, 200)

      # Navigate back to first set (should hit cache)
      conn = get(conn, "/sets/nav_set_alpha/v1.0/docs")
      assert html_response(conn, 200)

      # Get final cache stats
      final_stats = OntologyHub.get_stats()

      # Verify cache was used
      new_loads = final_stats.load_count - initial_stats.load_count
      new_hits = final_stats.cache_hit_count - initial_stats.cache_hit_count

      # Should have loaded 2 sets (alpha and beta)
      assert new_loads == 2

      # Third navigation should have hit cache (alpha already loaded)
      assert new_hits >= 1

      # Both sets should be in cache
      assert final_stats.loaded_count >= 2
    end
  end
end
