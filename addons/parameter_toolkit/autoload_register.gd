# Copyright © 2024 Parameter Toolkit Contributors - MIT License

## Autoload registration script to ensure proper class loading order
extends Node

func _ready():
	# Verify that core classes are available
	if _verify_core_classes():
		print("ParameterToolkit: Core classes loaded successfully")
	else:
		push_error("ParameterToolkit: Failed to load core classes")

func _verify_core_classes() -> bool:
	# Check if Parameter class is available
	if not FileAccess.file_exists("res://addons/parameter_toolkit/core/parameter.gd"):
		push_error("ParameterToolkit: parameter.gd not found")
		return false
	
	# Check if ParameterGroup class is available
	if not FileAccess.file_exists("res://addons/parameter_toolkit/core/parameter_group.gd"):
		push_error("ParameterToolkit: parameter_group.gd not found")
		return false
	
	# Check if SettingsManager is available
	if not FileAccess.file_exists("res://addons/parameter_toolkit/core/settings_manager.gd"):
		push_error("ParameterToolkit: settings_manager.gd not found")
		return false
	
	return true
