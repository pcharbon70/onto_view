defmodule OntoView.Ontology.Namespaces do
  @moduledoc """
  Standard RDF, RDFS, OWL, and XSD namespace IRIs.

  This module provides centralized access to commonly used namespace prefixes
  and IRI constants used throughout the OWL entity extraction system.

  ## Namespace Prefixes

  - `rdf/0` - RDF namespace (http://www.w3.org/1999/02/22-rdf-syntax-ns#)
  - `rdfs/0` - RDFS namespace (http://www.w3.org/2000/01/rdf-schema#)
  - `owl/0` - OWL namespace (http://www.w3.org/2002/07/owl#)
  - `xsd/0` - XSD namespace (http://www.w3.org/2001/XMLSchema#)

  ## Usage

      iex> Namespaces.rdf_type()
      {:iri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"}

      iex> Namespaces.owl_class()
      {:iri, "http://www.w3.org/2002/07/owl#Class"}

  Part of Task 1.3.100 — Section 1.3 Review Improvements
  """

  # ==========================================================================
  # Namespace Prefixes
  # ==========================================================================

  @doc "Returns the RDF namespace prefix."
  @spec rdf() :: String.t()
  def rdf, do: "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

  @doc "Returns the RDFS namespace prefix."
  @spec rdfs() :: String.t()
  def rdfs, do: "http://www.w3.org/2000/01/rdf-schema#"

  @doc "Returns the OWL namespace prefix."
  @spec owl() :: String.t()
  def owl, do: "http://www.w3.org/2002/07/owl#"

  @doc "Returns the XSD namespace prefix."
  @spec xsd() :: String.t()
  def xsd, do: "http://www.w3.org/2001/XMLSchema#"

  # ==========================================================================
  # RDF Terms
  # ==========================================================================

  @doc "Returns the rdf:type IRI as a tagged tuple."
  @spec rdf_type() :: {:iri, String.t()}
  def rdf_type, do: {:iri, rdf() <> "type"}

  # ==========================================================================
  # RDFS Terms
  # ==========================================================================

  @doc "Returns the rdfs:Class IRI as a tagged tuple."
  @spec rdfs_class() :: {:iri, String.t()}
  def rdfs_class, do: {:iri, rdfs() <> "Class"}

  @doc "Returns the rdfs:subClassOf IRI as a tagged tuple."
  @spec rdfs_sub_class_of() :: {:iri, String.t()}
  def rdfs_sub_class_of, do: {:iri, rdfs() <> "subClassOf"}

  @doc "Returns the rdfs:domain IRI as a tagged tuple."
  @spec rdfs_domain() :: {:iri, String.t()}
  def rdfs_domain, do: {:iri, rdfs() <> "domain"}

  @doc "Returns the rdfs:range IRI as a tagged tuple."
  @spec rdfs_range() :: {:iri, String.t()}
  def rdfs_range, do: {:iri, rdfs() <> "range"}

  @doc "Returns the rdfs:label IRI as a tagged tuple."
  @spec rdfs_label() :: {:iri, String.t()}
  def rdfs_label, do: {:iri, rdfs() <> "label"}

  @doc "Returns the rdfs:comment IRI as a tagged tuple."
  @spec rdfs_comment() :: {:iri, String.t()}
  def rdfs_comment, do: {:iri, rdfs() <> "comment"}

  # ==========================================================================
  # OWL Entity Types
  # ==========================================================================

  @doc "Returns the owl:Class IRI as a tagged tuple."
  @spec owl_class() :: {:iri, String.t()}
  def owl_class, do: {:iri, owl() <> "Class"}

  @doc "Returns the owl:ObjectProperty IRI as a tagged tuple."
  @spec owl_object_property() :: {:iri, String.t()}
  def owl_object_property, do: {:iri, owl() <> "ObjectProperty"}

  @doc "Returns the owl:DatatypeProperty IRI as a tagged tuple."
  @spec owl_datatype_property() :: {:iri, String.t()}
  def owl_datatype_property, do: {:iri, owl() <> "DatatypeProperty"}

  @doc "Returns the owl:AnnotationProperty IRI as a tagged tuple."
  @spec owl_annotation_property() :: {:iri, String.t()}
  def owl_annotation_property, do: {:iri, owl() <> "AnnotationProperty"}

  @doc "Returns the owl:NamedIndividual IRI as a tagged tuple."
  @spec owl_named_individual() :: {:iri, String.t()}
  def owl_named_individual, do: {:iri, owl() <> "NamedIndividual"}

  @doc "Returns the owl:Ontology IRI as a tagged tuple."
  @spec owl_ontology() :: {:iri, String.t()}
  def owl_ontology, do: {:iri, owl() <> "Ontology"}

  @doc "Returns the owl:imports IRI as a tagged tuple."
  @spec owl_imports() :: {:iri, String.t()}
  def owl_imports, do: {:iri, owl() <> "imports"}

  # ==========================================================================
  # OWL Property Characteristics
  # ==========================================================================

  @doc "Returns the owl:FunctionalProperty IRI as a tagged tuple."
  @spec owl_functional_property() :: {:iri, String.t()}
  def owl_functional_property, do: {:iri, owl() <> "FunctionalProperty"}

  @doc "Returns the owl:InverseFunctionalProperty IRI as a tagged tuple."
  @spec owl_inverse_functional_property() :: {:iri, String.t()}
  def owl_inverse_functional_property, do: {:iri, owl() <> "InverseFunctionalProperty"}

  @doc "Returns the owl:TransitiveProperty IRI as a tagged tuple."
  @spec owl_transitive_property() :: {:iri, String.t()}
  def owl_transitive_property, do: {:iri, owl() <> "TransitiveProperty"}

  @doc "Returns the owl:SymmetricProperty IRI as a tagged tuple."
  @spec owl_symmetric_property() :: {:iri, String.t()}
  def owl_symmetric_property, do: {:iri, owl() <> "SymmetricProperty"}

  # ==========================================================================
  # XSD Datatypes
  # ==========================================================================

  @doc "Returns the xsd:string IRI as a tagged tuple."
  @spec xsd_string() :: {:iri, String.t()}
  def xsd_string, do: {:iri, xsd() <> "string"}

  @doc "Returns the xsd:integer IRI as a tagged tuple."
  @spec xsd_integer() :: {:iri, String.t()}
  def xsd_integer, do: {:iri, xsd() <> "integer"}

  @doc "Returns the xsd:boolean IRI as a tagged tuple."
  @spec xsd_boolean() :: {:iri, String.t()}
  def xsd_boolean, do: {:iri, xsd() <> "boolean"}

  @doc "Returns the xsd:date IRI as a tagged tuple."
  @spec xsd_date() :: {:iri, String.t()}
  def xsd_date, do: {:iri, xsd() <> "date"}

  @doc "Returns the xsd:dateTime IRI as a tagged tuple."
  @spec xsd_date_time() :: {:iri, String.t()}
  def xsd_date_time, do: {:iri, xsd() <> "dateTime"}

  @doc "Returns the xsd:decimal IRI as a tagged tuple."
  @spec xsd_decimal() :: {:iri, String.t()}
  def xsd_decimal, do: {:iri, xsd() <> "decimal"}

  @doc "Returns the xsd:double IRI as a tagged tuple."
  @spec xsd_double() :: {:iri, String.t()}
  def xsd_double, do: {:iri, xsd() <> "double"}

  @doc "Returns the xsd:float IRI as a tagged tuple."
  @spec xsd_float() :: {:iri, String.t()}
  def xsd_float, do: {:iri, xsd() <> "float"}

  @doc "Returns the xsd:anyURI IRI as a tagged tuple."
  @spec xsd_any_uri() :: {:iri, String.t()}
  def xsd_any_uri, do: {:iri, xsd() <> "anyURI"}

  @doc "Returns the xsd:time IRI as a tagged tuple."
  @spec xsd_time() :: {:iri, String.t()}
  def xsd_time, do: {:iri, xsd() <> "time"}

  @doc "Returns the xsd:duration IRI as a tagged tuple."
  @spec xsd_duration() :: {:iri, String.t()}
  def xsd_duration, do: {:iri, xsd() <> "duration"}

  # ==========================================================================
  # Excluded Types for Individual Class Association
  # ==========================================================================

  @doc """
  Returns a list of OWL/RDFS types to exclude when extracting class associations
  for named individuals.

  These are meta-types that should not be considered as class memberships.
  """
  @spec excluded_individual_types() :: [iri_tuple :: {:iri, String.t()}]
  def excluded_individual_types do
    [
      owl_named_individual(),
      owl_class(),
      rdfs_class(),
      owl_object_property(),
      owl_datatype_property(),
      owl_annotation_property(),
      owl_ontology()
    ]
  end
end
