defmodule OntoView.Ontology.NamespacesTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Namespaces

  describe "namespace prefixes" do
    test "rdf/0 returns RDF namespace" do
      assert Namespaces.rdf() == "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    end

    test "rdfs/0 returns RDFS namespace" do
      assert Namespaces.rdfs() == "http://www.w3.org/2000/01/rdf-schema#"
    end

    test "owl/0 returns OWL namespace" do
      assert Namespaces.owl() == "http://www.w3.org/2002/07/owl#"
    end

    test "xsd/0 returns XSD namespace" do
      assert Namespaces.xsd() == "http://www.w3.org/2001/XMLSchema#"
    end
  end

  describe "RDF terms" do
    test "rdf_type/0 returns tagged IRI tuple" do
      assert Namespaces.rdf_type() == {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"}
    end
  end

  describe "RDFS terms" do
    test "rdfs_class/0 returns tagged IRI tuple" do
      assert Namespaces.rdfs_class() == {:iri, "http://www.w3.org/2000/01/rdf-schema#Class"}
    end

    test "rdfs_sub_class_of/0 returns tagged IRI tuple" do
      assert Namespaces.rdfs_sub_class_of() ==
               {:iri, "http://www.w3.org/2000/01/rdf-schema#subClassOf"}
    end

    test "rdfs_domain/0 returns tagged IRI tuple" do
      assert Namespaces.rdfs_domain() == {:iri, "http://www.w3.org/2000/01/rdf-schema#domain"}
    end

    test "rdfs_range/0 returns tagged IRI tuple" do
      assert Namespaces.rdfs_range() == {:iri, "http://www.w3.org/2000/01/rdf-schema#range"}
    end

    test "rdfs_label/0 returns tagged IRI tuple" do
      assert Namespaces.rdfs_label() == {:iri, "http://www.w3.org/2000/01/rdf-schema#label"}
    end

    test "rdfs_comment/0 returns tagged IRI tuple" do
      assert Namespaces.rdfs_comment() == {:iri, "http://www.w3.org/2000/01/rdf-schema#comment"}
    end
  end

  describe "OWL entity types" do
    test "owl_class/0 returns tagged IRI tuple" do
      assert Namespaces.owl_class() == {:iri, "http://www.w3.org/2002/07/owl#Class"}
    end

    test "owl_object_property/0 returns tagged IRI tuple" do
      assert Namespaces.owl_object_property() ==
               {:iri, "http://www.w3.org/2002/07/owl#ObjectProperty"}
    end

    test "owl_datatype_property/0 returns tagged IRI tuple" do
      assert Namespaces.owl_datatype_property() ==
               {:iri, "http://www.w3.org/2002/07/owl#DatatypeProperty"}
    end

    test "owl_annotation_property/0 returns tagged IRI tuple" do
      assert Namespaces.owl_annotation_property() ==
               {:iri, "http://www.w3.org/2002/07/owl#AnnotationProperty"}
    end

    test "owl_named_individual/0 returns tagged IRI tuple" do
      assert Namespaces.owl_named_individual() ==
               {:iri, "http://www.w3.org/2002/07/owl#NamedIndividual"}
    end

    test "owl_ontology/0 returns tagged IRI tuple" do
      assert Namespaces.owl_ontology() == {:iri, "http://www.w3.org/2002/07/owl#Ontology"}
    end

    test "owl_imports/0 returns tagged IRI tuple" do
      assert Namespaces.owl_imports() == {:iri, "http://www.w3.org/2002/07/owl#imports"}
    end
  end

  describe "OWL property characteristics" do
    test "owl_functional_property/0 returns tagged IRI tuple" do
      assert Namespaces.owl_functional_property() ==
               {:iri, "http://www.w3.org/2002/07/owl#FunctionalProperty"}
    end

    test "owl_inverse_functional_property/0 returns tagged IRI tuple" do
      assert Namespaces.owl_inverse_functional_property() ==
               {:iri, "http://www.w3.org/2002/07/owl#InverseFunctionalProperty"}
    end

    test "owl_transitive_property/0 returns tagged IRI tuple" do
      assert Namespaces.owl_transitive_property() ==
               {:iri, "http://www.w3.org/2002/07/owl#TransitiveProperty"}
    end

    test "owl_symmetric_property/0 returns tagged IRI tuple" do
      assert Namespaces.owl_symmetric_property() ==
               {:iri, "http://www.w3.org/2002/07/owl#SymmetricProperty"}
    end
  end

  describe "XSD datatypes" do
    test "xsd_string/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_string() == {:iri, "http://www.w3.org/2001/XMLSchema#string"}
    end

    test "xsd_integer/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_integer() == {:iri, "http://www.w3.org/2001/XMLSchema#integer"}
    end

    test "xsd_boolean/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_boolean() == {:iri, "http://www.w3.org/2001/XMLSchema#boolean"}
    end

    test "xsd_date/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_date() == {:iri, "http://www.w3.org/2001/XMLSchema#date"}
    end

    test "xsd_date_time/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_date_time() == {:iri, "http://www.w3.org/2001/XMLSchema#dateTime"}
    end

    test "xsd_decimal/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_decimal() == {:iri, "http://www.w3.org/2001/XMLSchema#decimal"}
    end

    test "xsd_double/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_double() == {:iri, "http://www.w3.org/2001/XMLSchema#double"}
    end

    test "xsd_float/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_float() == {:iri, "http://www.w3.org/2001/XMLSchema#float"}
    end

    test "xsd_any_uri/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_any_uri() == {:iri, "http://www.w3.org/2001/XMLSchema#anyURI"}
    end

    test "xsd_time/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_time() == {:iri, "http://www.w3.org/2001/XMLSchema#time"}
    end

    test "xsd_duration/0 returns tagged IRI tuple" do
      assert Namespaces.xsd_duration() == {:iri, "http://www.w3.org/2001/XMLSchema#duration"}
    end
  end

  describe "excluded_individual_types/0" do
    test "returns list of OWL meta-types to exclude" do
      excluded = Namespaces.excluded_individual_types()

      assert is_list(excluded)
      assert length(excluded) == 7

      assert Namespaces.owl_named_individual() in excluded
      assert Namespaces.owl_class() in excluded
      assert Namespaces.rdfs_class() in excluded
      assert Namespaces.owl_object_property() in excluded
      assert Namespaces.owl_datatype_property() in excluded
      assert Namespaces.owl_annotation_property() in excluded
      assert Namespaces.owl_ontology() in excluded
    end
  end
end
