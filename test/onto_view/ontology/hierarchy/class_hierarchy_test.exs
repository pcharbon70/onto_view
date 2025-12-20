defmodule OntoView.Ontology.Hierarchy.ClassHierarchyTest do
  use ExUnit.Case, async: true

  alias OntoView.Ontology.Hierarchy.ClassHierarchy
  alias OntoView.Ontology.TripleStore
  alias OntoView.Ontology.ImportResolver

  @hierarchy_fixture "test/support/fixtures/ontologies/class_hierarchy.ttl"
  @simple_fixture "test/support/fixtures/ontologies/valid_simple.ttl"

  # Namespace prefix for test assertions
  @ex "http://example.org/hierarchy#"

  describe "build/1" do
    test "builds hierarchy from triple store" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert %ClassHierarchy{} = hierarchy
      assert is_map(hierarchy.parent_to_children)
      assert %MapSet{} = hierarchy.all_class_iris
    end

    test "extracts all classes from the ontology" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      # Check that known classes are present
      assert MapSet.member?(hierarchy.all_class_iris, @ex <> "Animal")
      assert MapSet.member?(hierarchy.all_class_iris, @ex <> "Mammal")
      assert MapSet.member?(hierarchy.all_class_iris, @ex <> "Dog")
      assert MapSet.member?(hierarchy.all_class_iris, @ex <> "Cat")
    end

    test "handles empty triple store" do
      # Create minimal store with no classes
      {:ok, loaded} = ImportResolver.load_with_imports(@simple_fixture)
      store = TripleStore.from_loaded_ontologies(loaded)

      hierarchy = ClassHierarchy.build(store)
      assert %ClassHierarchy{} = hierarchy
    end
  end

  describe "children/2" do
    test "returns direct children of a class" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      children = ClassHierarchy.children(hierarchy, @ex <> "Mammal")

      assert @ex <> "Dog" in children
      assert @ex <> "Cat" in children
      assert length(children) == 2
    end

    test "returns children in linear hierarchy" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      # Animal has Mammal as child
      animal_children = ClassHierarchy.children(hierarchy, @ex <> "Animal")
      assert @ex <> "Mammal" in animal_children
    end

    test "returns empty list for leaf classes" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      # Dog has no children
      assert ClassHierarchy.children(hierarchy, @ex <> "Dog") == []
    end

    test "returns empty list for unknown IRI" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert ClassHierarchy.children(hierarchy, "http://example.org/unknown#Thing") == []
    end

    test "handles wide hierarchy (parent with many children)" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      vehicle_children = ClassHierarchy.children(hierarchy, @ex <> "Vehicle")

      assert @ex <> "Car" in vehicle_children
      assert @ex <> "Truck" in vehicle_children
      assert @ex <> "Motorcycle" in vehicle_children
      assert @ex <> "Bicycle" in vehicle_children
      assert @ex <> "Boat" in vehicle_children
      assert @ex <> "Airplane" in vehicle_children
      assert length(vehicle_children) == 6
    end

    test "handles deep hierarchy" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      # LevelA → LevelB → LevelC → LevelD → LevelE
      assert [@ex <> "LevelB"] = ClassHierarchy.children(hierarchy, @ex <> "LevelA")
      assert [@ex <> "LevelC"] = ClassHierarchy.children(hierarchy, @ex <> "LevelB")
      assert [@ex <> "LevelD"] = ClassHierarchy.children(hierarchy, @ex <> "LevelC")
      assert [@ex <> "LevelE"] = ClassHierarchy.children(hierarchy, @ex <> "LevelD")
      assert [] = ClassHierarchy.children(hierarchy, @ex <> "LevelE")
    end
  end

  describe "root_classes/1" do
    test "returns classes without explicit superclass" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      roots = ClassHierarchy.root_classes(hierarchy)

      # These classes have no rdfs:subClassOf:
      # - Animal (starts the animal hierarchy)
      # - Person (starts the person hierarchy)
      # - Event (orphan class)
      # - Location (orphan class)
      # - LevelA (starts the deep hierarchy)
      # - Vehicle (starts the vehicle hierarchy)

      assert @ex <> "Animal" in roots
      assert @ex <> "Person" in roots
      assert @ex <> "Event" in roots
      assert @ex <> "Location" in roots
      assert @ex <> "LevelA" in roots
      assert @ex <> "Vehicle" in roots
    end

    test "does not include classes with explicit superclass" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      roots = ClassHierarchy.root_classes(hierarchy)

      # These have rdfs:subClassOf and should not be roots
      refute @ex <> "Mammal" in roots
      refute @ex <> "Dog" in roots
      refute @ex <> "Cat" in roots
      refute @ex <> "Student" in roots
      refute @ex <> "Employee" in roots
    end
  end

  describe "has_children?/2" do
    test "returns true for classes with children" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert ClassHierarchy.has_children?(hierarchy, @ex <> "Animal")
      assert ClassHierarchy.has_children?(hierarchy, @ex <> "Mammal")
      assert ClassHierarchy.has_children?(hierarchy, @ex <> "Vehicle")
    end

    test "returns false for leaf classes" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      refute ClassHierarchy.has_children?(hierarchy, @ex <> "Dog")
      refute ClassHierarchy.has_children?(hierarchy, @ex <> "Cat")
      refute ClassHierarchy.has_children?(hierarchy, @ex <> "Location")
    end

    test "returns false for unknown classes" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      refute ClassHierarchy.has_children?(hierarchy, "http://example.org/unknown#X")
    end
  end

  describe "leaf_classes/1" do
    test "returns classes with no children" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      leaves = ClassHierarchy.leaf_classes(hierarchy)

      # Terminal classes in the hierarchy
      assert @ex <> "Dog" in leaves
      assert @ex <> "Cat" in leaves
      assert @ex <> "WorkingStudent" in leaves
      assert @ex <> "Conference" in leaves
      assert @ex <> "Location" in leaves
      assert @ex <> "LevelE" in leaves
      assert @ex <> "Car" in leaves
      assert @ex <> "Truck" in leaves
    end

    test "does not include classes with children" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      leaves = ClassHierarchy.leaf_classes(hierarchy)

      refute @ex <> "Animal" in leaves
      refute @ex <> "Mammal" in leaves
      refute @ex <> "Person" in leaves
      refute @ex <> "Vehicle" in leaves
    end
  end

  describe "child_count/2" do
    test "returns correct count for class with multiple children" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert ClassHierarchy.child_count(hierarchy, @ex <> "Vehicle") == 6
      assert ClassHierarchy.child_count(hierarchy, @ex <> "Mammal") == 2
    end

    test "returns correct count for class with single child" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert ClassHierarchy.child_count(hierarchy, @ex <> "Animal") == 1
      assert ClassHierarchy.child_count(hierarchy, @ex <> "LevelA") == 1
    end

    test "returns 0 for leaf classes" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert ClassHierarchy.child_count(hierarchy, @ex <> "Dog") == 0
      assert ClassHierarchy.child_count(hierarchy, @ex <> "LevelE") == 0
    end

    test "returns 0 for unknown classes" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert ClassHierarchy.child_count(hierarchy, "http://unknown#X") == 0
    end
  end

  describe "parents/1" do
    test "returns all classes that have children" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      parents = ClassHierarchy.parents(hierarchy)

      assert @ex <> "Animal" in parents
      assert @ex <> "Mammal" in parents
      assert @ex <> "Person" in parents
      assert @ex <> "Vehicle" in parents
      assert @ex <> "Event" in parents
    end

    test "includes owl:Thing when orphan classes exist" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      parents = ClassHierarchy.parents(hierarchy)

      assert hierarchy.owl_thing_iri in parents
    end
  end

  describe "class_count/1" do
    test "returns total number of classes" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      count = ClassHierarchy.class_count(hierarchy)

      # Count all classes in the fixture
      # Animal, Mammal, Dog, Cat = 4
      # Person, Student, Employee, WorkingStudent = 4
      # Event, Conference = 2
      # Location = 1
      # LevelA, LevelB, LevelC, LevelD, LevelE = 5
      # Vehicle, Car, Truck, Motorcycle, Bicycle, Boat, Airplane = 7
      # Total: 23 classes
      assert count == 23
    end
  end

  describe "class?/2" do
    test "returns true for known classes" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert ClassHierarchy.class?(hierarchy, @ex <> "Animal")
      assert ClassHierarchy.class?(hierarchy, @ex <> "Dog")
      assert ClassHierarchy.class?(hierarchy, @ex <> "Vehicle")
    end

    test "returns false for unknown IRIs" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      refute ClassHierarchy.class?(hierarchy, "http://example.org/unknown#Thing")
      refute ClassHierarchy.class?(hierarchy, @ex <> "NotAClass")
    end
  end

  describe "multiple inheritance" do
    test "class can have multiple parents" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      # WorkingStudent has two parents: Student and Employee
      # Check that WorkingStudent appears as a child of both
      student_children = ClassHierarchy.children(hierarchy, @ex <> "Student")
      employee_children = ClassHierarchy.children(hierarchy, @ex <> "Employee")

      assert @ex <> "WorkingStudent" in student_children
      assert @ex <> "WorkingStudent" in employee_children
    end

    test "WorkingStudent is a leaf class" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      leaves = ClassHierarchy.leaf_classes(hierarchy)
      assert @ex <> "WorkingStudent" in leaves
    end
  end

  describe "owl:Thing normalization" do
    test "orphan classes become children of owl:Thing" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      owl_thing_children = ClassHierarchy.children(hierarchy, hierarchy.owl_thing_iri)

      # Classes without rdfs:subClassOf should be under owl:Thing
      assert @ex <> "Animal" in owl_thing_children
      assert @ex <> "Person" in owl_thing_children
      assert @ex <> "Event" in owl_thing_children
      assert @ex <> "Location" in owl_thing_children
      assert @ex <> "LevelA" in owl_thing_children
      assert @ex <> "Vehicle" in owl_thing_children
    end

    test "classes with explicit subClassOf are not under owl:Thing" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      owl_thing_children = ClassHierarchy.children(hierarchy, hierarchy.owl_thing_iri)

      refute @ex <> "Mammal" in owl_thing_children
      refute @ex <> "Dog" in owl_thing_children
      refute @ex <> "Student" in owl_thing_children
      refute @ex <> "Conference" in owl_thing_children
    end

    test "owl:Thing IRI is stored correctly" do
      hierarchy = build_hierarchy(@hierarchy_fixture)

      assert hierarchy.owl_thing_iri == "http://www.w3.org/2002/07/owl#Thing"
    end
  end

  # Helper functions

  defp build_hierarchy(fixture_path) do
    {:ok, loaded} = ImportResolver.load_with_imports(fixture_path)
    store = TripleStore.from_loaded_ontologies(loaded)
    ClassHierarchy.build(store)
  end
end
