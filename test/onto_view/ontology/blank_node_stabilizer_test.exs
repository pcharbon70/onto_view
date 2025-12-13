defmodule OntoView.Ontology.BlankNodeStabilizerTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.TripleStore.BlankNodeStabilizer
  alias OntoView.Ontology.TripleStore.Triple

  doctest OntoView.Ontology.TripleStore.BlankNodeStabilizer

  # Test fixtures
  @ontology_a "http://example.org/ontology_a#"
  @ontology_b "http://example.org/ontology_b#"

  describe "stabilize/1 - Full pipeline (Task 1.2.2 complete)" do
    test "stabilizes blank nodes in single ontology" do
      triples = [
        %Triple{
          subject: {:iri, "http://example.org/Subject"},
          predicate: {:iri, "http://example.org/hasValue"},
          object: {:blank, "b1"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"},
          object: {:iri, "http://example.org/Value"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      assert length(stabilized) == 2

      # Check first triple - object should be stabilized
      [triple1, triple2] = stabilized
      assert {:blank, stable_id} = triple1.object
      assert String.starts_with?(stable_id, @ontology_a)
      assert String.contains?(stable_id, "_bn")

      # Check second triple - subject should have same stable ID
      assert {:blank, ^stable_id} = triple2.subject
    end

    test "preserves reference consistency across multiple uses" do
      # Same blank node "b1" appears in subject and object positions
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/hasProperty"},
          object: {:iri, "http://example.org/Value"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:iri, "http://example.org/Other"},
          predicate: {:iri, "http://example.org/references"},
          object: {:blank, "b1"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      [triple1, triple2] = stabilized
      {:blank, stable_id_1} = triple1.subject
      {:blank, stable_id_2} = triple2.object

      # Same original ID must map to same stable ID
      assert stable_id_1 == stable_id_2
    end

    test "handles multiple distinct blank nodes" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj1"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b2"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj2"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b3"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj3"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      stable_ids =
        Enum.map(stabilized, fn triple ->
          {:blank, id} = triple.subject
          id
        end)

      # All should be unique
      assert length(Enum.uniq(stable_ids)) == 3

      # All should have ontology prefix
      assert Enum.all?(stable_ids, &String.starts_with?(&1, @ontology_a))

      # All should have _bn pattern
      assert Enum.all?(stable_ids, &String.contains?(&1, "_bn"))
    end

    test "prevents collision across different ontologies" do
      # Both ontologies have blank node "b1" - must not collide
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_b
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      [triple_a, triple_b] = stabilized
      {:blank, stable_id_a} = triple_a.subject
      {:blank, stable_id_b} = triple_b.subject

      # IDs must be different
      assert stable_id_a != stable_id_b

      # Each must have correct ontology prefix
      assert String.starts_with?(stable_id_a, @ontology_a)
      assert String.starts_with?(stable_id_b, @ontology_b)
    end

    test "preserves non-blank terms unchanged" do
      triples = [
        %Triple{
          subject: {:iri, "http://example.org/Subject"},
          predicate: {:iri, "http://example.org/predicate"},
          object: {:literal, "value", nil, nil},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      assert stabilized == triples
    end

    test "handles mixed blank and non-blank terms" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:literal, "value", nil, nil},
          graph: @ontology_a
        }
      ]

      [stabilized] = BlankNodeStabilizer.stabilize(triples)

      assert {:blank, stable_id} = stabilized.subject
      assert String.starts_with?(stable_id, @ontology_a)
      assert stabilized.predicate == {:iri, "http://example.org/pred"}
      assert stabilized.object == {:literal, "value", nil, nil}
    end

    test "handles empty triple list" do
      assert BlankNodeStabilizer.stabilize([]) == []
    end
  end

  describe "Blank node detection (Task 1.2.2.1)" do
    test "detects blank node in subject position" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)
      [triple] = stabilized

      assert {:blank, stable_id} = triple.subject
      assert String.contains?(stable_id, "_bn")
    end

    test "detects blank node in object position" do
      triples = [
        %Triple{
          subject: {:iri, "http://example.org/subj"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:blank, "b1"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)
      [triple] = stabilized

      assert {:blank, stable_id} = triple.object
      assert String.contains?(stable_id, "_bn")
    end

    test "detects blank node in predicate position (rare but valid)" do
      triples = [
        %Triple{
          subject: {:iri, "http://example.org/subj"},
          predicate: {:blank, "b1"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)
      [triple] = stabilized

      assert {:blank, stable_id} = triple.predicate
      assert String.contains?(stable_id, "_bn")
    end

    test "detects multiple blank nodes in same triple" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:blank, "b2"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)
      [triple] = stabilized

      assert {:blank, subject_id} = triple.subject
      assert {:blank, object_id} = triple.object
      assert subject_id != object_id
      assert String.contains?(subject_id, "_bn")
      assert String.contains?(object_id, "_bn")
    end

    test "groups blank nodes by ontology" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b2"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_b
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      [triple_a, triple_b] = stabilized
      {:blank, id_a} = triple_a.subject
      {:blank, id_b} = triple_b.subject

      assert String.starts_with?(id_a, @ontology_a)
      assert String.starts_with?(id_b, @ontology_b)
    end

    test "ignores non-blank terms during detection" do
      triples = [
        %Triple{
          subject: {:iri, "http://example.org/Subject"},
          predicate: {:iri, "http://example.org/predicate"},
          object: {:literal, "value", nil, nil},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      assert stabilized == triples
    end
  end

  describe "Stable ID generation (Task 1.2.2.2)" do
    test "generates IDs with ontology prefix" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        }
      ]

      [stabilized] = BlankNodeStabilizer.stabilize(triples)
      {:blank, stable_id} = stabilized.subject

      assert String.starts_with?(stable_id, @ontology_a)
    end

    test "generates IDs with _bn marker" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        }
      ]

      [stabilized] = BlankNodeStabilizer.stabilize(triples)
      {:blank, stable_id} = stabilized.subject

      assert String.contains?(stable_id, "_bn")
    end

    test "generates IDs with zero-padded counter" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        }
      ]

      [stabilized] = BlankNodeStabilizer.stabilize(triples)
      {:blank, stable_id} = stabilized.subject

      # Should have 4-digit counter (e.g., _bn0001)
      assert Regex.match?(~r/_bn\d{4}$/, stable_id)
    end

    test "generates sequential counters for multiple blank nodes" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj1"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b2"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj2"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b3"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj3"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      stable_ids =
        Enum.map(stabilized, fn triple ->
          {:blank, id} = triple.subject
          id
        end)

      # Extract counter values
      counters =
        Enum.map(stable_ids, fn id ->
          [_, counter] = String.split(id, "_bn")
          String.to_integer(counter)
        end)

      # Should be sequential starting from 1
      assert Enum.sort(counters) == [1, 2, 3]
    end

    test "generates unique IDs for each distinct blank node" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:blank, "b2"},
          graph: @ontology_a
        }
      ]

      [stabilized] = BlankNodeStabilizer.stabilize(triples)
      {:blank, subject_id} = stabilized.subject
      {:blank, object_id} = stabilized.object

      assert subject_id != object_id
    end

    test "generates deterministic IDs for same input" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        }
      ]

      stabilized_1 = BlankNodeStabilizer.stabilize(triples)
      stabilized_2 = BlankNodeStabilizer.stabilize(triples)

      assert stabilized_1 == stabilized_2
    end

    test "handles large counter values" do
      # Create many blank nodes to test counter
      triples =
        Enum.map(1..100, fn i ->
          %Triple{
            subject: {:blank, "b#{i}"},
            predicate: {:iri, "http://example.org/pred"},
            object: {:iri, "http://example.org/obj"},
            graph: @ontology_a
          }
        end)

      stabilized = BlankNodeStabilizer.stabilize(triples)

      # Verify all have stable IDs with 4-digit counters
      stable_ids =
        Enum.map(stabilized, fn triple ->
          {:blank, id} = triple.subject
          id
        end)

      # All should match the pattern
      assert Enum.all?(stable_ids, &Regex.match?(~r/_bn\d{4}$/, &1))

      # Should have 100 unique IDs
      assert length(Enum.uniq(stable_ids)) == 100
    end
  end

  describe "Reference consistency (Task 1.2.2.3)" do
    test "same blank node ID gets same stable ID in subject and object" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred1"},
          object: {:iri, "http://example.org/obj1"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:iri, "http://example.org/subj2"},
          predicate: {:iri, "http://example.org/pred2"},
          object: {:blank, "b1"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      [triple1, triple2] = stabilized
      {:blank, subject_id} = triple1.subject
      {:blank, object_id} = triple2.object

      assert subject_id == object_id
    end

    test "same blank node across multiple triples maintains consistency" do
      # b1 appears 4 times across 3 triples
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:blank, "b1"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:iri, "http://example.org/subj"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:blank, "b1"},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      # Collect all stable IDs for b1
      stable_ids =
        Enum.flat_map(stabilized, fn triple ->
          [triple.subject, triple.predicate, triple.object]
          |> Enum.filter(&match?({:blank, _}, &1))
          |> Enum.map(fn {:blank, id} -> id end)
        end)

      # All should be the same
      assert length(Enum.uniq(stable_ids)) == 1
    end

    test "different blank nodes get different stable IDs" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:blank, "b2"},
          graph: @ontology_a
        }
      ]

      [stabilized] = BlankNodeStabilizer.stabilize(triples)
      {:blank, subject_id} = stabilized.subject
      {:blank, object_id} = stabilized.object

      assert subject_id != object_id
    end

    test "consistency across ontology boundaries is independent" do
      # Same original ID "b1" in different ontologies should get different stable IDs
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_b
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      [triple_a, triple_b] = stabilized
      {:blank, id_a} = triple_a.subject
      {:blank, id_b} = triple_b.subject

      assert id_a != id_b
    end

    test "preserves original graph assignment" do
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/pred"},
          object: {:iri, "http://example.org/obj"},
          graph: @ontology_a
        }
      ]

      [stabilized] = BlankNodeStabilizer.stabilize(triples)

      assert stabilized.graph == @ontology_a
    end

    test "handles complex reference pattern" do
      # b1 → b2 → b3 chain
      triples = [
        %Triple{
          subject: {:blank, "b1"},
          predicate: {:iri, "http://example.org/next"},
          object: {:blank, "b2"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b2"},
          predicate: {:iri, "http://example.org/next"},
          object: {:blank, "b3"},
          graph: @ontology_a
        },
        %Triple{
          subject: {:blank, "b3"},
          predicate: {:iri, "http://example.org/value"},
          object: {:literal, "end", nil, nil},
          graph: @ontology_a
        }
      ]

      stabilized = BlankNodeStabilizer.stabilize(triples)

      # Extract all blank node IDs
      all_blank_ids =
        Enum.flat_map(stabilized, fn triple ->
          [triple.subject, triple.object]
          |> Enum.filter(&match?({:blank, _}, &1))
          |> Enum.map(fn {:blank, id} -> id end)
        end)

      # Should have exactly 3 unique stable IDs
      assert length(Enum.uniq(all_blank_ids)) == 3

      # All should have ontology prefix
      assert Enum.all?(all_blank_ids, &String.starts_with?(&1, @ontology_a))
    end
  end

  describe "Integration with real fixtures" do
    test "stabilizes blank nodes from blank_nodes.ttl fixture" do
      # This test will use the actual blank_nodes.ttl fixture
      alias OntoView.Ontology.ImportResolver
      alias OntoView.Ontology.TripleStore

      fixture_path = "test/support/fixtures/ontologies/blank_nodes.ttl"

      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find triples with blank nodes
      blank_triples = Enum.filter(store.triples, fn triple ->
        match?({:blank, _}, triple.subject) or
        match?({:blank, _}, triple.object)
      end)

      # Should have found some blank node triples
      assert length(blank_triples) > 0

      # All blank node IDs should be stabilized
      Enum.each(blank_triples, fn triple ->
        if match?({:blank, _}, triple.subject) do
          {:blank, id} = triple.subject
          assert String.contains?(id, "_bn"), "Subject blank node should be stabilized: #{id}"
        end

        if match?({:blank, _}, triple.object) do
          {:blank, id} = triple.object
          assert String.contains?(id, "_bn"), "Object blank node should be stabilized: #{id}"
        end
      end)
    end

    test "blank node reference consistency in real fixture" do
      alias OntoView.Ontology.ImportResolver
      alias OntoView.Ontology.TripleStore

      fixture_path = "test/support/fixtures/ontologies/blank_nodes.ttl"

      {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find a blank node that appears multiple times
      blank_triples = Enum.filter(store.triples, fn triple ->
        match?({:blank, _}, triple.subject) or
        match?({:blank, _}, triple.object)
      end)

      # Group by blank node ID
      by_blank_id =
        Enum.reduce(blank_triples, %{}, fn triple, acc ->
          ids =
            [triple.subject, triple.object]
            |> Enum.filter(&match?({:blank, _}, &1))
            |> Enum.map(fn {:blank, id} -> id end)

          Enum.reduce(ids, acc, fn id, acc_inner ->
            Map.update(acc_inner, id, [triple], &[triple | &1])
          end)
        end)

      # If any blank node appears more than once, verify consistency
      by_blank_id
      |> Enum.filter(fn {_id, triples} -> length(triples) > 1 end)
      |> Enum.each(fn {id, _triples} ->
        # All references to this ID should be identical
        assert String.contains?(id, "_bn"),
               "Blank node #{id} appearing multiple times should be stabilized"
      end)
    end
  end
end
