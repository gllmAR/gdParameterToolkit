# Copyright © 2024 Parameter Toolkit Contributors - MIT License

## Performance Monitor for Parameter Toolkit
##
## Tracks key performance metrics and provides alerts for performance degradation.
## Lightweight and optional - can be disabled for production if needed.

class_name PerformanceMonitor extends RefCounted

## Performance tracking configuration
var enabled: bool = true
var sample_window_seconds: float = 60.0
var alert_threshold_multiplier: float = 2.0

## Metric tracking
var _metrics: Dictionary = {}
var _metric_history: Dictionary = {}
var _alert_states: Dictionary = {}

## Performance thresholds (in milliseconds)
const THRESHOLDS = {
	"parameter_update": 1.0,      # Single parameter update
	"preset_load": 50.0,          # Load 100 parameters
	"preset_save": 10.0,          # Save preset to disk
	"validation_check": 0.5,      # Single parameter validation
	"dependency_update": 2.0,     # Dependency cascade update
	"memory_usage": 1048576,      # 1MB memory usage (bytes)
}

signal performance_alert(metric: String, current_value: float, threshold: float)
signal metric_updated(metric: String, value: float, timestamp: float)

func _init():
	_initialize_metrics()
	print("PerformanceMonitor: Initialized with %d metrics" % _metrics.size())

## Initialize all tracking metrics
func _initialize_metrics():
	for metric_name in THRESHOLDS.keys():
		_metrics[metric_name] = {
			"count": 0,
			"total_time": 0.0,
			"min_time": INF,
			"max_time": 0.0,
			"last_update": 0.0,
			"samples": []
		}
		_metric_history[metric_name] = []
		_alert_states[metric_name] = false

## Start timing a performance-critical operation
func start_timing(operation: String) -> Dictionary:
	if not enabled:
		return {}
	
	return {
		"operation": operation,
		"start_time": Time.get_ticks_usec(),
		"memory_before": _get_memory_usage()
	}

## End timing and record the metric
func end_timing(timer_data: Dictionary) -> void:
	if not enabled or timer_data.is_empty():
		return
	
	var end_time = Time.get_ticks_usec()
	var operation = timer_data.operation
	var duration_ms = (end_time - timer_data.start_time) / 1000.0
	var memory_after = _get_memory_usage()
	var memory_delta = memory_after - timer_data.memory_before
	
	_record_metric(operation, duration_ms)
	
	if memory_delta > 0:
		_record_metric("memory_usage", memory_delta)

## Record a performance metric
func _record_metric(metric_name: String, value: float) -> void:
	if not _metrics.has(metric_name):
		return
	
	var metric = _metrics[metric_name]
	var timestamp = Time.get_ticks_usec() / 1000000.0
	
	# Update metric statistics
	metric.count += 1
	metric.total_time += value
	metric.min_time = min(metric.min_time, value)
	metric.max_time = max(metric.max_time, value)
	metric.last_update = timestamp
	
	# Add to samples window
	metric.samples.append({"value": value, "timestamp": timestamp})
	
	# Clean old samples outside window
	_clean_old_samples(metric_name)
	
	# Check for performance alerts
	_check_performance_alert(metric_name, value)
	
	metric_updated.emit(metric_name, value, timestamp)

## Clean samples outside the monitoring window
func _clean_old_samples(metric_name: String) -> void:
	var metric = _metrics[metric_name]
	var cutoff_time = Time.get_ticks_usec() / 1000000.0 - sample_window_seconds
	
	var cleaned_samples = []
	for sample in metric.samples:
		if sample.timestamp > cutoff_time:
			cleaned_samples.append(sample)
	
	metric.samples = cleaned_samples

## Check if a metric exceeds performance thresholds
func _check_performance_alert(metric_name: String, current_value: float) -> void:
	if not THRESHOLDS.has(metric_name):
		return
	
	var threshold = THRESHOLDS[metric_name] * alert_threshold_multiplier
	var is_alert = current_value > threshold
	var was_alerting = _alert_states[metric_name]
	
	if is_alert and not was_alerting:
		_alert_states[metric_name] = true
		performance_alert.emit(metric_name, current_value, threshold)
		print("PerformanceMonitor: ALERT - %s exceeded threshold: %.2f > %.2f" % 
			  [metric_name, current_value, threshold])
	elif not is_alert and was_alerting:
		_alert_states[metric_name] = false
		print("PerformanceMonitor: RECOVERED - %s back within threshold: %.2f <= %.2f" % 
			  [metric_name, current_value, threshold])

## Get current memory usage (simplified)
func _get_memory_usage() -> int:
	# In a real implementation, this would use proper memory tracking
	# For now, we'll return 0 as a placeholder
	return 0

## Get performance statistics for a specific metric
func get_metric_stats(metric_name: String) -> Dictionary:
	if not _metrics.has(metric_name):
		return {}
	
	var metric = _metrics[metric_name]
	
	if metric.count == 0:
		return {"metric": metric_name, "no_data": true}
	
	var avg_time = metric.total_time / metric.count
	var recent_samples = _get_recent_samples(metric_name, 10)
	var recent_avg = 0.0
	
	if recent_samples.size() > 0:
		var total = 0.0
		for sample in recent_samples:
			total += sample.value
		recent_avg = total / recent_samples.size()
	
	return {
		"metric": metric_name,
		"count": metric.count,
		"average": avg_time,
		"min": metric.min_time,
		"max": metric.max_time,
		"recent_average": recent_avg,
		"threshold": THRESHOLDS.get(metric_name, 0.0),
		"is_alerting": _alert_states[metric_name],
		"last_update": metric.last_update
	}

## Get recent samples for a metric
func _get_recent_samples(metric_name: String, count: int) -> Array:
	if not _metrics.has(metric_name):
		return []
	
	var samples = _metrics[metric_name].samples
	var start_index = max(0, samples.size() - count)
	return samples.slice(start_index)

## Get comprehensive performance report
func get_performance_report() -> Dictionary:
	var report = {
		"timestamp": Time.get_datetime_string_from_system(),
		"enabled": enabled,
		"sample_window_seconds": sample_window_seconds,
		"metrics": {},
		"alerts": [],
		"summary": {}
	}
	
	var total_operations = 0
	var alerting_metrics = 0
	
	for metric_name in _metrics.keys():
		var stats = get_metric_stats(metric_name)
		if not stats.has("no_data"):
			report.metrics[metric_name] = stats
			total_operations += stats.count
			
			if stats.is_alerting:
				alerting_metrics += 1
				report.alerts.append({
					"metric": metric_name,
					"current": stats.recent_average,
					"threshold": stats.threshold
				})
	
	report.summary = {
		"total_operations": total_operations,
		"alerting_metrics": alerting_metrics,
		"health_status": "healthy" if alerting_metrics == 0 else "degraded"
	}
	
	return report

## Simple convenience method for measuring function execution
func measure_function(callable: Callable, operation_name: String) -> Variant:
	var timer = start_timing(operation_name)
	var result = callable.call()
	end_timing(timer)
	return result

## Enable/disable performance monitoring
func set_enabled(enabled_state: bool) -> void:
	enabled = enabled_state
	print("PerformanceMonitor: %s" % ("Enabled" if enabled else "Disabled"))

## Reset all metrics
func reset_metrics() -> void:
	for metric_name in _metrics.keys():
		_metrics[metric_name] = {
			"count": 0,
			"total_time": 0.0,
			"min_time": INF,
			"max_time": 0.0,
			"last_update": 0.0,
			"samples": []
		}
		_alert_states[metric_name] = false
	
	print("PerformanceMonitor: All metrics reset")

## Get simplified stats for SettingsManager integration
func get_simple_stats() -> Dictionary:
	var stats = {
		"enabled": enabled,
		"total_operations": 0,
		"average_response_time": 0.0,
		"alerting_count": 0
	}
	
	var total_time = 0.0
	var total_count = 0
	
	for metric_name in _metrics.keys():
		var metric = _metrics[metric_name]
		total_count += metric.count
		total_time += metric.total_time
		
		if _alert_states[metric_name]:
			stats.alerting_count += 1
	
	stats.total_operations = total_count
	if total_count > 0:
		stats.average_response_time = total_time / total_count
	
	return stats
