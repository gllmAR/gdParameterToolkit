# Copyright © 2024 Parameter Toolkit Contributors - MIT License
extends RefCounted

## Basic unit tests for ParameterGroup class

var ParameterGroupClass = preload("res://addons/parameter_toolkit/core/parameter_group.gd")

func test_group_creation():
	var group = ParameterGroupClass.new("test_group")
	assert_eq(group.name, "test_group")
	assert_eq(group.parameters.size(), 0)
	print("✓ ParameterGroup creation test passed")

func test_parameter_management():
	var group = ParameterGroupClass.new("audio")
	
	# Create a simple mock parameter for testing
	var param = _create_mock_parameter("volume", "float")
	
	# Test adding parameter
	group.add_parameter(param)
	assert_eq(group.parameters.size(), 1)
	
	# Test getting parameter by name
	var retrieved = group.get_parameter_by_name("volume")
	assert_eq(retrieved, param)
	
	print("✓ Parameter management test passed")

func test_group_hierarchy():
	var root = ParameterGroupClass.new("root")
	var child = ParameterGroupClass.new("visual")
	
	root.add_group(child)
	assert_eq(child.parent, root)
	assert_eq(root.groups.size(), 1)
	
	# Test getting group by name
	var retrieved_child = root.get_group_by_name("visual")
	assert_eq(retrieved_child, child)
	
	print("✓ Group hierarchy test passed")

func run_tests():
	print("Running ParameterGroup tests...")
	test_group_creation()
	test_parameter_management()
	test_group_hierarchy()
	print("All ParameterGroup tests completed!")

# Helper function to create mock parameter for testing
func _create_mock_parameter(param_name: String, param_type: String):
	# Simple mock object that mimics Parameter interface
	var mock = RefCounted.new()
	mock.set("name", param_name)
	mock.set("type", param_type)
	mock.set("value", 0.0)
	return mock

# Helper functions
func assert_eq(actual, expected):
	if actual != expected:
		push_error("Assertion failed: expected %s, got %s" % [expected, actual])

func assert_true(value):
	if not value:
		push_error("Assertion failed: expected true, got %s" % value)
