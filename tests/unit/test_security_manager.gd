# Copyright © 2024 Parameter Toolkit Contributors - MIT License

extends RefCounted

## Unit tests for SecurityManager

var SecurityManagerClass = preload("res://addons/parameter_toolkit/core/security_manager.gd")

func test_security_profile_creation():
	var security_manager = SecurityManagerClass.new()
	assert_not_null(security_manager)
	
	# Test that profiles are properly initialized
	for profile in SecurityManagerClass.Profile.values():
		var config = security_manager.get_profile_config(profile)
		assert_true(config.has("web_bind_address"))
		assert_true(config.has("osc_whitelist"))
		assert_true(config.has("description"))
	
	print("✓ Security profile creation test passed")

func test_profile_switching():
	var security_manager = SecurityManagerClass.new()
	
	# Test switching to isolated mode
	security_manager.enable_isolated_network_mode()
	assert_eq(security_manager.current_profile, SecurityManagerClass.Profile.ISOLATED)
	
	# Test switching to development mode
	security_manager.enable_development_mode()
	assert_eq(security_manager.current_profile, SecurityManagerClass.Profile.DEVELOPMENT)
	
	# Test switching to production mode
	security_manager.enable_production_mode()
	assert_eq(security_manager.current_profile, SecurityManagerClass.Profile.PRODUCTION)
	
	print("✓ Security profile switching test passed")

func test_access_validation():
	var security_manager = SecurityManagerClass.new()
	
	# Test isolated mode - should allow everything
	security_manager.enable_isolated_network_mode()
	assert_true(security_manager.validate_action("test", "parameter_modification"))
	
	# Test production mode - should require authentication
	security_manager.enable_production_mode()
	assert_false(security_manager.validate_action("test", "parameter_modification", {"authenticated": false}))
	assert_true(security_manager.validate_action("test", "parameter_modification", {"authenticated": true}))
	
	print("✓ Security access validation test passed")

func test_ip_validation():
	var security_manager = SecurityManagerClass.new()
	
	# Test development mode - localhost only
	security_manager.enable_development_mode()
	assert_true(security_manager._is_ip_allowed_osc("127.0.0.1"))
	assert_false(security_manager._is_ip_allowed_osc("192.168.1.100"))
	
	print("✓ IP validation test passed")

func run_tests():
	print("Running SecurityManager tests...")
	test_security_profile_creation()
	test_profile_switching()
	test_access_validation()
	test_ip_validation()
	print("All SecurityManager tests completed!")

# Helper functions
func assert_eq(actual, expected):
	if actual != expected:
		push_error("Assertion failed: expected %s, got %s" % [expected, actual])

func assert_true(value):
	if not value:
		push_error("Assertion failed: expected true, got %s" % value)

func assert_false(value):
	if value:
		push_error("Assertion failed: expected false, got %s" % value)

func assert_not_null(value):
	if value == null:
		push_error("Assertion failed: expected non-null value")
