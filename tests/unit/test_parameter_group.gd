# Copyright © 2024 Parameter Toolkit Contributors - MIT License
extends RefCounted

## Basic unit tests for ParameterGroup class

var ParameterClass = preload("res://addons/parameter_toolkit/core/parameter.gd")
var ParameterGroupClass = preload("res://addons/parameter_toolkit/core/parameter_group.gd")

func test_group_creation():
	var group = ParameterGroupClass.new("test_group")
	assert_eq(group.name, "test_group")
	assert_eq(group.parameters.size(), 0)
	print("✓ ParameterGroup creation test passed")

func test_parameter_management():
	var group = ParameterGroupClass.new("audio")
	var param = ParameterClass.new("volume", "float")
	
	# Test adding parameter
	var success = group.add_parameter(param)
	assert_true(success)
	assert_eq(group.parameters.size(), 1)
	
	# Test getting parameter
	var retrieved = group.get_parameter("volume")
	assert_eq(retrieved, param)
	
	# Test removing parameter
	success = group.remove_parameter("volume")
	assert_true(success)
	assert_eq(group.parameters.size(), 0)
	
	print("✓ Parameter management test passed")

func test_group_hierarchy():
	var root = ParameterGroupClass.new("root")
	var child = ParameterGroupClass.new("visual")
	
	var success = root.add_group(child)
	assert_true(success)
	assert_eq(child.parent, root)
	assert_eq(child.path, "visual")
	
	print("✓ Group hierarchy test passed")

func run_tests():
	print("Running ParameterGroup tests...")
	test_group_creation()
	test_parameter_management()
	test_group_hierarchy()
	print("All ParameterGroup tests completed!")

# Helper functions
func assert_eq(actual, expected):
	if actual != expected:
		push_error("Assertion failed: expected %s, got %s" % [expected, actual])

func assert_true(value):
	if not value:
		push_error("Assertion failed: expected true, got %s" % value)
