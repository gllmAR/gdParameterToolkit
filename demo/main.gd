extends Control

@onready var label: Label = $VBoxContainer/Label
@onready var color_rect: ColorRect = $VBoxContainer/ColorRect

func _ready():
	# Bind to parameter changes
	if SettingsManager:
		SettingsManager.bind("visual/brightness", _on_brightness_changed)
		SettingsManager.bind("visual/color", _on_color_changed)
		SettingsManager.bind("game/title", _on_title_changed)

func _on_brightness_changed(value: float):
	if color_rect:
		color_rect.modulate = Color.WHITE * value

func _on_color_changed(value: Color):
	if color_rect:
		color_rect.color = value

func _on_title_changed(value: String):
	if label:
		label.text = value
