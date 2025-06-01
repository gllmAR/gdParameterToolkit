# Copyright © 2024 Parameter Toolkit Contributors - MIT License

class_name ParameterGroup extends RefCounted

## Hierarchical container for parameters and sub-groups

var name: String
var description: String = ""
var parameters: Dictionary = {}  # name -> Parameter
var groups: Dictionary = {}      # name -> ParameterGroup
var parent: ParameterGroup = null

## Performance optimization
var _param_cache: Dictionary = {}
var _cache_valid: bool = false

func _init(group_name: String = ""):
	name = group_name

func add_parameter(parameter) -> void:
	if parameter == null:
		push_error("Cannot add null parameter")
		return
	
	parameters[parameter.name] = parameter
	_invalidate_cache()

func add_group(group: ParameterGroup) -> void:
	if group == null:
		push_error("Cannot add null group")
		return
	
	groups[group.name] = group
	group.parent = self
	_invalidate_cache()

## Get parameter by name (within this group only)
func get_parameter_by_name(param_name: String):
	return parameters.get(param_name)

## Get group by name (within this group only)  
func get_group_by_name(group_name: String):
	return groups.get(group_name)

## Get parameter by path (supports traversal)
func get_param(path: String):
	if path.is_empty():
		return null
	
	# If no cache or cache is invalid, rebuild it
	if not _cache_valid:
		_rebuild_cache()
	
	# First try direct cache lookup
	if _param_cache.has(path):
		return _param_cache[path]
	
	# If not found, try manual traversal for debugging
	return _get_param_manual(path)

## Manual parameter traversal for fallback and debugging
func _get_param_manual(path: String):
	var parts = path.split("/")
	var current_group = self
	
	# Navigate to the target group
	for i in range(parts.size() - 1):
		var part = parts[i]
		if part.is_empty():
			continue
		
		if current_group.groups.has(part):
			current_group = current_group.groups[part]
		else:
			print("ParameterGroup: Group '%s' not found in path '%s'" % [part, path])
			return null
	
	# Get the parameter from the final group
	var param_name = parts[-1]
	if current_group.parameters.has(param_name):
		return current_group.parameters[param_name]
	else:
		print("ParameterGroup: Parameter '%s' not found in group '%s'" % [param_name, current_group.name])
		return null

## Get parameter value by path with default fallback
func get_param_value(path: String, default_value: Variant = null) -> Variant:
	var param = get_param(path)
	if param:
		return param.get_value()
	return default_value

## Get group by path (supports traversal)
func get_group(path: String):
	var parts = path.split("/")
	var current_group = self
	
	for part in parts:
		if part.is_empty():
			continue
		
		if current_group.groups.has(part):
			current_group = current_group.groups[part]
		else:
			return null
	
	return current_group

## Get the full path of this group
func get_path() -> String:
	if parent == null:
		return name if name != "root" else ""
	
	var parent_path = parent.get_path()
	if parent_path.is_empty():
		return name
	return parent_path + "/" + name

func _rebuild_cache() -> void:
	_param_cache.clear()
	_build_cache_recursive("", self)
	_cache_valid = true
	print("ParameterGroup: Cache rebuilt with %d parameters" % _param_cache.size())

func _build_cache_recursive(path_prefix: String, group: ParameterGroup) -> void:
	# Add parameters from this group
	for param_name in group.parameters.keys():
		var full_path = param_name if path_prefix.is_empty() else path_prefix + "/" + param_name
		_param_cache[full_path] = group.parameters[param_name]
		print("ParameterGroup: Cached parameter: %s" % full_path)
	
	# Recurse into sub-groups
	for group_name in group.groups.keys():
		var sub_group = group.groups[group_name]
		var group_path = group_name if path_prefix.is_empty() else path_prefix + "/" + group_name
		_build_cache_recursive(group_path, sub_group)

func _invalidate_cache() -> void:
	_cache_valid = false
	if parent:
		parent._invalidate_cache()

func get_stats() -> Dictionary:
	var total_params = parameters.size()
	var total_groups = groups.size()
	
	for group in groups.values():
		var sub_stats = group.get_stats()
		total_params += sub_stats.total_parameters
		total_groups += sub_stats.total_groups
	
	return {
		"total_parameters": total_params,
		"total_groups": total_groups
	}

func to_json() -> Array:
	var result = []
	
	# Convert this group to JSON
	var group_data = {
		"name": name,
		"description": description,
		"params": [],
		"groups": []
	}
	
	# Add parameters
	for parameter in parameters.values():
		group_data.params.append(parameter.to_json())
	
	# Add sub-groups
	for group in groups.values():
		var sub_group_array = group.to_json()
		group_data.groups.append_array(sub_group_array)
	
	result.append(group_data)
	return result

func from_json(data: Dictionary) -> bool:
	if not data.has("name"):
		return false
	
	name = data.name
	description = data.get("description", "")
	
	# Clear existing content
	parameters.clear()
	groups.clear()
	
	# Load parameters
	if data.has("params"):
		var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
		for param_data in data.params:
			var parameter = ParameterClass.new()
			if parameter.from_json(param_data):
				add_parameter(parameter)
	
	# Load sub-groups
	if data.has("groups"):
		for group_data in data.groups:
			var group = ParameterGroup.new()
			if group.from_json(group_data):
				add_group(group)
	
	return true
