# Copyright © 2024 Parameter Toolkit Contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
#
# This script is needed to make the `class_name` scripts visible in the
# Create New Node dialog once the plugin is enabled.
@tool
extends EditorPlugin

func _enter_tree():
	# Add the custom dock to the left dock
	add_control_to_dock(DOCK_SLOT_LEFT_UR, preload("res://addons/parameter_toolkit/editor/parameter_dock.tscn").instantiate())

func _exit_tree():
	# Remove the dock when disabling the plugin
	remove_control_from_docks(preload("res://addons/parameter_toolkit/editor/parameter_dock.tscn").instantiate())
