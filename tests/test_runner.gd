# Copyright © 2024 Parameter Toolkit Contributors - MIT License
extends Node

## Simple test runner for Parameter Toolkit
##
## This runs in the DEVELOPMENT project (root folder).
## For the demo/example, see demo/parameter_toolkit_demo/

func _ready():
	print("=== Parameter Toolkit Test Runner ===")
	print("Running in DEVELOPMENT mode")
	print("For demo/examples, use: demo/parameter_toolkit_demo/")
	print()
	
	# Check if addon is properly loaded
	if not _check_addon_loaded():
		print("ERROR: Addon not properly loaded. Enable it in Project Settings > Plugins")
		return
	
	run_all_tests()

func _check_addon_loaded() -> bool:
	# Check if SettingsManager autoload exists
	if not has_node("/root/SettingsManager"):
		print("SettingsManager autoload not found")
		return false
	
	# Try to load core classes
	var parameter_class = load("res://addons/parameter_toolkit/core/parameter.gd")
	if not parameter_class:
		print("Parameter class not found")
		return false
		
	print("✓ Addon appears to be loaded correctly")
	return true

func run_all_tests():
	print("=".repeat(60))
	print("Parameter Toolkit - Core Functionality Tests")
	print("=".repeat(60))
	
	var test_results = []
	
	# Run individual test modules
	test_results.append(_run_parameter_tests())
	test_results.append(_run_parameter_group_tests())
	test_results.append(_run_settings_manager_tests())
	
	# Print summary
	var passed = 0
	var failed = 0
	
	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1
	
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)
	print("Total:  %d" % test_results.size())
	
	if failed == 0:
		print("🎉 ALL TESTS PASSED! Parameter Toolkit is working correctly.")
	else:
		print("❌ Some tests failed. Check the output above for details.")
	
	print("=".repeat(60))
	
	return failed == 0

func _run_parameter_tests() -> Dictionary:
	print("\n📋 Running Parameter Tests...")
	
	var test_file = load("res://tests/unit/test_parameter.gd")
	if not test_file:
		print("❌ Could not load parameter test file")
		return {"name": "Parameter", "passed": false}
	
	var test_instance = test_file.new()
	if not test_instance:
		print("❌ Could not create parameter test instance")
		return {"name": "Parameter", "passed": false}
	
	if not test_instance.has_method("run_tests"):
		print("❌ Parameter test file missing run_tests method")
		return {"name": "Parameter", "passed": false}
	
	test_instance.run_tests()
	print("✅ Parameter tests completed successfully")
	return {"name": "Parameter", "passed": true}

func _run_parameter_group_tests() -> Dictionary:
	print("\n📋 Running ParameterGroup Tests...")
	
	var test_file = load("res://tests/unit/test_parameter_group.gd")
	if not test_file:
		print("❌ Could not load parameter group test file")
		return {"name": "ParameterGroup", "passed": false}
	
	var test_instance = test_file.new()
	if not test_instance:
		print("❌ Could not create parameter group test instance")
		return {"name": "ParameterGroup", "passed": false}
	
	if not test_instance.has_method("run_tests"):
		print("❌ ParameterGroup test file missing run_tests method")
		return {"name": "ParameterGroup", "passed": false}
	
	test_instance.run_tests()
	print("✅ ParameterGroup tests completed successfully")
	return {"name": "ParameterGroup", "passed": true}

func _run_settings_manager_tests() -> Dictionary:
	print("\n📋 Running SettingsManager Tests...")
	
	var test_file = load("res://tests/unit/test_settings_manager.gd")
	if not test_file:
		print("❌ Could not load settings manager test file")
		return {"name": "SettingsManager", "passed": false}
	
	var test_instance = test_file.new()
	if not test_instance:
		print("❌ Could not create settings manager test instance")
		return {"name": "SettingsManager", "passed": false}
	
	if not test_instance.has_method("run_tests"):
		print("❌ SettingsManager test file missing run_tests method")
		return {"name": "SettingsManager", "passed": false}
	
	test_instance.run_tests()
	print("✅ SettingsManager tests completed successfully")
	return {"name": "SettingsManager", "passed": true}

## Static method to run tests from command line or autoload
static func run_tests():
	var runner = load("res://tests/test_runner.gd").new()
	return runner.run_all_tests()
