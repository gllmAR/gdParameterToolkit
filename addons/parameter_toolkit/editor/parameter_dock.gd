# Copyright © 2024 Parameter Toolkit Contributors - MIT License
@tool
extends Control

## Editor dock for Parameter Toolkit
##
## Provides UI for creating and managing parameters in the editor.

@onready var parameter_list: VBoxContainer = $VBoxContainer/ScrollContainer/ParameterList

func _ready():
	print("Parameter Toolkit: Editor dock ready")
	_refresh_parameter_list()

func _refresh_parameter_list():
	# Clear existing items
	for child in parameter_list.get_children():
		child.queue_free()
	
	# Add placeholder text
	var placeholder = Label.new()
	placeholder.text = "Parameter management coming soon..."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parameter_list.add_child(placeholder)
