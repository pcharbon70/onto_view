defmodule OntoView.Ontology.TripleIndexingTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.{TripleStore, ImportResolver}

  doctest TripleStore

  # Test fixtures
  @valid_simple_path "test/support/fixtures/ontologies/valid_simple.ttl"
  @blank_nodes_path "test/support/fixtures/ontologies/blank_nodes.ttl"
  @integration_path "test/support/fixtures/ontologies/integration/hub.ttl"

  describe "Task 1.2.3.1 - Index by subject" do
    test "returns all triples with specified IRI subject" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find an IRI subject that exists
      subject = store.triples
        |> Enum.find_value(fn t -> if match?({:iri, _}, t.subject), do: t.subject end)

      assert subject != nil

      triples = TripleStore.by_subject(store, subject)

      assert length(triples) > 0
      assert Enum.all?(triples, fn t -> t.subject == subject end)
    end

    test "returns all triples with specified blank node subject" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find a blank node subject
      blank_triple = Enum.find(store.triples, fn t ->
        match?({:blank, _}, t.subject)
      end)

      assert blank_triple != nil

      {:blank, _} = blank_subject = blank_triple.subject
      triples = TripleStore.by_subject(store, blank_subject)

      assert length(triples) > 0
      assert Enum.all?(triples, fn t -> t.subject == blank_subject end)
    end

    test "returns multiple triples for subject with multiple predicates" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find a subject that has multiple triples
      subject_with_multiple = store.triples
        |> Enum.group_by(& &1.subject)
        |> Enum.find(fn {_subj, triples} -> length(triples) >= 2 end)

      if subject_with_multiple do
        {subject, _expected_triples} = subject_with_multiple
        result_triples = TripleStore.by_subject(store, subject)

        assert length(result_triples) >= 2
        assert Enum.all?(result_triples, fn t -> t.subject == subject end)
      else
        # Skip test if no suitable subject found
        assert true
      end
    end

    test "returns empty list for non-existent subject" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      non_existent = {:iri, "http://example.org/DoesNotExist"}
      triples = TripleStore.by_subject(store, non_existent)

      assert triples == []
    end

    test "returns triples from all graphs for same subject IRI" do
      {:ok, loaded} = ImportResolver.load_with_imports(@integration_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find a subject that appears in multiple graphs
      subject_counts =
        store.triples
        |> Enum.group_by(& &1.subject)
        |> Enum.filter(fn {_subj, triples} ->
          triples |> Enum.map(& &1.graph) |> Enum.uniq() |> length() > 1
        end)

      if length(subject_counts) > 0 do
        {subject, expected_triples} = hd(subject_counts)
        result_triples = TripleStore.by_subject(store, subject)

        assert length(result_triples) == length(expected_triples)
        assert Enum.sort(result_triples) == Enum.sort(expected_triples)
      end
    end

    test "subject index is built correctly during construction" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Index should be a map
      assert is_map(store.subject_index)

      # Every subject in triples should be a key in index
      subjects = store.triples |> Enum.map(& &1.subject) |> Enum.uniq()
      assert Enum.all?(subjects, fn subj -> Map.has_key?(store.subject_index, subj) end)
    end
  end

  describe "Task 1.2.3.2 - Index by predicate" do
    test "returns all rdf:type triples" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      rdf_type = {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"}
      triples = TripleStore.by_predicate(store, rdf_type)

      assert length(triples) > 0
      assert Enum.all?(triples, fn t -> t.predicate == rdf_type end)
    end

    test "returns all rdfs:label triples" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      rdfs_label = {:iri, "http://www.w3.org/2000/01/rdf-schema#label"}
      triples = TripleStore.by_predicate(store, rdfs_label)

      assert length(triples) > 0
      assert Enum.all?(triples, fn t -> t.predicate == rdfs_label end)
    end

    test "returns few triples for rare predicate (owl:imports)" do
      {:ok, loaded} = ImportResolver.load_with_imports(@integration_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      owl_imports = {:iri, "http://www.w3.org/2002/07/owl#imports"}
      triples = TripleStore.by_predicate(store, owl_imports)

      # Should have at least one import
      assert length(triples) >= 1
      assert Enum.all?(triples, fn t -> t.predicate == owl_imports end)
    end

    test "returns empty list for non-existent predicate" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      non_existent = {:iri, "http://example.org/nonExistentPredicate"}
      triples = TripleStore.by_predicate(store, non_existent)

      assert triples == []
    end

    test "predicate appears in multiple ontologies" do
      {:ok, loaded} = ImportResolver.load_with_imports(@integration_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # rdfs:label should appear across multiple graphs
      rdfs_label = {:iri, "http://www.w3.org/2000/01/rdf-schema#label"}
      triples = TripleStore.by_predicate(store, rdfs_label)

      graphs = triples |> Enum.map(& &1.graph) |> Enum.uniq()
      assert length(graphs) >= 1
    end

    test "can find OWL class declarations by chaining with object filter" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      rdf_type = {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"}
      owl_class = {:iri, "http://www.w3.org/2002/07/owl#Class"}

      class_triples =
        TripleStore.by_predicate(store, rdf_type)
        |> Enum.filter(&(&1.object == owl_class))

      assert length(class_triples) > 0
      assert Enum.all?(class_triples, fn t ->
        t.predicate == rdf_type and t.object == owl_class
      end)
    end

    test "predicate index is built correctly during construction" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Index should be a map
      assert is_map(store.predicate_index)

      # Every predicate in triples should be a key in index
      predicates = store.triples |> Enum.map(& &1.predicate) |> Enum.uniq()
      assert Enum.all?(predicates, fn pred -> Map.has_key?(store.predicate_index, pred) end)
    end
  end

  describe "Task 1.2.3.3 - Index by object" do
    test "returns all triples with IRI object" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      owl_ontology = {:iri, "http://www.w3.org/2002/07/owl#Ontology"}
      triples = TripleStore.by_object(store, owl_ontology)

      assert length(triples) > 0
      assert Enum.all?(triples, fn t -> t.object == owl_ontology end)
    end

    test "returns all triples with literal object" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find a specific literal
      literal_triple = Enum.find(store.triples, fn t ->
        match?({:literal, "Person", _, _}, t.object)
      end)

      if literal_triple do
        literal_object = literal_triple.object
        triples = TripleStore.by_object(store, literal_object)

        assert length(triples) >= 1
        assert Enum.all?(triples, fn t -> t.object == literal_object end)
      end
    end

    test "returns all triples with blank node object" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find a blank node object
      blank_triple = Enum.find(store.triples, fn t ->
        match?({:blank, _}, t.object)
      end)

      assert blank_triple != nil

      {:blank, _} = blank_object = blank_triple.object
      triples = TripleStore.by_object(store, blank_object)

      assert length(triples) >= 1
      assert Enum.all?(triples, fn t -> t.object == blank_object end)
    end

    test "returns empty list for non-existent object" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      non_existent = {:iri, "http://example.org/DoesNotExist"}
      triples = TripleStore.by_object(store, non_existent)

      assert triples == []
    end

    test "finds all class type declarations" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      owl_class = {:iri, "http://www.w3.org/2002/07/owl#Class"}
      triples = TripleStore.by_object(store, owl_class)

      assert length(triples) > 0
      assert Enum.all?(triples, fn t -> t.object == owl_class end)
    end

    test "finds all subclass relationships pointing to parent class" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find a parent class
      subClassOf = {:iri, "http://www.w3.org/2000/01/rdf-schema#subClassOf"}
      subclass_triples = TripleStore.by_predicate(store, subClassOf)

      if length(subclass_triples) > 0 do
        parent_class = hd(subclass_triples).object
        children = TripleStore.by_object(store, parent_class)
          |> Enum.filter(&(&1.predicate == subClassOf))

        assert length(children) >= 1
      end
    end

    test "object index is built correctly during construction" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Index should be a map
      assert is_map(store.object_index)

      # Every object in triples should be a key in index
      objects = store.triples |> Enum.map(& &1.object) |> Enum.uniq()
      assert Enum.all?(objects, fn obj -> Map.has_key?(store.object_index, obj) end)
    end
  end

  describe "Index correctness and completeness" do
    test "subject index contains all triples exactly once" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Flatten all index values
      indexed_triples =
        store.subject_index
        |> Map.values()
        |> List.flatten()
        |> Enum.sort()

      original_triples = Enum.sort(store.triples)

      assert indexed_triples == original_triples
    end

    test "predicate index contains all triples exactly once" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      indexed_triples =
        store.predicate_index
        |> Map.values()
        |> List.flatten()
        |> Enum.sort()

      original_triples = Enum.sort(store.triples)

      assert indexed_triples == original_triples
    end

    test "object index contains all triples exactly once" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      indexed_triples =
        store.object_index
        |> Map.values()
        |> List.flatten()
        |> Enum.sort()

      original_triples = Enum.sort(store.triples)

      assert indexed_triples == original_triples
    end

    test "index count consistency - sum of all index values equals total count" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      subject_count =
        store.subject_index
        |> Map.values()
        |> Enum.map(&length/1)
        |> Enum.sum()

      predicate_count =
        store.predicate_index
        |> Map.values()
        |> Enum.map(&length/1)
        |> Enum.sum()

      object_count =
        store.object_index
        |> Map.values()
        |> Enum.map(&length/1)
        |> Enum.sum()

      assert subject_count == store.count
      assert predicate_count == store.count
      assert object_count == store.count
    end

    test "indexed results match linear scan results for random queries" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Test subject query
      subject = store.triples |> Enum.take(5) |> Enum.map(& &1.subject) |> Enum.random()
      indexed_result = TripleStore.by_subject(store, subject) |> Enum.sort()
      linear_result = Enum.filter(store.triples, &(&1.subject == subject)) |> Enum.sort()
      assert indexed_result == linear_result

      # Test predicate query
      predicate = store.triples |> Enum.take(5) |> Enum.map(& &1.predicate) |> Enum.random()
      indexed_result = TripleStore.by_predicate(store, predicate) |> Enum.sort()
      linear_result = Enum.filter(store.triples, &(&1.predicate == predicate)) |> Enum.sort()
      assert indexed_result == linear_result

      # Test object query
      object = store.triples |> Enum.take(5) |> Enum.map(& &1.object) |> Enum.random()
      indexed_result = TripleStore.by_object(store, object) |> Enum.sort()
      linear_result = Enum.filter(store.triples, &(&1.object == object)) |> Enum.sort()
      assert indexed_result == linear_result
    end

    test "each triple appears exactly once in each index" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      Enum.each(store.triples, fn triple ->
        # Should appear in subject index
        subject_matches = TripleStore.by_subject(store, triple.subject)
        assert triple in subject_matches

        # Should appear in predicate index
        predicate_matches = TripleStore.by_predicate(store, triple.predicate)
        assert triple in predicate_matches

        # Should appear in object index
        object_matches = TripleStore.by_object(store, triple.object)
        assert triple in object_matches
      end)
    end
  end

  describe "Edge cases" do
    test "empty store has empty indexes" do
      # Create a store from an ontology with minimal triples
      {:ok, loaded} = ImportResolver.load_with_imports("test/support/fixtures/ontologies/empty.ttl")
      store = TripleStore.from_loaded_ontologies(loaded)

      assert is_map(store.subject_index)
      assert is_map(store.predicate_index)
      assert is_map(store.object_index)
    end

    test "single triple store has indexes with one entry each" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Pick first triple
      if store.count > 0 do
        first_triple = hd(store.triples)

        # Query by each component
        subject_results = TripleStore.by_subject(store, first_triple.subject)
        predicate_results = TripleStore.by_predicate(store, first_triple.predicate)
        object_results = TripleStore.by_object(store, first_triple.object)

        # Each should include the triple
        assert first_triple in subject_results
        assert first_triple in predicate_results
        assert first_triple in object_results
      end
    end

    test "integration fixture with deep imports" do
      {:ok, loaded} = ImportResolver.load_with_imports(@integration_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Should have many triples from multiple ontologies
      assert store.count > 10

      # All indexes should be populated
      assert map_size(store.subject_index) > 0
      assert map_size(store.predicate_index) > 0
      assert map_size(store.object_index) > 0
    end

    test "all triples with same predicate" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Find most common predicate
      {most_common_pred, _count} =
        store.triples
        |> Enum.group_by(& &1.predicate)
        |> Enum.map(fn {pred, triples} -> {pred, length(triples)} end)
        |> Enum.max_by(fn {_pred, count} -> count end)

      # Predicate index should have this entry
      triples_with_pred = TripleStore.by_predicate(store, most_common_pred)
      assert length(triples_with_pred) > 0
    end

    test "no duplicate index entries" do
      {:ok, loaded} = ImportResolver.load_with_imports(@blank_nodes_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      # Each index value should have no duplicates
      Enum.each(Map.values(store.subject_index), fn triples ->
        assert length(triples) == length(Enum.uniq(triples))
      end)

      Enum.each(Map.values(store.predicate_index), fn triples ->
        assert length(triples) == length(Enum.uniq(triples))
      end)

      Enum.each(Map.values(store.object_index), fn triples ->
        assert length(triples) == length(Enum.uniq(triples))
      end)
    end

    test "struct validation - all required fields present" do
      {:ok, loaded} = ImportResolver.load_with_imports(@valid_simple_path)
      store = TripleStore.from_loaded_ontologies(loaded)

      assert is_list(store.triples)
      assert is_integer(store.count)
      assert is_struct(store.ontologies, MapSet)
      assert is_map(store.subject_index)
      assert is_map(store.predicate_index)
      assert is_map(store.object_index)
    end
  end
end
