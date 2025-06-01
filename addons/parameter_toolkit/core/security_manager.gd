# Copyright © 2024 Parameter Toolkit Contributors - MIT License

## Security Manager for Parameter Toolkit
##
## Provides adaptive security profiles that balance usability with protection
## based on deployment context (isolated networks, development, production).

class_name SecurityManager extends RefCounted

## Security profile levels
enum Profile {
	ISOLATED,    ## No authentication, LAN access (art installations, kiosks)
	DEVELOPMENT, ## Localhost only, optional PIN (local development)
	PRODUCTION   ## Full authentication, restricted access (public deployment)
}

## Current active security profile
var current_profile: Profile = Profile.DEVELOPMENT

## Security configuration for each profile
var _profile_configs: Dictionary = {}

## Network interface detection cache
var _network_interfaces_cache: Array = []
var _internet_connectivity_cache: bool = false
var _cache_timeout: float = 30.0  # seconds
var _last_network_check: float = 0.0

signal profile_changed(new_profile: Profile)
signal security_violation(source: String, violation: String)

func _init():
	_setup_profile_configs()
	current_profile = _detect_appropriate_profile()
	print("SecurityManager: Initialized with profile: ", Profile.keys()[current_profile])

## Configure security settings for each profile
func _setup_profile_configs():
	_profile_configs[Profile.ISOLATED] = {
		"web_bind_address": "0.0.0.0",
		"web_pin_required": false,
		"web_session_timeout": 0,  # No timeout
		"osc_whitelist": [],  # Accept from any IP
		"osc_require_secret": false,
		"osc_rate_limit": 0,  # No rate limiting
		"audit_logging": false,
		"description": "Isolated network mode - minimal security for closed networks"
	}
	
	_profile_configs[Profile.DEVELOPMENT] = {
		"web_bind_address": "127.0.0.1",
		"web_pin_required": false,
		"web_session_timeout": 7200,  # 2 hours
		"osc_whitelist": ["127.0.0.1", "::1"],  # Localhost only
		"osc_require_secret": false,
		"osc_rate_limit": 100,  # 100 requests per minute
		"audit_logging": true,
		"description": "Development mode - localhost access with basic protection"
	}
	
	_profile_configs[Profile.PRODUCTION] = {
		"web_bind_address": "127.0.0.1",
		"web_pin_required": true,
		"web_session_timeout": 3600,  # 1 hour
		"osc_whitelist": [],  # Must be explicitly configured
		"osc_require_secret": true,
		"osc_rate_limit": 10,  # 10 requests per minute
		"audit_logging": true,
		"description": "Production mode - full security with authentication"
	}

## Detect appropriate security profile based on environment
func _detect_appropriate_profile() -> Profile:
	# Check for explicit configuration first
	var configured_profile = ProjectSettings.get_setting("parameter_toolkit/security/profile", "")
	if configured_profile != "":
		match configured_profile.to_lower():
			"isolated":
				return Profile.ISOLATED
			"development":
				return Profile.DEVELOPMENT
			"production":
				return Profile.PRODUCTION
	
	# Check for isolated network mode setting
	if ProjectSettings.get_setting("parameter_toolkit/security/isolated_network_mode", false):
		return Profile.ISOLATED
	
	# Automatic detection based on environment
	if OS.is_debug_build():
		return Profile.DEVELOPMENT
	
	# Check network configuration (cached)
	var current_time = Time.get_time_dict_from_system()
	var time_since_check = current_time.hour * 3600 + current_time.minute * 60 + current_time.second - _last_network_check
	
	if time_since_check > _cache_timeout:
		_update_network_cache()
	
	if not _internet_connectivity_cache and _is_private_network_only():
		return Profile.ISOLATED
	
	return Profile.PRODUCTION

## Update network interface and connectivity cache
func _update_network_cache():
	_network_interfaces_cache = IP.get_local_interfaces()
	_internet_connectivity_cache = _check_internet_connectivity()
	_last_network_check = Time.get_time_dict_from_system().hour * 3600 + \
						 Time.get_time_dict_from_system().minute * 60 + \
						 Time.get_time_dict_from_system().second

## Check if system has internet connectivity
func _check_internet_connectivity() -> bool:
	# Simple connectivity check (can be overridden for more sophisticated detection)
	var http_request = HTTPRequest.new()
	# In a real implementation, this would be an async check
	# For now, we'll use a simpler heuristic
	return true  # Assume connectivity unless proven otherwise

## Check if only private network interfaces are available
func _is_private_network_only() -> bool:
	for interface in _network_interfaces_cache:
		for address in interface.addresses:
			if _is_public_ip(address):
				return false
	return true

## Check if an IP address is public (not private/local)
func _is_public_ip(ip: String) -> bool:
	# RFC 1918 private ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
	# IPv6 private: fc00::/7, fe80::/10
	# Localhost: 127.0.0.0/8, ::1
	
	if ip.begins_with("10.") or ip.begins_with("192.168.") or ip.begins_with("127."):
		return false
	
	if ip.begins_with("172."):
		var octets = ip.split(".")
		if octets.size() >= 2:
			var second_octet = octets[1].to_int()
			if second_octet >= 16 and second_octet <= 31:
				return false
	
	if ip.begins_with("fc") or ip.begins_with("fe80") or ip == "::1":
		return false
	
	return true

## Apply a security profile
func apply_profile(profile: Profile) -> void:
	if current_profile == profile:
		return
	
	var old_profile = current_profile
	current_profile = profile
	
	var config = _profile_configs[profile]
	
	# Apply web settings
	ProjectSettings.set_setting("parameter_toolkit/web/bind_address", config.web_bind_address)
	ProjectSettings.set_setting("parameter_toolkit/web/pin_required", config.web_pin_required)
	ProjectSettings.set_setting("parameter_toolkit/web/session_timeout", config.web_session_timeout)
	
	# Apply OSC settings
	ProjectSettings.set_setting("parameter_toolkit/osc/whitelist", config.osc_whitelist)
	ProjectSettings.set_setting("parameter_toolkit/osc/require_secret", config.osc_require_secret)
	ProjectSettings.set_setting("parameter_toolkit/osc/rate_limit", config.osc_rate_limit)
	
	# Apply audit settings
	ProjectSettings.set_setting("parameter_toolkit/security/audit_logging", config.audit_logging)
	
	print("SecurityManager: Applied profile %s -> %s: %s" % [
		Profile.keys()[old_profile],
		Profile.keys()[profile],
		config.description
	])
	
	profile_changed.emit(profile)

## Get configuration for current profile
func get_current_config() -> Dictionary:
	return _profile_configs[current_profile].duplicate()

## Get configuration for specific profile
func get_profile_config(profile: Profile) -> Dictionary:
	return _profile_configs[profile].duplicate()

## Validate if an action is allowed under current security profile
func validate_action(source: String, action: String, context: Dictionary = {}) -> bool:
	var config = _profile_configs[current_profile]
	
	match action:
		"web_access":
			var client_ip = context.get("client_ip", "")
			if not _is_ip_allowed_web(client_ip):
				security_violation.emit(source, "Unauthorized web access from " + client_ip)
				return false
		
		"osc_access":
			var client_ip = context.get("client_ip", "")
			if not _is_ip_allowed_osc(client_ip):
				security_violation.emit(source, "Unauthorized OSC access from " + client_ip)
				return false
		
		"parameter_modification":
			if config.osc_require_secret and not context.get("authenticated", false):
				security_violation.emit(source, "Parameter modification requires authentication")
				return false
	
	return true

## Check if IP is allowed for web access
func _is_ip_allowed_web(client_ip: String) -> bool:
	var config = _profile_configs[current_profile]
	var bind_address = config.web_bind_address
	
	if bind_address == "0.0.0.0":
		return true  # Allow from anywhere
	
	if bind_address == "127.0.0.1":
		return client_ip == "127.0.0.1" or client_ip == "::1"
	
	return false

## Check if IP is allowed for OSC access
func _is_ip_allowed_osc(client_ip: String) -> bool:
	var config = _profile_configs[current_profile]
	var whitelist = config.osc_whitelist
	
	if whitelist.is_empty():
		return current_profile == Profile.ISOLATED  # Only allow in isolated mode
	
	for allowed_ip in whitelist:
		if _ip_matches_pattern(client_ip, allowed_ip):
			return true
	
	return false

## Check if IP matches a pattern (supports CIDR notation)
func _ip_matches_pattern(ip: String, pattern: String) -> bool:
	if ip == pattern:
		return true
	
	# Simple exact match for now
	# TODO: Implement CIDR notation support
	if pattern.ends_with("/24"):
		var base = pattern.substr(0, pattern.length() - 3)
		var ip_parts = ip.split(".")
		var pattern_parts = base.split(".")
		if ip_parts.size() >= 3 and pattern_parts.size() >= 3:
			return (ip_parts[0] == pattern_parts[0] and 
					ip_parts[1] == pattern_parts[1] and 
					ip_parts[2] == pattern_parts[2])
	
	return false

## Convenience methods for profile switching
func enable_isolated_network_mode() -> void:
	apply_profile(Profile.ISOLATED)

func enable_development_mode() -> void:
	apply_profile(Profile.DEVELOPMENT)

func enable_production_mode() -> void:
	apply_profile(Profile.PRODUCTION)

## Get human-readable profile description
func get_profile_description(profile: Profile = current_profile) -> String:
	return _profile_configs[profile].description

## Check if current profile allows unrestricted access
func is_unrestricted_mode() -> bool:
	return current_profile == Profile.ISOLATED
