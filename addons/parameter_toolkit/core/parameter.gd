# Copyright © 2024 Parameter Toolkit Contributors - MIT License

class_name Parameter extends RefCounted

## A single parameter with type, constraints, and change notifications

signal changed(value: Variant)

var name: String
var type: String  # "float", "int", "bool", "string", "color", "enum"
var value: Variant
var min_value: Variant = null
var max_value: Variant = null
var step: float = 0.0
var enum_values: Array = []
var exposed: bool = true
var description: String = ""

## Enhanced validation (Week 3 feature placeholder)
var validation_rules: Array = []

func _init(param_name: String = "", param_type: String = "float"):
	name = param_name
	type = param_type
	_set_default_value()

func _set_default_value():
	match type:
		"float":
			value = 0.0
		"int":
			value = 0
		"bool":
			value = false
		"string":
			value = ""
		"color":
			value = Color.WHITE
		"enum":
			value = 0

func set_value(new_value: Variant) -> bool:
	var clamped_value = _clamp_value(new_value)
	
	if value != clamped_value:
		value = clamped_value
		changed.emit(value)
		return true
	
	return false

func get_value() -> Variant:
	return value

func _clamp_value(input_value: Variant) -> Variant:
	match type:
		"float":
			var float_val = float(input_value)
			if min_value != null:
				float_val = max(float_val, float(min_value))
			if max_value != null:
				float_val = min(float_val, float(max_value))
			if step > 0:
				float_val = round(float_val / step) * step
			return float_val
		
		"int":
			var int_val = int(input_value)
			if min_value != null:
				int_val = max(int_val, int(min_value))
			if max_value != null:
				int_val = min(int_val, int(max_value))
			return int_val
		
		"bool":
			return bool(input_value)
		
		"string":
			return str(input_value)
		
		"color":
			if input_value is Color:
				return input_value
			elif input_value is String:
				return Color(input_value)
			else:
				return Color.WHITE
		
		"enum":
			var enum_val = int(input_value)
			if enum_values.size() > 0:
				enum_val = clamp(enum_val, 0, enum_values.size() - 1)
			return enum_val
		
		_:
			return input_value

## Get validation errors for current value (Week 3 feature)
func get_validation_errors() -> Array[String]:
	var errors = []
	
	# Basic validation checks
	if type == "float" or type == "int":
		if min_value != null and value < min_value:
			errors.append("Value %s below minimum %s" % [value, min_value])
		if max_value != null and value > max_value:
			errors.append("Value %s above maximum %s" % [value, max_value])
	
	# TODO: Week 3 - Add custom validation rules processing
	for rule in validation_rules:
		pass  # Process validation rules
	
	return errors

func to_json() -> Dictionary:
	var data = {
		"name": name,
		"type": type,
		"value": value,
		"exposed": exposed,
		"description": description
	}
	
	if min_value != null:
		data["min"] = min_value
	if max_value != null:
		data["max"] = max_value
	if step > 0:
		data["step"] = step
	if not enum_values.is_empty():
		data["enum_values"] = enum_values
	
	return data

func from_json(data: Dictionary) -> bool:
	if not data.has("name") or not data.has("type"):
		return false
	
	name = data.name
	type = data.type
	
	if data.has("value"):
		set_value(data.value)
	
	if data.has("min"):
		min_value = data.min
	if data.has("max"):
		max_value = data.max
	if data.has("step"):
		step = data.step
	if data.has("enum_values"):
		enum_values = data.enum_values
	if data.has("exposed"):
		exposed = data.exposed
	if data.has("description"):
		description = data.description
	
	return true
