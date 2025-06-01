# Copyright © 2024 Parameter Toolkit Contributors - MIT License
class_name Parameter extends RefCounted

## Individual parameter with validation, type safety, and change notifications.
##
## Represents a single adjustable value with constraints, validation rules,
## and UI hints for automatic widget generation.

signal changed(value: Variant)

## Core properties
var name: String = ""
var type: String = "float"  # float, int, bool, enum, color, string
var value: Variant
var default_value: Variant
var path: String = ""  # Full path like "visual/brightness"

## Constraints
var min_value: Variant
var max_value: Variant
var step: float = 0.0
var enum_values: Array[String] = []

## Metadata
var description: String = ""
var exposed: bool = true  # Whether parameter appears in OSC/Web interfaces
var ui_hints: Dictionary = {}  # Widget type, precision, etc.

## Validation
var validation_rules: Array[String] = []
var custom_validator: String = ""

func _init(param_name: String = "", param_type: String = "float"):
	name = param_name
	type = param_type
	_set_default_constraints()

## Set the parameter value with validation and constraints
func set_value(new_value: Variant) -> bool:
	var validated_value = _validate_and_clamp(new_value)
	if validated_value == null:
		return false
	
	var _old_value = value
	value = validated_value
	changed.emit(value)
	return true

## Get the current value
func get_value() -> Variant:
	return value

## Reset to default value
func reset_to_default() -> void:
	set_value(default_value)

## Add a validation rule
func add_validation_rule(rule: String) -> void:
	if rule not in validation_rules:
		validation_rules.append(rule)

## Get validation errors for a given value
func get_validation_errors(test_value: Variant = value) -> Array[String]:
	var errors: Array[String] = []
	
	# Type validation
	if not _is_valid_type(test_value):
		errors.append("Invalid type for parameter '%s'. Expected %s, got %s" % [name, type, typeof(test_value)])
		return errors
	
	# Range validation
	if min_value != null and test_value < min_value:
		errors.append("Value %s is below minimum %s" % [test_value, min_value])
	
	if max_value != null and test_value > max_value:
		errors.append("Value %s is above maximum %s" % [test_value, max_value])
	
	# Enum validation
	if type == "enum" and enum_values.size() > 0:
		if test_value not in enum_values:
			errors.append("Value '%s' not in allowed values: %s" % [test_value, enum_values])
	
	return errors

## Convert to JSON dictionary
func to_json() -> Dictionary:
	var json_data = {
		"name": name,
		"type": type,
		"value": value
	}
	
	if default_value != null:
		json_data["default_value"] = default_value
	if min_value != null:
		json_data["min"] = min_value
	if max_value != null:
		json_data["max"] = max_value
	if step != 0.0:
		json_data["step"] = step
	if enum_values.size() > 0:
		json_data["enum_values"] = enum_values
	if description != "":
		json_data["description"] = description
	if not exposed:
		json_data["exposed"] = exposed
	if ui_hints.size() > 0:
		json_data["ui_hints"] = ui_hints
	if validation_rules.size() > 0:
		json_data["validation_rules"] = validation_rules
	if custom_validator != "":
		json_data["custom_validator"] = custom_validator
	
	return json_data

## Load from JSON dictionary
func from_json(json_data: Dictionary) -> bool:
	if not json_data.has("name") or not json_data.has("type"):
		push_error("Parameter JSON missing required fields: name, type")
		return false
	
	name = json_data["name"]
	type = json_data["type"]
	
	# Set default constraints for type
	_set_default_constraints()
	
	# Load optional fields
	if json_data.has("value"):
		value = json_data["value"]
	if json_data.has("default_value"):
		default_value = json_data["default_value"]
	else:
		default_value = value
	
	if json_data.has("min"):
		min_value = json_data["min"]
	if json_data.has("max"):
		max_value = json_data["max"]
	if json_data.has("step"):
		step = json_data["step"]
	if json_data.has("enum_values"):
		enum_values = json_data["enum_values"]
	if json_data.has("description"):
		description = json_data["description"]
	if json_data.has("exposed"):
		exposed = json_data["exposed"]
	if json_data.has("ui_hints"):
		ui_hints = json_data["ui_hints"]
	if json_data.has("validation_rules"):
		validation_rules = json_data["validation_rules"]
	if json_data.has("custom_validator"):
		custom_validator = json_data["custom_validator"]
	
	return true

# Private helper methods

func _set_default_constraints() -> void:
	match type:
		"float":
			if min_value == null: min_value = 0.0
			if max_value == null: max_value = 1.0
			if value == null: value = 0.5
			step = 0.01
		"int":
			if min_value == null: min_value = 0
			if max_value == null: max_value = 100
			if value == null: value = 50
			step = 1.0
		"bool":
			if value == null: value = false
		"string":
			if value == null: value = ""
		"color":
			if value == null: value = Color.WHITE
		"enum":
			if value == null and enum_values.size() > 0:
				value = enum_values[0]
	
	if default_value == null:
		default_value = value

func _validate_and_clamp(test_value: Variant) -> Variant:
	# Type validation
	if not _is_valid_type(test_value):
		push_warning("Invalid type for parameter '%s'. Expected %s, got %s" % [name, type, typeof(test_value)])
		return null
	
	# Type-specific validation and clamping
	match type:
		"float", "int":
			if min_value != null:
				test_value = max(test_value, min_value)
			if max_value != null:
				test_value = min(test_value, max_value)
			if step > 0.0:
				test_value = round(test_value / step) * step
		"enum":
			if enum_values.size() > 0 and test_value not in enum_values:
				push_warning("Invalid enum value '%s' for parameter '%s'" % [test_value, name])
				return null
	
	return test_value

func _is_valid_type(test_value: Variant) -> bool:
	match type:
		"float":
			return test_value is float or test_value is int
		"int":
			return test_value is int
		"bool":
			return test_value is bool
		"string":
			return test_value is String
		"color":
			return test_value is Color
		"enum":
			return test_value is String
		_:
			return false
