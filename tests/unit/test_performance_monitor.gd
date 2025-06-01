# Copyright © 2024 Parameter Toolkit Contributors - MIT License

extends RefCounted

## Unit tests for PerformanceMonitor

var PerformanceMonitorClass = preload("res://addons/parameter_toolkit/core/performance_monitor.gd")

func test_performance_monitor_creation():
	var monitor = PerformanceMonitorClass.new()
	assert_not_null(monitor)
	assert_true(monitor.enabled)
	
	print("✓ Performance monitor creation test passed")

func test_timing_operations():
	var monitor = PerformanceMonitorClass.new()
	
	# Test basic timing
	var timer = monitor.start_timing("test_operation")
	assert_true(timer.has("operation"))
	assert_true(timer.has("start_time"))
	
	# Simulate some work
	await _wait_frame()
	
	monitor.end_timing(timer)
	
	var stats = monitor.get_metric_stats("test_operation")
	assert_true(stats.has("count"))
	assert_eq(stats.count, 1)
	
	print("✓ Timing operations test passed")

func test_performance_alerts():
	var monitor = PerformanceMonitorClass.new()
	
	var alert_data = {"triggered": false}
	monitor.performance_alert.connect(func(_metric, _value, _threshold):
		alert_data.triggered = true
	)
	
	# Record a value that should trigger an alert
	monitor._record_metric("parameter_update", 1000.0)  # Way over threshold
	
	assert_true(alert_data.triggered)
	
	print("✓ Performance alerts test passed")

func test_metric_statistics():
	var monitor = PerformanceMonitorClass.new()
	
	# Record multiple samples
	monitor._record_metric("test_metric", 10.0)
	monitor._record_metric("test_metric", 20.0)
	monitor._record_metric("test_metric", 30.0)
	
	var stats = monitor.get_metric_stats("test_metric")
	assert_eq(stats.count, 3)
	assert_eq(stats.min, 10.0)
	assert_eq(stats.max, 30.0)
	assert_eq(stats.average, 20.0)
	
	print("✓ Metric statistics test passed")

func test_performance_report():
	var monitor = PerformanceMonitorClass.new()
	
	# Add some test data
	monitor._record_metric("parameter_update", 5.0)
	monitor._record_metric("preset_load", 25.0)
	
	var report = monitor.get_performance_report()
	assert_true(report.has("timestamp"))
	assert_true(report.has("metrics"))
	assert_true(report.has("summary"))
	assert_eq(report.summary.total_operations, 2)
	
	print("✓ Performance report test passed")

func test_function_measurement():
	var monitor = PerformanceMonitorClass.new()
	
	var test_function = func():
		return 42
	
	var result = monitor.measure_function(test_function, "test_function")
	assert_eq(result, 42)
	
	var stats = monitor.get_metric_stats("test_function")
	assert_eq(stats.count, 1)
	
	print("✓ Function measurement test passed")

func run_tests():
	print("Running PerformanceMonitor tests...")
	test_performance_monitor_creation()
	await test_timing_operations()
	test_performance_alerts()
	test_metric_statistics()
	test_performance_report()
	test_function_measurement()
	print("All PerformanceMonitor tests completed!")

# Helper functions
func _wait_frame():
	# Simulate waiting a frame for timing tests
	await Engine.get_main_loop().process_frame

func assert_eq(actual, expected):
	if actual != expected:
		push_error("Assertion failed: expected %s, got %s" % [expected, actual])

func assert_true(value):
	if not value:
		push_error("Assertion failed: expected true, got %s" % value)

func assert_not_null(value):
	if value == null:
		push_error("Assertion failed: expected non-null value")
