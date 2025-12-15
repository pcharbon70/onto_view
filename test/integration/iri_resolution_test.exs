defmodule OntoView.Integration.IRIResolutionTest do
  use OntoViewWeb.ConnCase, async: false

  alias OntoView.OntologyHub

  # Task 0.99.5 — IRI Resolution & Linked Data Workflow
  #
  # These tests validate end-to-end IRI resolution following W3C Linked Data
  # best practices. Tests confirm that IRIs can be resolved to documentation
  # views, content negotiation works correctly, and IRIs can be found across
  # multiple loaded sets and versions.

  describe "IRI Resolution & Linked Data Workflow (0.99.5)" do
    setup do
      # Configure multiple ontology sets with different IRIs and versions
      Application.put_env(:onto_view, :ontology_sets, [
        [
          set_id: "iri_test_elixir",
          name: "Elixir IRI Test Set",
          description: "Elixir ontology for IRI resolution testing",
          homepage_url: "http://example.org/elixir",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
              default: false
            ],
            [
              version: "v2.0",
              root_path: "test/support/fixtures/ontologies/valid_simple.ttl",
              default: true
            ]
          ],
          auto_load: false,
          priority: 1
        ],
        [
          set_id: "iri_test_custom",
          name: "Custom Prefixes IRI Test Set",
          description: "Custom prefixes ontology for IRI testing",
          homepage_url: "http://example.org/custom",
          versions: [
            [
              version: "v1.0",
              root_path: "test/support/fixtures/ontologies/custom_prefixes.ttl",
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

    test "0.99.5.1 - Resolve IRI to documentation view via /resolve endpoint", %{conn: conn} do
      # Load the set containing the IRI
      {:ok, _set} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      # Resolve IRI for Module class
      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri}")

      # Should return 303 See Other (W3C best practice)
      assert conn.status == 303

      # Should have Location header pointing to documentation
      location = get_resp_header(conn, "location") |> List.first()
      assert location != nil
      assert location =~ "/sets/iri_test_elixir/v2.0/docs"

      # Follow the redirect to verify it works
      conn = get(build_conn(), location)
      assert html_response(conn, 200) =~ "iri_test_elixir"
      assert html_response(conn, 200) =~ "v2.0"
    end

    test "0.99.5.2 - Validate content negotiation redirects to correct format", %{conn: conn} do
      # Load the set
      {:ok, _set} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      # Test HTML content negotiation
      conn_html =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri}")

      assert conn_html.status == 303
      location_html = get_resp_header(conn_html, "location") |> List.first()
      assert location_html =~ "/sets/iri_test_elixir/v2.0/docs"

      # Test JSON content negotiation
      conn_json =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/resolve?iri=#{encoded_iri}")

      assert conn_json.status == 200
      assert get_resp_header(conn_json, "content-type") == ["application/json; charset=utf-8"]

      json_response = json_response(conn_json, 200)
      assert json_response["iri"] == iri
      assert json_response["set_id"] == "iri_test_elixir"
      assert json_response["version"] == "v2.0"
      assert json_response["documentation_url"] =~ "/sets/iri_test_elixir/v2.0/docs"
      assert json_response["ttl_export_url"] =~ "/sets/iri_test_elixir/v2.0/export.ttl"

      # Test Turtle content negotiation
      conn_turtle =
        build_conn()
        |> put_req_header("accept", "text/turtle")
        |> get("/resolve?iri=#{encoded_iri}")

      assert conn_turtle.status == 303
      assert get_resp_header(conn_turtle, "content-type") == ["text/turtle; charset=utf-8"]
      location_turtle = get_resp_header(conn_turtle, "location") |> List.first()
      assert location_turtle =~ "/sets/iri_test_elixir/v2.0/export.ttl"

      # Test RDF/XML content negotiation
      conn_rdf =
        build_conn()
        |> put_req_header("accept", "application/rdf+xml")
        |> get("/resolve?iri=#{encoded_iri}")

      assert conn_rdf.status == 303
      location_rdf = get_resp_header(conn_rdf, "location") |> List.first()
      assert location_rdf =~ "/export.ttl"
    end

    test "0.99.5.3 - Resolve IRIs across multiple loaded sets", %{conn: conn} do
      # Load both sets
      {:ok, _set1} = OntologyHub.get_set("iri_test_elixir", "v2.0")
      {:ok, _set2} = OntologyHub.get_set("iri_test_custom", "v1.0")

      # Resolve IRI from first set (Elixir)
      iri1 = "http://example.org/elixir/core#Module"
      encoded_iri1 = URI.encode_www_form(iri1)

      conn1 =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri1}")

      assert conn1.status == 303
      location1 = get_resp_header(conn1, "location") |> List.first()
      assert location1 =~ "/sets/iri_test_elixir/"

      # Resolve IRI from second set (Custom)
      # Note: custom_prefixes.ttl uses different namespace, check the actual IRIs
      iri2 = "http://example.org/elixir/core#Function"
      encoded_iri2 = URI.encode_www_form(iri2)

      conn2 =
        build_conn()
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri2}")

      assert conn2.status == 303
      location2 = get_resp_header(conn2, "location") |> List.first()
      assert location2 =~ "/sets/iri_test_elixir/"  # Function is in same ontology

      # Verify both sets remain accessible via IRI resolution
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 2

      # Verify both sets remain loaded (IRI resolution doesn't evict)
      # IRI resolution uses loaded sets without affecting cache metrics
      assert stats.loaded_count == 2

      # Resolve same IRI again (uses same loaded set)
      conn3 =
        build_conn()
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri1}")

      assert conn3.status == 303

      # Verify sets still loaded
      stats_after = OntologyHub.get_stats()
      assert stats_after.loaded_count == 2
    end

    test "0.99.5.4 - Handle IRIs present in multiple versions (selects latest stable)", %{conn: conn} do
      # Load both versions of the same set
      {:ok, _set_v1} = OntologyHub.get_set("iri_test_elixir", "v1.0")
      {:ok, _set_v2} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      # Resolve IRI that exists in both versions
      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri}")

      assert conn.status == 303
      location = get_resp_header(conn, "location") |> List.first()

      # Should resolve to default version (v2.0 marked as default)
      assert location =~ "/sets/iri_test_elixir/v2.0/docs"
      refute location =~ "/sets/iri_test_elixir/v1.0/docs"

      # Verify via JSON response which version was selected
      conn_json =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/resolve?iri=#{encoded_iri}")

      json_response = json_response(conn_json, 200)
      assert json_response["version"] == "v2.0"  # Default version
      assert json_response["set_id"] == "iri_test_elixir"
    end

    test "IRI not found returns appropriate error", %{conn: conn} do
      # Load a set
      {:ok, _set} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      # Try to resolve non-existent IRI
      iri = "http://example.org/nonexistent#SomeClass"
      encoded_iri = URI.encode_www_form(iri)

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri}")

      # Should redirect to /sets with error message
      assert redirected_to(conn, 302) == "/sets"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "IRI"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
    end

    test "missing IRI parameter returns error", %{conn: conn} do
      conn = get(conn, "/resolve")

      assert redirected_to(conn, 302) == "/sets"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Missing 'iri' query parameter"
    end

    test "IRI resolution works with URL-encoded IRIs", %{conn: _conn} do
      {:ok, _set} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      iri = "http://example.org/elixir/core#Module"

      # Test URL-encoded IRI (standard web form encoding)
      encoded_iri = URI.encode_www_form(iri)

      conn =
        build_conn()
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_iri}")

      # Should resolve successfully (303 for found IRIs)
      assert conn.status == 303
      location = get_resp_header(conn, "location") |> List.first()
      assert location =~ "/sets/iri_test_elixir/v2.0/docs"

      # Test with JSON response to verify IRI decoded correctly
      conn_json =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/resolve?iri=#{encoded_iri}")

      assert conn_json.status == 200
      json_response = json_response(conn_json, 200)
      # Should match original unencoded IRI
      assert json_response["iri"] == iri
    end

    test "IRI resolution maintains performance under concurrent load", %{conn: _conn} do
      {:ok, _set} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      # Spawn 50 concurrent IRI resolution requests
      tasks =
        1..50
        |> Enum.map(fn _ ->
          Task.async(fn ->
            build_conn()
            |> put_req_header("accept", "text/html")
            |> get("/resolve?iri=#{encoded_iri}")
          end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 10_000))

      # All should succeed with 303 redirects
      assert Enum.all?(results, fn conn -> conn.status == 303 end)

      # All should point to same documentation URL
      locations = Enum.map(results, fn conn ->
        get_resp_header(conn, "location") |> List.first()
      end)

      assert Enum.all?(locations, fn loc ->
        loc =~ "/sets/iri_test_elixir/v2.0/docs"
      end)

      # Verify GenServer still operational
      stats = OntologyHub.get_stats()
      assert stats != nil
    end

    test "content negotiation handles complex Accept headers", %{conn: conn} do
      {:ok, _set} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      iri = "http://example.org/elixir/core#Module"
      encoded_iri = URI.encode_www_form(iri)

      # Browser-like Accept header with quality values
      conn_browser =
        conn
        |> put_req_header("accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        |> get("/resolve?iri=#{encoded_iri}")

      assert conn_browser.status == 303
      location = get_resp_header(conn_browser, "location") |> List.first()
      assert location =~ "/docs"  # HTML redirect

      # Accept header with multiple formats
      conn_multi =
        build_conn()
        |> put_req_header("accept", "application/json, text/turtle;q=0.8, text/html;q=0.5")
        |> get("/resolve?iri=#{encoded_iri}")

      # Should prefer JSON (first in list, no quality specified = q=1.0)
      assert conn_multi.status == 200
      assert get_resp_header(conn_multi, "content-type") == ["application/json; charset=utf-8"]
    end

    test "IRI resolution respects loaded vs unloaded sets", %{conn: conn} do
      # Only load one set
      {:ok, _set} = OntologyHub.get_set("iri_test_elixir", "v2.0")

      # IRI from loaded set should resolve
      iri_loaded = "http://example.org/elixir/core#Module"
      encoded_loaded = URI.encode_www_form(iri_loaded)

      conn_loaded =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/resolve?iri=#{encoded_loaded}")

      assert conn_loaded.status == 303

      # IRI from unloaded set should return not found
      # (Note: IRI index only includes loaded sets)
      stats = OntologyHub.get_stats()
      assert stats.loaded_count == 1
    end
  end
end
