# Copyright © 2024 Parameter Toolkit Contributors - MIT License

extends Node

## Enhanced SettingsManager for Parameter Toolkit
##
## Central management system with security profiles, performance monitoring,
## and enhanced JSON persistence with schema versioning.

signal parameter_changed(path: String, value: Variant, source: String)
signal preset_loaded(preset_type: String)
signal preset_saved(preset_type: String)

## Core parameter tree
var root: ParameterGroup

## Threading support
var _update_queue: Array = []
var _queue_mutex: Mutex = Mutex.new()

## File paths
const DEFAULT_PRESET_PATH = "res://settings/default.json"
const USER_PRESET_PATH = "user://settings.json"

## Performance monitoring
var _performance_enabled: bool = false
var _load_time_ms: float = 0.0

## Enhanced properties for Week 2
var security_manager: SecurityManager
var performance_monitor: PerformanceMonitor
var schema_version: int = 2
var preset_metadata: Dictionary = {}

func _init():
	print("ParameterToolkit: Core classes loaded successfully")
	var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
	root = ParameterGroupClass.new("root")

func _ready():
	print("ParameterToolkit: Initializing enhanced SettingsManager...")
	
	var start_time = Time.get_ticks_msec()
	
	# Initialize security manager
	var SecurityManagerClass = load("res://addons/parameter_toolkit/core/security_manager.gd")
	security_manager = SecurityManagerClass.new()
	security_manager.profile_changed.connect(_on_security_profile_changed)
	
	# Initialize performance monitor
	var PerformanceMonitorClass = load("res://addons/parameter_toolkit/core/performance_monitor.gd")
	performance_monitor = PerformanceMonitorClass.new()
	performance_monitor.performance_alert.connect(_on_performance_alert)
	
	# Enable monitoring based on debug mode
	performance_monitor.set_enabled(OS.is_debug_build() or 
		ProjectSettings.get_setting("parameter_toolkit/monitoring/enabled", false))
	
	# Load default preset first
	_load_default_preset()
	
	# Then merge user preset if it exists
	_load_user_preset()
	
	var end_time = Time.get_ticks_msec()
	_load_time_ms = end_time - start_time
	
	print("ParameterToolkit: Enhanced SettingsManager ready with security profile: %s" % 
		  security_manager.get_profile_description())
	
	# Debug: Print initial parameter count
	print("ParameterToolkit: Loaded %d parameters in %d ms" % [_count_parameters(), _load_time_ms])

func _process(_delta):
	_process_queued_updates()

## Get a parameter by path
func get_param(path: String):
	var timer = performance_monitor.start_timing("parameter_lookup")
	var result = root.get_param(path)
	performance_monitor.end_timing(timer)
	
	if not result:
		print("SettingsManager: Parameter not found at path '%s'" % path)
		print("SettingsManager: Available paths:")
		_debug_available_paths()
	
	return result

func _debug_available_paths():
	var paths = []
	_collect_paths_recursive(root, "", paths)
	if paths.is_empty():
		print("  No parameters found")
	else:
		for path in paths:
			print("  - %s" % path)

func _collect_paths_recursive(group: ParameterGroup, prefix: String, paths: Array):
	# Collect parameters
	for param_name in group.parameters.keys():
		var full_path = param_name if prefix.is_empty() else prefix + "/" + param_name
		paths.append(full_path)
	
	# Recurse into sub-groups
	for group_name in group.groups.keys():
		var sub_group = group.groups[group_name]
		var new_prefix = group_name if prefix.is_empty() else prefix + "/" + group_name
		_collect_paths_recursive(sub_group, new_prefix, paths)

## Set a parameter value by path
func set_param(path: String, value: Variant, source: String = "internal") -> bool:
	var timer = performance_monitor.start_timing("parameter_update")
	
	# Security validation for external sources
	if source != "internal":
		var context = {"source": source, "authenticated": false}  # TODO: Add authentication
		if not security_manager.validate_action(source, "parameter_modification", context):
			performance_monitor.end_timing(timer)
			return false
	
	var param = get_param(path)
	if param:
		var old_value = param.get_value()
		var success = param.set_value(value)
		
		if success:
			parameter_changed.emit(path, value, source)
			print("ParameterToolkit: Parameter updated - %s: %s → %s (source: %s)" % 
				  [path, old_value, value, source])
		
		performance_monitor.end_timing(timer)
		return success
	
	performance_monitor.end_timing(timer)
	return false

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
	var timer = performance_monitor.start_timing("preset_save")
	var success = false
	
	# Ensure user directory exists
	if not DirAccess.dir_exists_absolute(USER_PRESET_PATH.get_base_dir()):
		DirAccess.open("user://").make_dir_recursive(USER_PRESET_PATH.get_base_dir())
	
	var user_file = FileAccess.open(USER_PRESET_PATH, FileAccess.WRITE)
	if user_file:
		var preset_data = {
			"$schema": "https://parametertoolkit.org/schema/v2.json",
			"version": schema_version,
			"metadata": {
				"created": preset_metadata.get("created", Time.get_datetime_string_from_system()),
				"modified": Time.get_datetime_string_from_system(),
				"generated_by": "Parameter Toolkit v1.0.0",
				"security_profile": SecurityManager.Profile.keys()[security_manager.current_profile]
			},
			"groups": root.to_json()
		}
		
		var json_string = JSON.stringify(preset_data, "\t")
		user_file.store_string(json_string)
		user_file.close()
		success = true
		
		print("ParameterToolkit: User preset saved with metadata")
	
	performance_monitor.end_timing(timer)
	return success

## Load user preset
func load_user_preset() -> bool:
	var timer = performance_monitor.start_timing("preset_load")
	var success = false
	
	var user_file = FileAccess.open(USER_PRESET_PATH, FileAccess.READ)
	if user_file:
		var json_text = user_file.get_as_text()
		user_file.close()
		
		var json_parser = JSON.new()
		var parse_result = json_parser.parse(json_text)
		
		if parse_result == OK:
			var data = json_parser.data
			
			# Handle schema migration
			data = _migrate_schema(data)
			
			# Store metadata
			preset_metadata = data.get("metadata", {})
			
			# Apply user preset
			if data.has("groups"):
				_apply_preset_data(data.groups)
				success = true
				print("ParameterToolkit: User preset loaded (schema v%d)" % 
					  data.get("version", 1))
		else:
			print("ParameterToolkit: Failed to parse user preset JSON")
	
	performance_monitor.end_timing(timer)
	return success

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
	var base_stats = {
		"parameter_count": _get_total_parameter_count(),
		"group_count": _get_total_group_count(),
		"queue_size": _update_queue.size(),
		"schema_version": schema_version,
		"security_profile": SecurityManager.Profile.keys()[security_manager.current_profile],
		"preset_metadata": preset_metadata
	}
	
	# Add performance monitoring stats
	if performance_monitor:
		base_stats.merge(performance_monitor.get_simple_stats())
	
	return base_stats

## Get detailed performance report
func get_detailed_performance_report() -> Dictionary:
	if performance_monitor:
		return performance_monitor.get_performance_report()
	return {"error": "Performance monitoring disabled"}

## Security profile management
func configure_for_isolated_network() -> void:
	security_manager.enable_isolated_network_mode()

func configure_for_development() -> void:
	security_manager.enable_development_mode()

func configure_for_production() -> void:
	security_manager.enable_production_mode()

func get_security_status() -> Dictionary:
	return {
		"current_profile": SecurityManager.Profile.keys()[security_manager.current_profile],
		"description": security_manager.get_profile_description(),
		"config": security_manager.get_current_config()
	}

## Enhanced validation for all parameters
func validate_all_parameters() -> Array[String]:
	var timer = performance_monitor.start_timing("validation_check")
	var errors = []
	
	_validate_group_recursive(root, errors)
	
	performance_monitor.end_timing(timer)
	return errors

func _validate_group_recursive(group, errors: Array) -> void:
	# Validate parameters in this group
	for param_name in group.parameters.keys():
		var param = group.parameters[param_name]
		var param_errors = param.get_validation_errors()
		for error in param_errors:
			errors.append("%s/%s: %s" % [group.get_path(), param_name, error])
	
	# Recurse into sub-groups
	for sub_group in group.groups.values():
		_validate_group_recursive(sub_group, errors)

## Signal handlers for monitoring
func _on_security_profile_changed(new_profile: SecurityManager.Profile) -> void:
	print("ParameterToolkit: Security profile changed to %s" % 
		  SecurityManager.Profile.keys()[new_profile])

func _on_performance_alert(metric: String, current_value: float, threshold: float) -> void:
	print("ParameterToolkit: Performance alert - %s: %.2f > %.2f" % 
		  [metric, current_value, threshold])

## Private methods

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
	var timer = performance_monitor.start_timing("preset_load")
	var success = false
	
	var user_file = FileAccess.open(USER_PRESET_PATH, FileAccess.READ)
	if user_file:
		var json_text = user_file.get_as_text()
		user_file.close()
		
		var json_parser = JSON.new()
		var parse_result = json_parser.parse(json_text)
		
		if parse_result == OK:
			var data = json_parser.data
			
			# Handle schema migration
			data = _migrate_schema(data)
			
			# Store metadata
			preset_metadata = data.get("metadata", {})
			
			# Apply user preset
			if data.has("groups"):
				_apply_preset_data(data.groups)
				success = true
				print("ParameterToolkit: User preset loaded (schema v%d)" % 
					  data.get("version", 1))
		else:
			print("ParameterToolkit: Failed to parse user preset JSON")
	
	performance_monitor.end_timing(timer)
	return success

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

## Schema migration system
func _migrate_schema(data: Dictionary) -> Dictionary:
	var version = data.get("version", 1)
	
	if version == schema_version:
		return data  # No migration needed
	
	print("ParameterToolkit: Migrating schema from v%d to v%d" % [version, schema_version])
	
	# Migration chain
	if version == 1:
		data = _migrate_v1_to_v2(data)
		version = 2
	
	# Future migrations would go here
	# if version == 2:
	#     data = _migrate_v2_to_v3(data)
	#     version = 3
	
	data["version"] = schema_version
	return data

## Migrate from schema v1 to v2
func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	print("ParameterToolkit: Migrating v1 → v2 schema")
	
	# Add metadata section
	if not data.has("metadata"):
		data["metadata"] = {
			"created": Time.get_datetime_string_from_system(),
			"modified": Time.get_datetime_string_from_system(),
			"migrated_from_version": 1
		}
	
	# Convert old validation format if present
	if data.has("groups"):
		_migrate_validation_format(data.groups)
	
	return data

## Migrate validation format in groups
func _migrate_validation_format(groups: Array) -> void:
	for group_data in groups:
		if group_data.has("params"):
			for param_data in group_data.params:
				# Convert old validation format to new format
				if param_data.has("validators") and not param_data.has("validation"):
					param_data["validation"] = {
						"rules": param_data.validators,
						"custom_validator": ""
					}
					param_data.erase("validators")
		
		# Recurse into sub-groups
		if group_data.has("groups"):
			_migrate_validation_format(group_data.groups)

func _get_total_parameter_count() -> int:
	return _count_parameters_recursive(root)

func _count_parameters_recursive(group) -> int:
	var count = group.parameters.size()
	for sub_group in group.groups.values():
		count += _count_parameters_recursive(sub_group)
	return count

func _get_total_group_count() -> int:
	return _count_groups_recursive(root) - 1  # Don't count root

func _count_groups_recursive(group) -> int:
	var count = 1  # Count this group
	for sub_group in group.groups.values():
		count += _count_groups_recursive(sub_group)
	return count

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

## Apply preset data to existing parameters
func _apply_preset_data(groups_data: Array) -> void:
	for group_data in groups_data:
		_apply_group_data(root, group_data)

## Apply group data recursively
func _apply_group_data(parent_group, group_data: Dictionary) -> void:
	var group_name = group_data.get("name", "")
	var target_group = parent_group.get_group_by_name(group_name)
	
	if not target_group:
		# Create the group if it doesn't exist
		var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
		target_group = ParameterGroupClass.new(group_name)
		parent_group.add_group(target_group)
	
	# Apply parameters
	if group_data.has("params"):
		for param_data in group_data.params:
			_apply_parameter_data(target_group, param_data)
	
	# Apply sub-groups
	if group_data.has("groups"):
		for sub_group_data in group_data.groups:
			_apply_group_data(target_group, sub_group_data)

## Apply parameter data to a group
func _apply_parameter_data(group, param_data: Dictionary) -> void:
	var param_name = param_data.get("name", "")
	var param = group.get_parameter_by_name(param_name)
	
	if not param:
		# Create the parameter if it doesn't exist
		var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
		param = ParameterClass.new(param_name, param_data.get("type", "float"))
		group.add_parameter(param)
	
	# Set parameter properties from data
	if param_data.has("value"):
		param.set_value(param_data.value)
	if param_data.has("min"):
		param.min_value = param_data.min
	if param_data.has("max"):
		param.max_value = param_data.max
	if param_data.has("step"):
		param.step = param_data.step
	if param_data.has("description"):
		param.description = param_data.description
