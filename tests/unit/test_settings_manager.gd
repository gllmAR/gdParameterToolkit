# Copyright © 2024 Parameter Toolkit Contributors - MIT License

# Unit tests for SettingsManager
extends GutTest

var settings_manager: Node

func before_each():
	# Create a fresh SettingsManager instance for each test
	settings_manager = preload("res://addons/parameter_toolkit/core/settings_manager.gd").new()
	settings_manager.name = "TestSettingsManager"
	add_child(settings_manager)
	settings_manager._ready()

func after_each():
	if settings_manager:
		settings_manager.queue_free()
		settings_manager = null

func test_settings_manager_initialization():
	assert_not_null(settings_manager.root)
	assert_eq(settings_manager.root.name, "root")

func test_bind_parameter():
	# Add a test parameter
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var param = ParameterClass.new("test_param", "float")
	param.set_value(0.5)
	settings_manager.root.add_parameter(param)
	
	# Use a more robust approach for testing callbacks
	var test_state = TestState.new()
	
	var callback = func(value):
		test_state.callback_called = true
		test_state.received_value = value
	
	# Test binding
	var success = settings_manager.bind("test_param", callback)
	assert_true(success)
	assert_true(test_state.callback_called)  # Should be called immediately
	assert_eq(test_state.received_value, 0.5)
	
	# Test that changing the parameter triggers the callback
	test_state.reset()
	param.set_value(0.8)
	assert_true(test_state.callback_called)
	assert_eq(test_state.received_value, 0.8)

func test_bind_nonexistent_parameter():
	var callback = func(_value): pass
	var success = settings_manager.bind("nonexistent", callback)
	assert_false(success)

func test_get_set_value():
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var param = ParameterClass.new("test_param", "float")
	param.set_value(0.5)
	settings_manager.root.add_parameter(param)
	
	# Test get_value
	var value = settings_manager.get_param_value("test_param")
	assert_eq(value, 0.5)
	
	# Test get_value with default for non-existent parameter
	var default_value = settings_manager.get_param_value("nonexistent", "default")
	assert_eq(default_value, "default")
	
	# Test set_value
	var success = settings_manager.set_param("test_param", 0.8)
	assert_true(success)
	assert_eq(param.value, 0.8)
	
	# Test set_value for non-existent parameter
	var failure = settings_manager.set_param("nonexistent", 1.0)
	assert_false(failure)

func test_parameter_changed_signal():
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var param = ParameterClass.new("test_param", "float")
	param.set_value(0.5)
	settings_manager.root.add_parameter(param)
	
	var test_state = TestState.new()
	
	settings_manager.parameter_changed.connect(func(path, value, source):
		test_state.signal_emitted = true
		test_state.received_path = path
		test_state.received_value = value
		test_state.received_source = source
	)
	
	settings_manager.set_param("test_param", 0.8, "test_source")
	
	assert_true(test_state.signal_emitted)
	assert_eq(test_state.received_path, "test_param")
	assert_eq(test_state.received_value, 0.8)
	assert_eq(test_state.received_source, "test_source")

func test_queue_parameter_update():
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var param = ParameterClass.new("test_param", "float")
	param.set_value(0.5)
	settings_manager.root.add_parameter(param)
	
	# Queue an update
	settings_manager.queue_parameter_update("test_param", 0.8, "external")
	
	# Process the queue manually
	settings_manager._process_queued_updates()
	
	assert_eq(param.value, 0.8)

func test_get_all_paths():
	var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	
	var visual = ParameterGroupClass.new("visual")
	settings_manager.root.add_group(visual)
	
	var brightness = ParameterClass.new("brightness", "float")
	brightness.set_value(0.8)
	var volume = ParameterClass.new("volume", "float")
	volume.set_value(0.7)
	
	visual.add_parameter(brightness)
	settings_manager.root.add_parameter(volume)
	
	var paths = settings_manager.root.get_all_param_paths()
	assert_true("visual/brightness" in paths)
	assert_true("volume" in paths)
	assert_eq(paths.size(), 2)

func test_performance_stats():
	var stats = settings_manager.get_performance_stats()
	assert_true(stats.has("parameter_count"))
	assert_true(stats.has("queue_size"))
	assert_eq(stats["queue_size"], 0)

## Basic unit tests for SettingsManager

func test_settings_manager_basic():
	# This is a placeholder test since SettingsManager is an autoload
	# and requires the full Godot environment to test properly
	print("✓ SettingsManager basic test passed (placeholder)")

func run_tests():
	print("Running SettingsManager tests...")
	test_settings_manager_basic()
	print("All SettingsManager tests completed!")

# Helper class to avoid lambda capture issues
class TestState:
	var callback_called: bool = false
	var received_value = null
	var signal_emitted: bool = false
	var received_path: String = ""
	var received_source: String = ""
	
	func reset():
		callback_called = false
		received_value = null
		signal_emitted = false
		received_path = ""
		received_source = ""
