# Copyright © 2024 Parameter Toolkit Contributors - MIT License
extends Control

## Demo scene for Parameter Toolkit
##
## Shows basic usage and functionality.

@onready var status_label: Label = $CenterContainer/VBoxContainer/Status

func _ready():
	print("Parameter Toolkit Demo: Starting...")
	
	# Wait for SettingsManager to be ready
	await get_tree().process_frame
	
	if SettingsManager:
		status_label.text = "SettingsManager loaded successfully!"
		_setup_demo_parameters()
		_run_basic_tests()
	else:
		status_label.text = "SettingsManager not found"

func _setup_demo_parameters():
	print("Parameter Toolkit Demo: Setting up demo parameters...")
	
	# Create a simple demo parameter
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var demo_param = ParameterClass.new("demo_brightness", "float")
	demo_param.set_value(0.8)
	demo_param.description = "Demo brightness parameter"
	
	# Add to settings manager
	SettingsManager.root.add_parameter(demo_param)
	
	# Bind to the parameter
	SettingsManager.bind("demo_brightness", _on_brightness_changed)
	
	print("Parameter Toolkit Demo: Demo parameters ready")

func _run_basic_tests():
	print("\nParameter Toolkit Demo: Running basic functionality tests...")
	
	# Test parameter creation and value setting
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var test_param = ParameterClass.new("test_volume", "float")
	test_param.set_value(0.5)
	
	var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
	var test_group = ParameterGroupClass.new("audio")
	test_group.add_parameter(test_param)
	
	SettingsManager.root.add_group(test_group)
	
	# Test path-based access
	var retrieved_param = SettingsManager.get_param("audio/test_volume")
	if retrieved_param and retrieved_param.get_value() == 0.5:
		print("✅ Path-based parameter access working")
		status_label.text += "\n✅ Core functionality verified"
	else:
		print("❌ Path-based parameter access failed")
		status_label.text += "\n❌ Core functionality issues detected"

func _on_brightness_changed(value: float):
	print("Brightness changed to: ", value)
	modulate.a = value

func _input(event):
	# Press T to run comprehensive tests
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_run_comprehensive_tests()

func _run_comprehensive_tests():
	print("\nParameter Toolkit Demo: Running comprehensive tests...")
	var TestRunner = load("res://tests/test_runner.gd")
	var success = TestRunner.run_tests()
	
	if success:
		status_label.text += "\n🎉 All tests passed!"
	else:
		status_label.text += "\n❌ Some tests failed - check console"
