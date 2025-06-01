# Copyright © 2024 Parameter Toolkit Contributors - MIT License

@tool
extends EditorPlugin

const AUTOLOAD_NAME = "SettingsManager"
const AUTOLOAD_PATH = "res://addons/parameter_toolkit/core/settings_manager.gd"

func _enter_tree():
	print("Parameter Toolkit: Plugin enabled")
	
	# Add the SettingsManager autoload
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		print("Parameter Toolkit: SettingsManager autoload added")
	else:
		print("Parameter Toolkit: SettingsManager autoload already exists")
	
	# Add editor dock
	var dock = preload("res://addons/parameter_toolkit/editor/parameter_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	print("Parameter Toolkit: Editor dock ready")

func _exit_tree():
	print("Parameter Toolkit: Plugin disabled")
	
	# Remove the autoload
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
		print("Parameter Toolkit: SettingsManager autoload removed")
	
	# Remove editor dock
	remove_control_from_docks(get_dock_control())

func get_dock_control():
	# Find and return the parameter dock control
	for dock_container in [DOCK_SLOT_LEFT_UR, DOCK_SLOT_LEFT_BR, DOCK_SLOT_RIGHT_UL, DOCK_SLOT_RIGHT_UR]:
		var dock = get_editor_interface().get_editor_main_screen().find_child("ParameterDock")
		if dock:
			return dock
	return null
