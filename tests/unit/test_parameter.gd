# Copyright © 2024 Parameter Toolkit Contributors - MIT License

# Try to extend GutTest if available, otherwise extend RefCounted for basic testing
extends RefCounted

## Basic unit tests for Parameter class
##
## Tests parameter creation, validation, serialization, and value management.

var ParameterClass = preload("res://addons/parameter_toolkit/core/parameter.gd")

func test_parameter_creation():
	var param = ParameterClass.new("test_param", "float")
	assert_eq(param.name, "test_param")
	assert_eq(param.type, "float")
	assert_eq(param.value, 0.5)  # Default for float
	print("✓ Parameter creation test passed")

func test_parameter_value_setting():
	var param = ParameterClass.new("brightness", "float")
	
	# Test valid value
	var success = param.set_value(0.8)
	assert_true(success)
	assert_eq(param.value, 0.8)
	
	# Test clamping
	param.set_value(2.0)  # Should be clamped to max (1.0)
	assert_eq(param.value, 1.0)
	
	print("✓ Parameter value setting test passed")

func test_parameter_constraints():
	var param = ParameterClass.new("clamped", "float")
	param.min_value = 0.0
	param.max_value = 1.0
	
	param.set_value(1.5)  # Should clamp to 1.0
	assert_eq(param.get_value(), 1.0)
	
	param.set_value(-0.5)  # Should clamp to 0.0
	assert_eq(param.get_value(), 0.0)
	
	print("✓ Parameter constraints test passed")

func test_parameter_json_serialization():
	var param = ParameterClass.new("volume", "float")
	param.set_value(0.7)
	param.description = "Audio volume level"
	
	var json_data = param.to_json()
	assert_true(json_data.has("name"))
	assert_true(json_data.has("type"))
	assert_true(json_data.has("value"))
	assert_eq(json_data["value"], 0.7)
	
	# Test round-trip
	var new_param = ParameterClass.new()
	var success = new_param.from_json(json_data)
	assert_true(success)
	assert_eq(new_param.name, "volume")
	assert_eq(new_param.value, 0.7)
	
	print("✓ Parameter JSON serialization test passed")

func run_tests():
	print("Running Parameter tests...")
	test_parameter_creation()
	test_parameter_value_setting()
	test_parameter_constraints()
	test_parameter_json_serialization()
	print("All Parameter tests completed!")

# Helper functions for basic assertions
func assert_eq(actual, expected):
	if actual != expected:
		push_error("Assertion failed: expected %s, got %s" % [expected, actual])

func assert_true(value):
	if not value:
		push_error("Assertion failed: expected true, got %s" % value)
