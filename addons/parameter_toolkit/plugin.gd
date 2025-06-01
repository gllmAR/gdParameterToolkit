# Copyright © 2024 Parameter Toolkit Contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends EditorPlugin

const SETTINGS_MANAGER_PATH = "res://addons/parameter_toolkit/core/settings_manager.gd"
const DOCK_SCENE_PATH = "res://addons/parameter_toolkit/editor/parameter_dock.tscn"

var dock_instance = null

func _enter_tree():
	# Add the autoload for SettingsManager
	add_autoload_singleton("SettingsManager", SETTINGS_MANAGER_PATH)
	print("Parameter Toolkit: Plugin enabled")

	# Create and add the dock
	if FileAccess.file_exists(DOCK_SCENE_PATH):
		var dock_scene = load(DOCK_SCENE_PATH)
		if dock_scene:
			dock_instance = dock_scene.instantiate()
			add_control_to_dock(DOCK_SLOT_LEFT_UR, dock_instance)
	else:
		print("Parameter Toolkit: Dock scene not found, editor functionality limited")

func _exit_tree():
	# Remove autoload
	remove_autoload_singleton("SettingsManager")
	print("Parameter Toolkit: Plugin disabled")
	
	# Remove dock
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance = null
