# Copyright © 2024 Parameter Toolkit Contributors - MIT License
extends Node

## Central parameter management system and autoload.
##
## Manages parameter groups, persistence, and provides the main API for 
## parameter access and modification. Handles user/default preset loading
## and provides thread-safe parameter updates from external sources.

signal parameter_changed(path: String, value: Variant, source: String)
signal preset_loaded(preset_type: String)
signal preset_saved(preset_type: String)

## Core parameter tree
var root

## Threading support
var _update_queue: Array = []
var _queue_mutex: Mutex = Mutex.new()

## File paths
const DEFAULT_PRESET_PATH = "res://settings/default.json"
const USER_PRESET_PATH = "user://settings.json"

## Performance monitoring
var _performance_enabled: bool = false
var _load_time_ms: float = 0.0

func _init():
	var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
	root = ParameterGroupClass.new("root")

func _ready():
	print("ParameterToolkit: Initializing SettingsManager...")
	var start_time = Time.get_ticks_msec()
	
	# Load default preset first
	_load_default_preset()
	
	# Then merge user preset if it exists
	_load_user_preset()
	
	var end_time = Time.get_ticks_msec()
	_load_time_ms = end_time - start_time
	
	print("ParameterToolkit: Loaded %d parameters in %d ms" % [_count_parameters(), _load_time_ms])

func _process(_delta):
	_process_queued_updates()

## Get a parameter by path
func get_param(path: String):
	return root.get_param(path)

## Set a parameter value by path
func set_param(path: String, value: Variant, source: String = "internal") -> bool:
	var success = root.set_param(path, value)
	if success:
		parameter_changed.emit(path, value, source)
	return success

## Get a parameter value by path with optional default
func get_param_value(path: String, default_value: Variant = null) -> Variant:
	return root.get_param_value(path, default_value)

## Bind a callable to parameter changes
func bind(path: String, callable: Callable) -> bool:
	var parameter = get_param(path)
	if parameter:
		parameter.changed.connect(callable)
		# Call immediately with current value
		callable.call(parameter.get_value())
		return true
	
	push_warning("Cannot bind to parameter '%s': not found" % path)
	return false

## Queue a parameter update from external source (thread-safe)
func queue_parameter_update(path: String, value: Variant, source: String) -> void:
	_queue_mutex.lock()
	_update_queue.append({
		"path": path,
		"value": value,
		"source": source,
		"timestamp": Time.get_ticks_msec()
	})
	_queue_mutex.unlock()

## Save current state as user preset
func save_user_preset() -> bool:
	var user_dir = USER_PRESET_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(user_dir):
		DirAccess.open("user://").make_dir_recursive(user_dir.get_file())
	
	var file = FileAccess.open(USER_PRESET_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to create user preset file: %s" % USER_PRESET_PATH)
		return false
	
	var preset_data = {
		"version": 2,
		"metadata": {
			"created": Time.get_datetime_string_from_system(),
			"type": "user_preset"
		},
		"groups": [root.to_json()]
	}
	
	file.store_string(JSON.stringify(preset_data, "\t"))
	file.close()
	
	preset_saved.emit("user")
	print("ParameterToolkit: User preset saved to %s" % USER_PRESET_PATH)
	return true

## Load user preset
func load_user_preset() -> bool:
	return _load_user_preset()

## Reset to default preset (clear user overrides)
func reset_to_defaults() -> bool:
	# Delete user preset file
	if FileAccess.file_exists(USER_PRESET_PATH):
		DirAccess.remove_absolute(USER_PRESET_PATH)
	
	# Reload default preset
	if _load_default_preset():
		preset_loaded.emit("default")
		return true
	
	return false

## Get performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"load_time_ms": _load_time_ms,
		"parameter_count": _count_parameters(),
		"queue_size": _update_queue.size()
	}

## Enable/disable performance monitoring
func set_performance_monitoring(enabled: bool) -> void:
	_performance_enabled = enabled

# Private methods

func _process_queued_updates() -> void:
	if _update_queue.is_empty():
		return
	
	_queue_mutex.lock()
	var updates = _update_queue.duplicate()
	_update_queue.clear()
	_queue_mutex.unlock()
	
	for update in updates:
		set_param(update.path, update.value, update.source)

func _load_default_preset() -> bool:
	if not FileAccess.file_exists(DEFAULT_PRESET_PATH):
		push_warning("No default preset found at %s" % DEFAULT_PRESET_PATH)
		return _create_empty_preset()
	
	var file = FileAccess.open(DEFAULT_PRESET_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open default preset: %s" % DEFAULT_PRESET_PATH)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Failed to parse default preset JSON: %s" % json.error_string)
		return false
	
	var preset_data = json.data
	if not preset_data is Dictionary:
		push_error("Invalid default preset format")
		return false
	
	return _load_preset_data(preset_data)

func _load_user_preset() -> bool:
	if not FileAccess.file_exists(USER_PRESET_PATH):
		print("ParameterToolkit: No user preset found, using defaults only")
		return true
	
	var file = FileAccess.open(USER_PRESET_PATH, FileAccess.READ)
	if not file:
		push_warning("Failed to open user preset: %s" % USER_PRESET_PATH)
		return true  # Continue with defaults only
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_warning("Failed to parse user preset JSON, using defaults only: %s" % json.error_string)
		return true
	
	var preset_data = json.data
	if preset_data is Dictionary and preset_data.has("groups"):
		for group_data in preset_data.groups:
			root.merge_json(group_data, false)  # Don't create new parameters
		
		preset_loaded.emit("user")
		print("ParameterToolkit: User preset loaded from %s" % USER_PRESET_PATH)
	
	return true

func _load_preset_data(preset_data: Dictionary) -> bool:
	if not preset_data.has("groups"):
		push_error("Preset missing groups array")
		return false
	
	# Clear existing root
	var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
	root = ParameterGroupClass.new("root")
	
	# Load groups
	for group_data in preset_data.groups:
		var group = ParameterGroupClass.new()
		if group.from_json(group_data):
			root.add_group(group)
		else:
			push_error("Failed to load group from preset")
			return false
	
	return true

func _create_empty_preset() -> bool:
	var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
	root = ParameterGroupClass.new("root")
	print("ParameterToolkit: Created empty parameter tree")
	return true

func _count_parameters() -> int:
	var stats = root.get_stats()
	return stats.total_parameters

## Convenience methods for common use cases
func bind_float(path: String, callable: Callable) -> bool:
	return bind(path, callable)

func bind_int(path: String, callable: Callable) -> bool:
	return bind(path, callable)

func bind_bool(path: String, callable: Callable) -> bool:
	return bind(path, callable)

func bind_string(path: String, callable: Callable) -> bool:
	return bind(path, callable)

func bind_color(path: String, callable: Callable) -> bool:
	return bind(path, callable)
