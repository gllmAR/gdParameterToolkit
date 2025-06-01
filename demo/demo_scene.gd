extends Control

# Demo scene for Parameter Toolkit

func _ready():
	print("Parameter Toolkit Demo: Starting...")
	
	# Wait a frame for autoloads to initialize
	await get_tree().process_frame
	
	# Check if SettingsManager is available
	if not _check_settings_manager():
		print("❌ Parameter Toolkit Demo: SettingsManager not available")
		return
	
	_setup_demo_parameters()
	_test_basic_functionality()

func _check_settings_manager() -> bool:
	if not has_node("/root/SettingsManager"):
		print("❌ SettingsManager autoload not found")
		return false
	
	var settings_manager = get_node("/root/SettingsManager")
	if not settings_manager:
		print("❌ SettingsManager node is null")
		return false
	
	if not settings_manager.has_method("get_param"):
		print("❌ SettingsManager missing required methods")
		return false
	
	print("✅ SettingsManager is available and ready")
	return true

func _setup_demo_parameters():
	print("Parameter Toolkit Demo: Setting up demo parameters...")
	
	var settings_manager = get_node("/root/SettingsManager")
	
	# Create visual group
	var ParameterGroupClass = load("res://addons/parameter_toolkit/core/parameter_group.gd")
	var visual_group = ParameterGroupClass.new("visual")
	settings_manager.root.add_group(visual_group)
	
	# Create brightness parameter
	var ParameterClass = load("res://addons/parameter_toolkit/core/parameter.gd")
	var brightness_param = ParameterClass.new("brightness", "float")
	brightness_param.min_value = 0.0
	brightness_param.max_value = 2.0
	brightness_param.set_value(0.8)
	visual_group.add_parameter(brightness_param)
	
	# Bind to brightness changes
	var success = settings_manager.bind("visual/brightness", _on_brightness_changed)
	if success:
		print("Parameter Toolkit Demo: Successfully bound to brightness parameter")
	else:
		print("❌ Parameter Toolkit Demo: Failed to bind to brightness parameter")
	
	print("Parameter Toolkit Demo: Demo parameters ready")

func _test_basic_functionality():
	print("Parameter Toolkit Demo: Running basic functionality tests...")
	
	var settings_manager = get_node("/root/SettingsManager")
	
	# Test 1: Path-based parameter access
	var brightness_param = settings_manager.get_param("visual/brightness")
	if brightness_param:
		print("✅ Path-based parameter access working")
		print("  Current brightness: %s" % brightness_param.get_value())
	else:
		print("❌ Path-based parameter access failed")
		_debug_parameter_structure()
	
	# Test 2: Parameter modification
	var success = settings_manager.set_param("visual/brightness", 0.9)
	if success:
		print("✅ Parameter modification working")
	else:
		print("❌ Parameter modification failed")
	
	# Test 3: Settings saving/loading
	success = settings_manager.save_user_preset()
	if success:
		print("✅ Preset saving working")
	else:
		print("❌ Preset saving failed")

func _debug_parameter_structure():
	var settings_manager = get_node("/root/SettingsManager")
	print("Debug: Parameter structure:")
	print("  Root name: %s" % settings_manager.root.name)
	print("  Root groups: %s" % settings_manager.root.groups.keys())
	print("  Root parameters: %s" % settings_manager.root.parameters.keys())
	
	if settings_manager.root.groups.has("visual"):
		var visual = settings_manager.root.groups["visual"]
		print("  Visual group name: %s" % visual.name)
		print("  Visual parameters: %s" % visual.parameters.keys())
	else:
		print("  Visual group not found!")

func _on_brightness_changed(value: float):
	print("Brightness changed to: %s" % value)
	# Update the actual visual brightness here
	modulate = Color(value, value, value)
