# Copyright © 2024 Parameter Toolkit Contributors - MIT License
class_name ParameterGroup extends RefCounted

## Hierarchical container for parameters and sub-groups.
##
## Provides path-based parameter lookup and JSON serialization for entire parameter trees.
## Supports inheritance and templates for rapid parameter creation.

signal parameter_added(parameter)
signal parameter_removed(parameter_name: String)
signal group_added(group: ParameterGroup)
signal group_removed(group_name: String)

## Group identification
var name: String = ""
var description: String = ""
var path: String = ""  # Full path like "visual" or "visual/effects"

## Collections
var parameters: Dictionary = {}  # String -> Parameter
var groups: Dictionary = {}      # String -> ParameterGroup

## Performance optimization
var _param_cache: Dictionary = {}  # Full path -> Parameter
var _cache_dirty: bool = true

## Parent reference for path building
var parent: ParameterGroup = null

func _init(group_name: String = ""):
	name = group_name

## Add a parameter to this group
func add_parameter(parameter) -> bool:
	if parameter.name in parameters:
		push_warning("Parameter '%s' already exists in group '%s'" % [parameter.name, name])
		return false
	
	parameters[parameter.name] = parameter
	parameter.path = _build_parameter_path(parameter.name)
	_invalidate_cache()
	parameter_added.emit(parameter)
	return true

## Remove a parameter from this group
func remove_parameter(parameter_name: String) -> bool:
	if parameter_name not in parameters:
		return false
	
	var _parameter = parameters[parameter_name]
	parameters.erase(parameter_name)
	_invalidate_cache()
	parameter_removed.emit(parameter_name)
	return true

## Get a parameter by name (local to this group)
func get_parameter(parameter_name: String):
	return parameters.get(parameter_name)

## Add a sub-group to this group
func add_group(group: ParameterGroup) -> bool:
	if group.name in groups:
		push_warning("Group '%s' already exists in group '%s'" % [group.name, name])
		return false
	
	groups[group.name] = group
	group.parent = self
	group.path = _build_group_path(group.name)
	group._update_all_paths()
	_invalidate_cache()
	group_added.emit(group)
	return true

## Remove a sub-group from this group
func remove_group(group_name: String) -> bool:
	if group_name not in groups:
		return false
	
	var group = groups[group_name]
	group.parent = null
	groups.erase(group_name)
	_invalidate_cache()
	group_removed.emit(group_name)
	return true

## Get a sub-group by name (local to this group)
func get_group(group_name: String) -> ParameterGroup:
	return groups.get(group_name)

## Get a parameter by full path (e.g., "visual/brightness")
func get_param(param_path: String):
	if _cache_dirty:
		_rebuild_cache()
	
	return _param_cache.get(param_path)

## Set a parameter value by path
func set_param(param_path: String, value: Variant) -> bool:
	var parameter = get_param(param_path)
	if parameter:
		return parameter.set_value(value)
	
	push_warning("Parameter not found: %s" % param_path)
	return false

## Get a parameter value by path
func get_param_value(param_path: String, default_value: Variant = null) -> Variant:
	var parameter = get_param(param_path)
	if parameter:
		return parameter.get_value()
	return default_value

## Get all parameter paths in this group and sub-groups
func get_all_param_paths() -> Array[String]:
	if _cache_dirty:
		_rebuild_cache()
	
	return _param_cache.keys()

## Create a parameter from a template
func create_from_template(param_name: String, template_data: Dictionary):
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var parameter = ParameterClass.new(param_name, template_data.get("type", "float"))
	
	# Apply template properties
	if template_data.has("value"):
		parameter.default_value = template_data["value"]
		parameter.value = template_data["value"]
	if template_data.has("min"):
		parameter.min_value = template_data["min"]
	if template_data.has("max"):
		parameter.max_value = template_data["max"]
	if template_data.has("step"):
		parameter.step = template_data["step"]
	if template_data.has("enum_values"):
		parameter.enum_values = template_data["enum_values"]
	if template_data.has("exposed"):
		parameter.exposed = template_data["exposed"]
	if template_data.has("ui_hints"):
		parameter.ui_hints = template_data["ui_hints"]
	if template_data.has("description"):
		parameter.description = template_data["description"]
	
	return parameter

## Convert to JSON dictionary
func to_json() -> Dictionary:
	var json_data = {
		"name": name,
		"params": [],
		"groups": []
	}
	
	if description != "":
		json_data["description"] = description
	
	# Serialize parameters
	for param in parameters.values():
		json_data["params"].append(param.to_json())
	
	# Serialize sub-groups
	for group in groups.values():
		json_data["groups"].append(group.to_json())
	
	return json_data

## Load from JSON dictionary
func from_json(json_data: Dictionary) -> bool:
	if not json_data.has("name"):
		push_error("ParameterGroup JSON missing required field: name")
		return false
	
	name = json_data["name"]
	description = json_data.get("description", "")
	
	# Clear existing data
	parameters.clear()
	groups.clear()
	
	# Load parameters
	if json_data.has("params"):
		if not _load_parameters_from_json(json_data["params"]):
			return false
	
	# Load sub-groups
	if json_data.has("groups"):
		if not _load_groups_from_json(json_data["groups"]):
			return false
	
	return true

func _load_parameters_from_json(params_data: Array) -> bool:
	for param_data in params_data:
		if not param_data is Dictionary:
			push_error("Invalid parameter data format")
			continue
		
		var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
		if not ParameterClass:
			push_error("Failed to load Parameter class")
			return false
		
		var parameter = ParameterClass.new()
		if parameter.from_json(param_data):
			add_parameter(parameter)
		else:
			push_error("Failed to load parameter: %s" % param_data.get("name", "unknown"))
			return false
	
	return true

func _load_groups_from_json(groups_data: Array) -> bool:
	for group_data in groups_data:
		if not group_data is Dictionary:
			push_error("Invalid group data format")
			continue
		
		var group = ParameterGroup.new()
		if group.from_json(group_data):
			add_group(group)
		else:
			push_error("Failed to load group: %s" % group_data.get("name", "unknown"))
			return false
	
	return true

## Merge another group's data into this group (for user preset loading)
func merge_json(json_data: Dictionary, overwrite: bool = false) -> void:
	# Merge parameters
	if json_data.has("params"):
		_merge_parameters_from_json(json_data["params"], overwrite)
	
	# Merge sub-groups
	if json_data.has("groups"):
		_merge_groups_from_json(json_data["groups"], overwrite)

func _merge_parameters_from_json(params_data: Array, overwrite: bool) -> void:
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	if not ParameterClass:
		push_error("Failed to load Parameter class for merging")
		return
	
	for param_data in params_data:
		if not param_data is Dictionary:
			continue
		
		var param_name = param_data.get("name", "")
		if param_name == "":
			continue
		
		var existing_param = get_parameter(param_name)
		if existing_param and param_data.has("value"):
			existing_param.set_value(param_data["value"])
		elif not existing_param and overwrite:
			var new_param = ParameterClass.new()
			if new_param.from_json(param_data):
				add_parameter(new_param)

func _merge_groups_from_json(groups_data: Array, overwrite: bool) -> void:
	for group_data in groups_data:
		if not group_data is Dictionary:
			continue
		
		var group_name = group_data.get("name", "")
		if group_name == "":
			continue
		
		var existing_group = get_group(group_name)
		if existing_group:
			existing_group.merge_json(group_data, overwrite)
		elif overwrite:
			var new_group = ParameterGroup.new()
			if new_group.from_json(group_data):
				add_group(new_group)

## Get statistics about this group
func get_stats() -> Dictionary:
	var total_params = 0
	var total_groups = 0
	var max_depth = 0
	
	_calculate_stats(total_params, total_groups, max_depth, 0)
	
	return {
		"total_parameters": total_params,
		"total_groups": total_groups,
		"max_depth": max_depth
	}

# Private helper methods

func _build_parameter_path(param_name: String) -> String:
	if path == "":
		return param_name
	return path + "/" + param_name

func _build_group_path(group_name: String) -> String:
	if path == "":
		return group_name
	return path + "/" + group_name

func _update_all_paths() -> void:
	# Update own path
	if parent:
		path = parent._build_group_path(name)
	else:
		path = name if name != "" else ""
	
	# Update parameter paths
	for param in parameters.values():
		param.path = _build_parameter_path(param.name)
	
	# Update sub-group paths recursively
	for group in groups.values():
		group._update_all_paths()
	
	_invalidate_cache()

func _invalidate_cache() -> void:
	_cache_dirty = true
	if parent:
		parent._invalidate_cache()

func _rebuild_cache() -> void:
	_param_cache.clear()
	_build_cache_recursive()
	_cache_dirty = false

func _build_cache_recursive() -> void:
	# Add own parameters
	for param in parameters.values():
		_param_cache[param.path] = param
	
	# Add sub-group parameters recursively
	for group in groups.values():
		group._build_cache_recursive()
		for param_path in group._param_cache:
			_param_cache[param_path] = group._param_cache[param_path]

func _calculate_stats(total_params: int, total_groups: int, max_depth: int, current_depth: int) -> void:
	total_params += parameters.size()
	total_groups += groups.size()
	max_depth = max(max_depth, current_depth)
	
	for group in groups.values():
		group._calculate_stats(total_params, total_groups, max_depth, current_depth + 1)
