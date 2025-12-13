defmodule OntoView.Ontology.TripleStore.TripleTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.TripleStore.Triple

  doctest Triple

  describe "from_rdf_triple/2 - IRI conversion" do
    test "converts IRI subject" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/predicate")
      object = RDF.iri("http://example.org/Object")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph_iri")

      assert {:iri, "http://example.org/Subject"} = triple.subject
      assert {:iri, "http://example.org/predicate"} = triple.predicate
      assert {:iri, "http://example.org/Object"} = triple.object
      assert triple.graph == "graph_iri"
    end

    test "converts IRI predicate" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
      object = RDF.iri("http://www.w3.org/2002/07/owl#Class")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"} = triple.predicate
    end

    test "converts IRI object" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
      object = RDF.iri("http://www.w3.org/2002/07/owl#Class")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:iri, "http://www.w3.org/2002/07/owl#Class"} = triple.object
    end

    test "normalizes all IRIs to fully expanded strings" do
      subject = RDF.iri("http://example.org/ns#Resource")
      predicate = RDF.iri("http://www.w3.org/2000/01/rdf-schema#subClassOf")
      object = RDF.iri("http://www.w3.org/2002/07/owl#Thing")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      # All should be fully qualified HTTP IRIs
      {:iri, subj_str} = triple.subject
      {:iri, pred_str} = triple.predicate
      {:iri, obj_str} = triple.object

      assert String.starts_with?(subj_str, "http://")
      assert String.starts_with?(pred_str, "http://")
      assert String.starts_with?(obj_str, "http://")
    end
  end

  describe "from_rdf_triple/2 - blank node conversion" do
    test "converts blank node subject" do
      subject = RDF.bnode("b1")
      predicate = RDF.iri("http://example.org/predicate")
      object = RDF.iri("http://example.org/Object")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:blank, "b1"} = triple.subject
    end

    test "converts blank node object" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/hasAddress")
      object = RDF.bnode("b2")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:blank, "b2"} = triple.object
    end

    test "preserves blank node identifiers" do
      subject = RDF.bnode("custom_id_123")
      predicate = RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
      object = RDF.iri("http://example.org/Address")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:blank, "custom_id_123"} = triple.subject
    end
  end

  describe "from_rdf_triple/2 - literal conversion" do
    test "converts string literal object" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
      object = RDF.literal("Test Label")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:literal, value, datatype, language} = triple.object
      assert value == "Test Label"
      # String literals have implicit xsd:string datatype
      assert datatype =~ "string" or datatype =~ "XMLSchema"
      assert language == nil
    end

    test "converts language-tagged literal" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://www.w3.org/2000/01/rdf-schema#label")
      object = RDF.literal("Test Label", language: "en")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:literal, value, _datatype, language} = triple.object
      assert value == "Test Label"
      assert language == "en"
    end

    test "converts integer literal" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/hasAge")
      object = RDF.literal(42)

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:literal, value, datatype, nil} = triple.object
      assert value == 42
      assert datatype =~ "integer" or datatype =~ "XMLSchema"
    end

    test "converts boolean literal" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/isActive")
      object = RDF.literal(true)

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:literal, true, datatype, nil} = triple.object
      assert datatype =~ "boolean" or datatype =~ "XMLSchema"
    end

    test "converts float literal" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/hasWeight")
      object = RDF.literal(3.14)

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert {:literal, value, datatype, nil} = triple.object
      assert value == 3.14
      assert datatype =~ "double" or datatype =~ "XMLSchema"
    end

    test "preserves literal datatype information" do
      subject = RDF.iri("http://example.org/Event")
      predicate = RDF.iri("http://example.org/occurredAt")
      # Explicitly typed literal - RDF.ex converts to Elixir Date struct
      object = RDF.literal("2025-01-15", datatype: RDF.iri("http://www.w3.org/2001/XMLSchema#date"))

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      # RDF.ex converts xsd:date to Elixir Date struct
      assert {:literal, value, datatype, nil} = triple.object
      assert value == ~D[2025-01-15]
      assert datatype == "http://www.w3.org/2001/XMLSchema#date"
    end
  end

  describe "from_rdf_triple/2 - graph provenance" do
    test "tracks graph IRI for provenance" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
      object = RDF.iri("http://www.w3.org/2002/07/owl#Class")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "http://example.org/ontology#")

      assert triple.graph == "http://example.org/ontology#"
    end

    test "supports default graph name" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/predicate")
      object = RDF.iri("http://example.org/Object")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "default")

      assert triple.graph == "default"
    end
  end

  describe "from_rdf_triple/2 - error handling" do
    test "raises on invalid subject type" do
      # Literals cannot be subjects
      subject = RDF.literal("invalid")
      predicate = RDF.iri("http://example.org/predicate")
      object = RDF.iri("http://example.org/Object")

      assert_raise ArgumentError, ~r/Subject must be IRI or BlankNode/, fn ->
        Triple.from_rdf_triple({subject, predicate, object}, "graph")
      end
    end

    test "raises on invalid predicate type" do
      subject = RDF.iri("http://example.org/Subject")
      # Blank nodes cannot be predicates
      predicate = RDF.bnode("b1")
      object = RDF.iri("http://example.org/Object")

      assert_raise ArgumentError, ~r/Predicate must be IRI/, fn ->
        Triple.from_rdf_triple({subject, predicate, object}, "graph")
      end
    end

    test "raises on invalid object type (edge case)" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/predicate")
      # Completely invalid type
      object = "not_an_rdf_term"

      assert_raise ArgumentError, ~r/Object must be IRI, BlankNode, or Literal/, fn ->
        Triple.from_rdf_triple({subject, predicate, object}, "graph")
      end
    end
  end

  describe "Triple struct" do
    test "has all required fields" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/predicate")
      object = RDF.iri("http://example.org/Object")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert Map.has_key?(triple, :subject)
      assert Map.has_key?(triple, :predicate)
      assert Map.has_key?(triple, :object)
      assert Map.has_key?(triple, :graph)
    end

    test "is a proper struct" do
      subject = RDF.iri("http://example.org/Subject")
      predicate = RDF.iri("http://example.org/predicate")
      object = RDF.iri("http://example.org/Object")

      triple = Triple.from_rdf_triple({subject, predicate, object}, "graph")

      assert %Triple{} = triple
      assert triple.__struct__ == Triple
    end
  end
end
