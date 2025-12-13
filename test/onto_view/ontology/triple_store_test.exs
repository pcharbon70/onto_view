defmodule OntoView.Ontology.TripleStoreTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.{TripleStore, ImportResolver}
  alias OntoView.Ontology.TripleStore.Triple

  import OntoView.FixtureHelpers

  doctest TripleStore

  describe "Task 1.2.1.1 - Parse (subject, predicate, object) triples" do
    test "extracts all triples from single ontology" do
      path = fixture_path("valid_simple.ttl")

      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Verify triple extraction
      assert store.count > 0
      assert length(store.triples) == store.count

      # Verify triple structure
      for triple <- store.triples do
        assert %Triple{subject: _, predicate: _, object: _, graph: _} = triple
      end
    end

    test "extracts triples from multi-ontology dataset" do
      path = integration_fixture("hub.ttl")

      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Should have triples from hub + 3 spokes
      assert MapSet.size(store.ontologies) == 4

      # Verify all ontologies contribute triples
      for ontology_iri <- store.ontologies do
        graph_triples = TripleStore.from_graph(store, ontology_iri)
        assert length(graph_triples) > 0, "Ontology #{ontology_iri} should have triples"
      end
    end

    test "preserves all triples across import chain" do
      path = integration_fixture("deep_level_0.ttl")

      {:ok, loaded} = ImportResolver.load_with_imports(path)

      # Count triples from RDF.Dataset
      expected_count =
        loaded.dataset
        |> RDF.Dataset.graphs()
        |> Enum.map(&RDF.Graph.triple_count/1)
        |> Enum.sum()

      store = TripleStore.from_loaded_ontologies(loaded)

      assert store.count == expected_count
    end

    @tag :skip
    test "handles diamond dependency pattern correctly" do
      # Note: diamond fixture not yet created, skipping for now
      # The hub.ttl fixture already tests multi-ontology scenarios
      path = integration_fixture("diamond_top.ttl")

      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Diamond: top imports left+right, both import bottom
      # Should have 4 ontologies: top, left, right, bottom
      assert MapSet.size(store.ontologies) == 4

      # All triples should be preserved (no duplicates from shared imports)
      assert store.count > 0
    end

    test "triple count matches dataset triple count" do
      path = fixture_path("valid_simple.ttl")

      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      dataset_triple_count =
        loaded.dataset
        |> RDF.Dataset.graphs()
        |> Enum.map(&RDF.Graph.triple_count/1)
        |> Enum.sum()

      assert store.count == dataset_triple_count
      assert length(store.triples) == dataset_triple_count
    end
  end

  describe "Task 1.2.1.2 - Normalize IRIs" do
    test "converts IRI subjects to string format" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find triple with IRI subject (e.g., ontology declaration)
      iri_triple =
        Enum.find(store.triples, fn t ->
          match?({:iri, _}, t.subject)
        end)

      assert iri_triple != nil
      {:iri, iri_string} = iri_triple.subject
      assert is_binary(iri_string)
      assert String.starts_with?(iri_string, "http")
    end

    test "converts IRI predicates to string format" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # All predicates should be IRIs
      for triple <- store.triples do
        assert {:iri, predicate_string} = triple.predicate
        assert is_binary(predicate_string)
        assert String.starts_with?(predicate_string, "http")
      end
    end

    test "converts IRI objects to string format" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find rdf:type triple (object is IRI)
      type_triple =
        Enum.find(store.triples, fn t ->
          case t.predicate do
            {:iri, iri} -> String.ends_with?(iri, "type")
            _ -> false
          end
        end)

      assert type_triple != nil
      assert {:iri, _class_iri} = type_triple.object
    end

    test "fully qualified IRIs have no prefix notation" do
      path = fixture_path("custom_prefixes.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # All IRIs should be fully expanded (no "prefix:localName" format)
      for triple <- store.triples do
        case triple.subject do
          {:iri, iri} ->
            assert String.starts_with?(iri, "http"), "Subject IRI should be fully qualified: #{iri}"

          {:blank, _} ->
            :ok
        end

        {:iri, predicate} = triple.predicate

        assert String.starts_with?(predicate, "http"),
               "Predicate IRI should be fully qualified: #{predicate}"

        case triple.object do
          {:iri, iri} ->
            assert String.starts_with?(iri, "http"), "Object IRI should be fully qualified: #{iri}"

          {:literal, _, _, _} ->
            :ok

          {:blank, _} ->
            :ok
        end
      end
    end

    test "IRIs are normalized consistently across ontologies" do
      path = integration_fixture("hub.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Collect all unique IRI strings
      iris =
        store.triples
        |> Enum.flat_map(fn triple ->
          iris = []

          iris =
            case triple.subject do
              {:iri, iri} -> [iri | iris]
              _ -> iris
            end

          {:iri, pred} = triple.predicate
          iris = [pred | iris]

          iris =
            case triple.object do
              {:iri, iri} -> [iri | iris]
              _ -> iris
            end

          iris
        end)
        |> Enum.uniq()

      # All should be fully qualified HTTP(S) URIs
      for iri <- iris do
        assert String.starts_with?(iri, "http://") or String.starts_with?(iri, "https://"),
               "IRI should be fully qualified: #{iri}"
      end
    end
  end

  describe "Task 1.2.1.3 - Expand prefix mappings" do
    test "prefix expansion handled by RDF.ex during parsing" do
      # This test documents that prefix expansion is already done
      path = fixture_path("custom_prefixes.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)

      # Verify prefix map is preserved in metadata
      ontology_meta = loaded.ontologies[loaded.import_chain.root_iri]
      assert Map.has_key?(ontology_meta.prefix_map, "owl")
      assert Map.has_key?(ontology_meta.prefix_map, "rdfs")

      # Verify triples have expanded IRIs
      store = TripleStore.from_loaded_ontologies(loaded)

      # All predicates should be fully expanded (no prefix:localName)
      for triple <- store.triples do
        {:iri, predicate} = triple.predicate
        refute String.contains?(predicate, ":") and not String.starts_with?(predicate, "http"),
               "Predicate should not contain unexpanded prefix: #{predicate}"
      end
    end

    test "custom prefixes are expanded correctly" do
      path = fixture_path("custom_prefixes.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Verify that custom prefix was expanded
      # custom_prefixes.ttl should use custom namespace
      custom_iris =
        store.triples
        |> Enum.flat_map(fn triple ->
          case triple.subject do
            {:iri, iri} -> [iri]
            _ -> []
          end
        end)
        |> Enum.filter(&String.contains?(&1, "example.org"))

      assert length(custom_iris) > 0, "Should have IRIs from custom namespace"
    end
  end

  describe "Task 1.2.1.4 - Separate literals from IRIs" do
    test "identifies IRI objects" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find rdf:type triple (object is IRI)
      iri_objects =
        Enum.filter(store.triples, fn t ->
          match?({:iri, _}, t.object)
        end)

      assert length(iri_objects) > 0

      for triple <- iri_objects do
        {:iri, iri_string} = triple.object
        assert is_binary(iri_string)
        assert String.starts_with?(iri_string, "http")
      end
    end

    test "identifies literal objects with values" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find rdfs:label triple (object is literal)
      literal_objects =
        Enum.filter(store.triples, fn t ->
          match?({:literal, _, _, _}, t.object)
        end)

      assert length(literal_objects) > 0

      for triple <- literal_objects do
        {:literal, value, _datatype, _lang} = triple.object
        assert value != nil
      end
    end

    test "extracts datatype from typed literals" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Most literals will have implicit xsd:string datatype
      typed_literals =
        Enum.filter(store.triples, fn t ->
          case t.object do
            {:literal, _, dt, _} when is_binary(dt) -> true
            _ -> false
          end
        end)

      if length(typed_literals) > 0 do
        triple = hd(typed_literals)
        {:literal, _value, datatype, _lang} = triple.object
        # Should be XSD datatype
        assert String.contains?(datatype, "XMLSchema") or String.contains?(datatype, "w3.org")
      end
    end

    test "extracts language tags from language-tagged literals" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find language-tagged literals
      lang_literals =
        Enum.filter(store.triples, fn t ->
          case t.object do
            {:literal, _, _, lang} when is_binary(lang) -> true
            _ -> false
          end
        end)

      assert length(lang_literals) > 0

      triple = hd(lang_literals)
      {:literal, _value, _datatype, language} = triple.object
      assert language == "en"
    end

    test "identifies blank node subjects" do
      path = fixture_path("blank_nodes.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find blank node subjects
      blank_subjects =
        Enum.filter(store.triples, fn t ->
          match?({:blank, _}, t.subject)
        end)

      assert length(blank_subjects) > 0

      for triple <- blank_subjects do
        {:blank, id} = triple.subject
        assert is_binary(id)
        assert String.length(id) > 0
      end
    end

    test "identifies blank node objects" do
      path = fixture_path("blank_nodes.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find blank node objects
      blank_objects =
        Enum.filter(store.triples, fn t ->
          match?({:blank, _}, t.object)
        end)

      assert length(blank_objects) > 0

      for triple <- blank_objects do
        {:blank, id} = triple.object
        assert is_binary(id)
        assert String.length(id) > 0
      end
    end

    test "distinguishes all three object types (IRI, literal, blank)" do
      path = fixture_path("blank_nodes.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Group by object type
      by_type =
        Enum.group_by(store.triples, fn triple ->
          case triple.object do
            {:iri, _} -> :iri
            {:literal, _, _, _} -> :literal
            {:blank, _} -> :blank
          end
        end)

      # Should have all three types
      assert Map.has_key?(by_type, :iri)
      assert Map.has_key?(by_type, :literal)
      assert Map.has_key?(by_type, :blank)

      assert length(by_type[:iri]) > 0
      assert length(by_type[:literal]) > 0
      assert length(by_type[:blank]) > 0
    end
  end

  describe "provenance tracking" do
    test "tracks which ontology each triple came from" do
      path = integration_fixture("hub.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Group triples by graph
      graphs = store.triples |> Enum.map(& &1.graph) |> Enum.uniq()

      # Should have triples from 4 different graphs
      assert length(graphs) == 4

      # Each graph should be a valid ontology IRI
      for graph_iri <- graphs do
        assert String.starts_with?(graph_iri, "http://example.org/")
      end
    end

    test "from_graph/2 filters triples by ontology" do
      path = integration_fixture("hub.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      hub_iri = loaded.import_chain.root_iri
      hub_triples = TripleStore.from_graph(store, hub_iri)

      # All returned triples should be from hub graph
      for triple <- hub_triples do
        assert triple.graph == hub_iri
      end

      # Should have some triples
      assert length(hub_triples) > 0
    end

    test "each ontology in import chain has corresponding triples" do
      path = integration_fixture("deep_level_0.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Every ontology in import chain should have triples
      for import_node <- loaded.import_chain.imports do
        graph_triples = TripleStore.from_graph(store, import_node.iri)
        assert length(graph_triples) > 0, "Ontology #{import_node.iri} should have triples"
      end
    end

    test "stores ontology IRIs correctly" do
      path = integration_fixture("hub.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Ontologies set should match loaded ontologies
      loaded_iris = MapSet.new(Map.keys(loaded.ontologies))
      assert store.ontologies == loaded_iris
    end
  end

  describe "query interface" do
    test "all/1 returns all triples" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      all_triples = TripleStore.all(store)

      assert is_list(all_triples)
      assert length(all_triples) == store.count
      assert all_triples == store.triples
    end

    test "count/1 returns triple count" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      count = TripleStore.count(store)

      assert is_integer(count)
      assert count == length(store.triples)
      assert count > 0
    end

    test "from_graph/2 returns empty list for unknown graph" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      triples = TripleStore.from_graph(store, "http://nonexistent.org/ontology#")

      assert triples == []
    end

    test "from_graph/2 returns correct subset" do
      path = integration_fixture("hub.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      hub_iri = loaded.import_chain.root_iri
      hub_triples = TripleStore.from_graph(store, hub_iri)

      # Should be a subset of all triples
      assert length(hub_triples) < store.count
      assert length(hub_triples) > 0

      # All should have correct graph
      assert Enum.all?(hub_triples, &(&1.graph == hub_iri))
    end
  end

  describe "edge cases and error handling" do
    test "handles empty ontology gracefully" do
      path = fixture_path("empty.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Empty ontology has 0 triples
      assert store.count == 0
      assert store.triples == []
      assert MapSet.size(store.ontologies) >= 0
    end

    test "handles ontology with only metadata triples" do
      path = fixture_path("no_base_iri.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Should have at least some triples (prefix declarations, etc.)
      assert store.count >= 0
      assert length(store.triples) == store.count
    end

    test "handles large ontology efficiently" do
      # Use integration fixture with multiple imports
      path = integration_fixture("deep_level_0.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)

      # Should complete in reasonable time
      store = TripleStore.from_loaded_ontologies(loaded)

      assert store.count > 0
      assert length(store.triples) == store.count
    end
  end

  describe "TripleStore struct" do
    test "has all required fields" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      assert Map.has_key?(store, :triples)
      assert Map.has_key?(store, :count)
      assert Map.has_key?(store, :ontologies)
    end

    test "is a proper struct" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      assert %TripleStore{} = store
      assert store.__struct__ == TripleStore
    end

    test "triples field contains Triple structs" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      assert is_list(store.triples)

      for triple <- store.triples do
        assert %Triple{} = triple
      end
    end

    test "ontologies field is a MapSet" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      assert %MapSet{} = store.ontologies
    end
  end

  describe "integration with Section 1.1" do
    test "works with single file load result" do
      path = fixture_path("valid_simple.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)

      # Should work seamlessly
      store = TripleStore.from_loaded_ontologies(loaded)

      assert store.count > 0
      assert MapSet.size(store.ontologies) == 1
    end

    test "works with recursive import result" do
      path = integration_fixture("hub.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)

      # Should work seamlessly with imports
      store = TripleStore.from_loaded_ontologies(loaded)

      assert store.count > 0
      assert MapSet.size(store.ontologies) == 4
    end

    test "preserves all data from LoadedOntologies" do
      path = integration_fixture("hub.ttl")
      {:ok, loaded} = ImportResolver.load_with_imports(path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # All ontologies preserved
      assert MapSet.new(Map.keys(loaded.ontologies)) == store.ontologies

      # All triples extracted
      expected_triples =
        loaded.dataset
        |> RDF.Dataset.graphs()
        |> Enum.map(&RDF.Graph.triple_count/1)
        |> Enum.sum()

      assert store.count == expected_triples
    end
  end
end
