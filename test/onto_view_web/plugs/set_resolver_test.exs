defmodule OntoViewWeb.Plugs.SetResolverTest do
  use OntoViewWeb.ConnCase, async: false

  alias OntoViewWeb.Plugs.SetResolver
  alias OntoView.OntologyHub
  alias Phoenix.Flash

  describe "SetResolver plug" do
    setup do
      # Configure test ontology sets
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "test_set",
          name: "Test Ontology Set",
          description: "Test set for SetResolver",
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

    test "skips resolution when no set_id in path params", %{conn: conn} do
      conn =
        conn
        |> Map.put(:path_params, %{})
        |> SetResolver.call([])

      # Should return conn unchanged
      refute Map.has_key?(conn.assigns, :ontology_set)
      refute Map.has_key?(conn.assigns, :set_id)
      refute Map.has_key?(conn.assigns, :version)
    end

    test "assigns only set_id when version is missing", %{conn: conn} do
      conn =
        conn
        |> Map.put(:path_params, %{"set_id" => "test_set"})
        |> SetResolver.call([])

      # Should assign set_id but not load the set
      assert conn.assigns.set_id == "test_set"
      refute Map.has_key?(conn.assigns, :ontology_set)
      refute Map.has_key?(conn.assigns, :version)
    end

    test "loads and assigns ontology set when both set_id and version present", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:path_params, %{"set_id" => "test_set", "version" => "v1.0"})
        |> SetResolver.call([])

      # Should load and assign the ontology set
      assert conn.assigns.set_id == "test_set"
      assert conn.assigns.version == "v1.0"
      assert %OntoView.OntologyHub.OntologySet{} = conn.assigns.ontology_set
      assert conn.assigns.ontology_set.set_id == "test_set"
      assert conn.assigns.ontology_set.version == "v1.0"
      assert conn.assigns.triple_store == conn.assigns.ontology_set.triple_store
    end

    test "redirects to /sets when set_id not found", %{conn: conn} do
      conn =
        conn
        |> Map.put(:path_params, %{"set_id" => "nonexistent", "version" => "v1.0"})
        |> SetResolver.call([])

      # Should redirect with error flash
      assert conn.halted
      assert redirected_to(conn) == "/sets"
      assert Flash.get(conn.assigns.flash, :error) =~ "Ontology set 'nonexistent' not found"
    end

    test "redirects to /sets/:set_id when version not found", %{conn: conn} do
      conn =
        conn
        |> Map.put(:path_params, %{"set_id" => "test_set", "version" => "v99.99"})
        |> SetResolver.call([])

      # Should redirect with error flash
      assert conn.halted
      assert redirected_to(conn) == "/sets/test_set"
      assert Flash.get(conn.assigns.flash, :error) =~ "Version 'v99.99' not found for set 'test_set'"
    end

    test "handles load errors gracefully", %{conn: conn} do
      # Configure a set with invalid root_path to trigger load error
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "broken_set",
          name: "Broken Set",
          description: "Set with invalid file path",
          homepage_url: "http://example.org/broken",
          versions: [
            [
              version: "v1.0",
              root_path: "nonexistent/path.ttl",
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

      conn =
        conn
        |> Map.put(:path_params, %{"set_id" => "broken_set", "version" => "v1.0"})
        |> SetResolver.call([])

      # Should redirect with error flash
      assert conn.halted
      assert redirected_to(conn) == "/sets"
      assert Flash.get(conn.assigns.flash, :error) =~ "Failed to load ontology set"
    end

    test "multiple requests reuse cached set (cache hit)", %{conn: conn} do
      # First request - cache miss
      conn1 =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:path_params, %{"set_id" => "test_set", "version" => "v1.0"})
        |> SetResolver.call([])

      assert %OntoView.OntologyHub.OntologySet{} = conn1.assigns.ontology_set

      # Second request - should hit cache
      conn2 =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:path_params, %{"set_id" => "test_set", "version" => "v1.0"})
        |> SetResolver.call([])

      assert %OntoView.OntologyHub.OntologySet{} = conn2.assigns.ontology_set

      # Verify cache hit by checking stats
      stats = OntologyHub.get_stats()
      assert stats.cache_hit_count >= 1
    end

    test "0.4.99.2 - SetResolver plug loads correct ontology into assigns", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:path_params, %{"set_id" => "test_set", "version" => "v1.0"})
        |> SetResolver.call([])

      # Verify all expected assigns are present
      assert conn.assigns.set_id == "test_set"
      assert conn.assigns.version == "v1.0"
      assert %OntoView.OntologyHub.OntologySet{} = conn.assigns.ontology_set
      assert conn.assigns.triple_store != nil
      assert conn.assigns.ontology_set.set_id == "test_set"
      assert conn.assigns.ontology_set.version == "v1.0"
    end

    test "0.4.99.4 - Session remembers last-viewed set and version", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:path_params, %{"set_id" => "test_set", "version" => "v1.0"})
        |> SetResolver.call([])

      # Verify session was updated
      assert get_session(conn, :last_set_id) == "test_set"
      assert get_session(conn, :last_version) == "v1.0"
    end
  end
end
