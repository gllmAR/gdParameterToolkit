# **Parameter Toolkit for Godot 4.4**

### *Software-Engineering Specification v1.1*

---

## 1  Purpose & Scope

Build a reusable **add-on** (GPL-compatible licence) that gives Godot 4.4 projects a *parameter-centric* workflow comparable to **ofParameter + ofxGui** in openFrameworks:

* Designers edit parameters in the *editor* and commit a **default preset** (`res://settings/default.json`).
* End-users can override those values with their own **user preset** (`user://settings.json`).
* Every parameter can be changed **live** from:

  * an in-game settings panel,
  * OSC or raw-UDP messages,
  * an optional self-hosted Web UI.
* Reset, import/export, A/B testing and hot-reload are first-class features.

The add-on must ship as a **plug-and-play module** (copy into `addons/`, enable in *Project → Plugins*, add one autoload).

---

## 2  Stakeholders

| Role                        | Interest                                                       |
| --------------------------- | -------------------------------------------------------------- |
| **Creative coder / artist** | Fast iteration; no boilerplate; visual editing.                |
| **Game dev**                | Clean API, easy integration, works in export templates.        |
| **Exhibition technician**   | Remote tweaking via OSC / browser; reset to “artist defaults”. |
| **QA**                      | Deterministic state, reproducible presets, unit-test hooks.    |

---

## 3  Glossary

* **Preset** – Complete snapshot of all parameters in JSON form
  – *Default preset* lives under `res://` (read-only at runtime)
  – *User preset* lives under `user://` (read/write)
* **Parameter** – Atomic adjustable value (float, int, bool, enum, color, string)
* **Group** – Hierarchical collection of parameters, may contain sub-groups
* **Path** – Slash-separated address (`visual/brightness`) used for binding / OSC
* **Validator** – Function or rule that ensures parameter values meet constraints
* **Dependency** – Relationship where one parameter's change affects another parameter's state
* **Session** – Authenticated connection context for remote interfaces
* **Migration** – Process of converting parameter data between schema versions

---

## 4  User Stories

| ID | Story                                                                                      | Priority |
| -- | ------------------------------------------------------------------------------------------ | -------- |
| U1 | As a designer I can create parameters in the editor and save them as a default preset.     | Must     |
| U2 | As an end-user I can modify settings in-game, save them, and see changes immediately.      | Must     |
| U3 | As an end-user I can press **Reset** and revert to the shipped defaults.                   | Must     |
| U4 | As a technician I can change any parameter through an OSC message.                         | Must     |
| U5 | As a developer I can bind a script callback to a parameter change in one line.             | Must     |
| U6 | As a curator I can open a local Web UI on my phone to tweak values during an installation. | Should   |
| U7 | As a tester I can programmatically load a preset and verify game state matches.            | Should   |
| U8 | As a power-user I can export the current preset to JSON and share it.                      | Could    |
| U9  | As a developer I can define parameter validation rules beyond min/max constraints.        | Should   |
| U10 | As a user I can undo/redo parameter changes with Ctrl+Z/Ctrl+Y.                          | Should   |
| U11 | As a developer I can create parameter dependencies that auto-update related values.       | Could    |
| U12 | As an admin I can monitor parameter system performance and detect bottlenecks.           | Could    |

---

## 5  Functional Requirements (FR)

| ID        | Description                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------------- |
| **FR-1**  | Provide a `SettingsManager` *autoload* exposing CRUD operations for presets.                            |
| **FR-2**  | Support parameter types: **float, int, bool, enum, color, string**.                                     |
| **FR-3**  | Each parameter emits a **`changed(value)`** signal on update.                                           |
| **FR-4**  | Parameters are addressable via a unique **path**; retrieval in O(1).                                    |
| **FR-5**  | Editor dock for creating, deleting, re-ordering parameters & groups.                                    |
| **FR-6**  | **Save as Default** writes JSON under `res://settings/` (over-write allowed).                           |
| **FR-7**  | `SettingsManager` loads default → merges user preset on launch.                                         |
| **FR-8**  | In-game settings panel auto-generates widgets from the parameter graph.                                 |
| **FR-9**  | Provide **OSC** bridge (UDP, configurable port) for get/set & discovery.                                |
| **FR-10** | Provide **Web dashboard** (HTTP + WebSocket) that mirrors the panel.                                    |
| **FR-11** | `reset_user()` deletes or ignores user preset and reloads default *live*.                               |
| **FR-12** | Hot-reload: changing a value immediately fires signals and updates widgets, OSC, WebSocket subscribers. |
| **FR-13** | JSON schema versioning & graceful migration strategy.                                                   |
| **FR-14** | Support custom validation rules (regex, custom functions, enum constraints).               |
| **FR-15** | Implement undo/redo system with configurable history depth (default 50 operations).       |
| **FR-16** | Support parameter dependencies with automatic cascade updates and cycle detection.         |
| **FR-17** | Provide performance monitoring hooks and optional profiling data collection.               |
| **FR-18** | Support parameter templates for rapid creation of similar parameter sets.                  |
| **FR-19** | Implement session-based authentication for remote connections with token expiry.           |
| **FR-20** | Support parameter groups with inherited properties and override capabilities.              |
| **FR-21** | OSC bridge supports preset operations: **/save_user, /load_user, /reset_user, /export_preset, /import_preset**. |

---

## 6  Non-Functional Requirements (NFR)

* **NFR-1 (Performance)** – Load & merge ≤ 100 parameters in < 50 ms on desktop; < 200 ms on Raspberry Pi 4.
* **NFR-2 (Footprint)** – Add-on must not increase exported binary size by > 500 kB (excluding Web UI assets).
* **NFR-3 (Thread Safety)** – All public API callable from main thread only; external parameter updates (OSC/Web) processed via thread-safe queue and applied on main thread.
* **NFR-4 (Portability)** – Works in desktop, HTML5, Android, iOS export templates. Web UI uses HTTPServer on desktop/mobile; HTML5 uses alternative communication via URL parameters, localStorage, or external messaging.
* **NFR-5 (Security)** – Adequate security by default with easy opt-out for isolated networks; Web dashboard binds to `localhost` by default but easily configurable for LAN access.
* **NFR-6 (Localization)** – GUI labels support Godot’s translation strings.
* **NFR-7 (Reliability)** – Parameter changes must be atomic; partial updates not allowed.
* **NFR-8 (Maintainability)** – Core API must remain backward compatible within major versions.
* **NFR-9 (Usability)** – Parameter widgets must support keyboard navigation and screen readers.
* **NFR-10 (Scalability)** – System must handle parameter trees up to 10 levels deep without performance degradation.

---

## 7  High-Level Architecture

```text
+--------------------------------------------------------------+
|                         SettingsManager                      |
| (autoload)                                                   |
| • Root ParameterGroup                                        |
| • Persistence (JSON)                                         |
| • Bridge registry                                            |
| • Thread-safe parameter queue                               |
| • bind(path,Callable) helper                                 |
+---^--------------^--------------------^--------------^-------+
    |              |                    |              |
    | signals      | signals            | OSC msgs     | WS messages
+---+----+  +------+-----+      +-------+-----+  +------+-----+
| GUI    |  | Editor Dock |      | OSC Bridge |  | Web Dash   |
| Panel  |  | (tool mode) |      | (Thread)   |  | (Thread)   |
+--------+  +------------+      +-------------+  +-----------+
```

* **SettingsManager** is **source of truth**.
* **External bridges** run on background threads, queue parameter updates.
* All parameter modifications applied atomically on main thread.

---

## 8  Module Breakdown

| Module             | Owner      | Key Classes / Files                                                    |
| ------------------ | ---------- | ---------------------------------------------------------------------- |
| **Core**           | Core team  | `parameter.gd`, `parameter_group.gd`, `settings_manager.gd`            |
| **Editor**         | Tools team | `parameter_inspector_plugin.gd`, `parameter_dock.tscn`                 |
| **GUI**            | UI team    | `widgets/` (slider, toggle…), `settings_panel.tscn`                    |
| **OSC Bridge**     | Net team   | `osc_bridge.gd`, uses **GodotOSC** or built-in `PacketPeerUDP`         |
| **Web Bridge**     | Net team   | `web_dashboard.gd`, `web_client/` static assets (plain JS + WebSocket) |
| **Docs / Samples** | DevRel     | `demo/` Godot project showcasing usage                                 |
| **Validation**     | Core team  | `validators/`, `parameter_validator.gd`, `validation_rule.gd`          |
| **History**        | Core team  | `parameter_history.gd`, `history_command.gd`                          |
| **Dependencies**   | Core team  | `parameter_dependency.gd`, `dependency_graph.gd`                      |
| **Monitoring**     | Tools team | `performance_monitor.gd`, `parameter_profiler.gd`                     |

---

## 9  Detailed Design

### 9.1 Data Model

```jsonc
{
  "$schema": "https://example.com/parameter.schema.json",
  "version": 2,
  "metadata": {
    "created": "2024-01-01T00:00:00Z",
    "modified": "2024-01-15T12:30:00Z",
    "author": "artist@example.com",
    "description": "Main installation parameters"
  },
  "groups": [
    {
      "name": "visual",
      "description": "Visual appearance settings",
      "inheritance": {
        "enabled": true,
        "base_group": "defaults"
      },
      "params": [
        {
          "name": "brightness",
          "type": "float",
          "value": 0.8,
          "min": 0.0,
          "max": 2.0,
          "step": 0.1,
          "exposed": true,
          "description": "Overall brightness multiplier",
          "validation": {
            "rules": ["range(0.0, 2.0)", "step(0.1)"],
            "custom_validator": "brightness_validator"
          },
          "dependencies": [
            {
              "target": "visual/contrast",
              "expression": "brightness * 0.5",
              "condition": "brightness > 1.0"
            }
          ],
          "ui_hints": {
            "widget": "slider",
            "precision": 2,
            "show_value": true
          }
        }
      ],
      "groups": []
    }
  ],
  "templates": [
    {
      "name": "color_param",
      "type": "color",
      "value": "#ffffff",
      "exposed": true,
      "ui_hints": {
        "widget": "color_picker",
        "show_alpha": false
      }
    }
  ]
}
```

### 9.2 Class Contracts

#### 9.2.1 `Parameter` (Enhanced)

| Method                              | Description                                      |
| ----------------------------------- | ------------------------------------------------ |
| `set_value(v:Variant) -> bool`      | Validate, clamp, store, emit `changed(v)`. Returns success. |
| `add_validator(rule:ValidationRule)` | Add custom validation rule.                      |
| `add_dependency(dep:ParameterDependency)` | Register dependency on another parameter.   |
| `get_validation_errors() -> Array[String]` | Get current validation error messages.     |

#### 9.2.2 `ParameterGroup` (Enhanced)

| Method                                       | Description                                        |
| -------------------------------------------- | -------------------------------------------------- |
| `create_from_template(name:String, template:String)` | Create parameter from predefined template.  |
| `set_inheritance(enabled:bool, base:String)` | Configure group inheritance behavior.             |
| `get_dependent_params(path:String) -> Array` | Get parameters that depend on given parameter.    |

#### 9.2.3 `SettingsManager` (Enhanced)

| Property | Type                   | Description                        |
| -------- | ---------------------- | ---------------------------------- |
| `history` | `ParameterHistory`    | Undo/redo command history.         |
| `monitor` | `PerformanceMonitor`  | Performance tracking (optional).   |

| Method                           | Description                                    |
| -------------------------------- | ---------------------------------------------- |
| `undo() -> bool`                 | Undo last parameter change.                   |
| `redo() -> bool`                 | Redo previously undone change.                |
| `begin_batch()`                  | Start batching parameter changes.             |
| `end_batch()`                    | Apply batched changes atomically.             |
| `validate_all() -> Array[String]` | Validate all parameters, return errors.      |
| `get_performance_stats() -> Dictionary` | Get system performance metrics.       |

### 9.3 OSC Bridge

* Config via project settings (`parameter_toolkit/osc/port`, default 7000).
* **Runs on background thread** to avoid blocking main thread during network I/O.
* **Message Types**

| Address             | Payload      | Action                                              |
| ------------------- | ------------ | --------------------------------------------------- |
| `/param/<path>`     | single value | Set parameter (queued for main thread)             |
| `/get/<path>`       | (empty)      | Bridge replies `/param/<path>` current value        |
| `/list`             | (empty)      | Bridge replies JSON blob listing all exposed params |
| `/save_user`        | (empty)      | Save current state as user preset                   |
| `/load_user`        | (empty)      | Load user preset (if exists)                        |
| `/reset_user`       | (empty)      | Reset to default preset, clear user overrides      |
| `/export_preset`    | (empty)      | Bridge replies with full preset JSON                |
| `/import_preset`    | JSON blob    | Load preset from JSON (temporary, not saved)        |

### 9.4 Web Dashboard

* **Desktop/Mobile**: HTTPServer on configurable port (default 8000)
* **HTML5**: Alternative communication methods due to HTTPServer limitations
* Config via project settings (`parameter_toolkit/web/enabled`, default `false`).

#### 9.4.1 Desktop/Mobile Communication

* Configurable via `parameter_toolkit/web/port`
* Binds to all network interfaces by default for LAN access
* Optional PIN protection (`parameter_toolkit/web/pin_required`)

#### 9.4.2 HTML5 Communication Strategies

Since HTTPServer is not available in HTML5 exports, the toolkit provides alternative communication methods:

**Option 1: URL Parameters (Read-only)**
```javascript
// Set parameters via URL: https://game.com/?brightness=0.8&volume=0.5
// Parameters loaded on game start
```

**Option 2: localStorage Bridge**
```javascript
// External controller writes to localStorage
localStorage.setItem('pt_param_brightness', '0.8');
// Game polls localStorage for changes
```

**Option 3: PostMessage API**
```javascript
// Parent page can send parameters to embedded game
window.parent.postMessage({
    type: 'parameter_update',
    path: 'visual/brightness',
    value: 0.8
}, '*');
```

**Option 4: External WebSocket Proxy**
```javascript
// Use external WebSocket server as relay
// Game connects to ws://relay-server/game-id
// Controllers connect to same relay
```

#### 9.4.3 HTML5 Implementation

```gdscript
# HTML5-specific parameter bridge
class HTML5Bridge:
    var _check_interval: float = 0.1  # Check for updates every 100ms
    
    func _ready():
        if OS.get_name() == "HTML5":
            _setup_html5_communication()
    
    func _setup_html5_communication():
        # Set up URL parameter parsing
        _parse_url_parameters()
        
        # Set up localStorage polling
        var timer = Timer.new()
        timer.wait_time = _check_interval
        timer.timeout.connect(_check_localStorage_updates)
        add_child(timer)
        timer.start()
        
        # Set up PostMessage listener
        if JavaScriptBridge:
            JavaScriptBridge.eval("""
                window.addEventListener('message', function(event) {
                    if (event.data.type === 'parameter_update') {
                        godot_parameter_update(event.data.path, event.data.value);
                    }
                });
            """)
```

### 9.5 Enhanced Security Model

#### 9.5.1 Security Defaults for Different Environments

| Environment | Default Security Level | Rationale |
|-------------|----------------------|-----------|
| **Desktop Development** | Medium (localhost only) | Developer convenience |
| **Desktop Production** | High (authentication required) | Public deployment safety |
| **Isolated Network** | Low (easy LAN access) | Performance/convenience priority |
| **HTML5** | Medium (limited by platform) | Browser security constraints |

#### 9.5.2 Easy Security Opt-Out Configuration

```jsonc
// Quick isolated network setup
{
  "parameter_toolkit/security/isolated_network_mode": true,  // Disables most security
  "parameter_toolkit/web/bind_address": "0.0.0.0",         // Allow LAN access
  "parameter_toolkit/web/pin_required": false,             // No PIN needed
  "parameter_toolkit/osc/whitelist": [],                   // Accept from any IP
  "parameter_toolkit/osc/require_secret": false            // No secret needed
}
```

```jsonc
// Production security (default for builds)
{
  "parameter_toolkit/security/isolated_network_mode": false,
  "parameter_toolkit/web/bind_address": "127.0.0.1",
  "parameter_toolkit/web/pin_required": true,
  "parameter_toolkit/web/session_timeout": 3600,
  "parameter_toolkit/osc/whitelist": ["192.168.1.0/24"],
  "parameter_toolkit/osc/require_secret": true
}
```

#### 9.5.3 Runtime Security Configuration

```gdscript
# Easy security mode switching
class SettingsManager:
    func enable_isolated_network_mode() -> void:
        ProjectSettings.set_setting("parameter_toolkit/security/isolated_network_mode", true)
        ProjectSettings.set_setting("parameter_toolkit/web/bind_address", "0.0.0.0")
        ProjectSettings.set_setting("parameter_toolkit/web/pin_required", false)
        ProjectSettings.set_setting("parameter_toolkit/osc/require_secret", false)
        _restart_bridges()
    
    func enable_production_security() -> void:
        ProjectSettings.set_setting("parameter_toolkit/security/isolated_network_mode", false)
        ProjectSettings.set_setting("parameter_toolkit/web/bind_address", "127.0.0.1")
        ProjectSettings.set_setting("parameter_toolkit/web/pin_required", true)
        ProjectSettings.set_setting("parameter_toolkit/osc/require_secret", true)
        _restart_bridges()
```

#### 9.5.4 Security Level Detection

```gdscript
# Automatic security level detection
func _detect_security_level() -> String:
    # Check if running in development
    if OS.is_debug_build():
        return "development"
    
    # Check network interfaces for isolation indicators
    var interfaces = IP.get_local_interfaces()
    var has_internet = _check_internet_connectivity()
    
    if not has_internet and _is_private_network_only(interfaces):
        return "isolated"
    
    return "production"
```

### 9.6 Platform-Specific Parameter Communication

#### 9.6.1 Communication Matrix

| Platform | HTTP Server | OSC | PostMessage | localStorage | URL Params |
|----------|-------------|-----|-------------|--------------|------------|
| **Desktop** | ✅ Primary | ✅ Primary | ❌ | ❌ | ❌ |
| **Mobile** | ✅ Primary | ✅ Primary | ❌ | ❌ | ❌ |
| **HTML5** | ❌ Not available | ⚠️ Limited* | ✅ Primary | ✅ Polling | ✅ Init only |

*OSC in HTML5 requires WebRTC or external proxy

#### 9.6.2 HTML5 Parameter Controller Example

```html
<!-- External HTML5 parameter controller -->
<!DOCTYPE html>
<html>
<head>
    <title>Parameter Controller</title>
</head>
<body>
    <div id="controls"></div>
    
    <script>
    class HTML5ParameterController {
        constructor(gameFrame) {
            this.gameFrame = gameFrame;
            this.setupControls();
        }
        
        // Send parameter via PostMessage
        setParameter(path, value) {
            this.gameFrame.contentWindow.postMessage({
                type: 'parameter_update',
                path: path,
                value: value
            }, '*');
        }
        
        // Alternative: localStorage method
        setParameterViaStorage(path, value) {
            localStorage.setItem(`pt_param_${path.replace('/', '_')}`, JSON.stringify(value));
        }
        
        setupControls() {
            // Create UI controls that call setParameter()
            const slider = document.createElement('input');
            slider.type = 'range';
            slider.min = 0;
            slider.max = 1;
            slider.step = 0.1;
            slider.addEventListener('input', (e) => {
                this.setParameter('visual/brightness', parseFloat(e.target.value));
            });
            document.getElementById('controls').appendChild(slider);
        }
    }
    
    // Initialize when game iframe loads
    window.addEventListener('load', () => {
        const gameFrame = document.getElementById('game-frame');
        new HTML5ParameterController(gameFrame);
    });
    </script>
</body>
</html>
```

---

## 11  Security Considerations (Enhanced)

### 11.1 Adaptive Security Model

The toolkit implements **adaptive security** that balances usability with protection based on deployment context:

#### 11.1.1 Security Profiles

**Isolated Network Profile** (Easy opt-in)
* No authentication required
* Bind to all interfaces (0.0.0.0)
* Accept connections from any IP
* Minimal logging
* **Use case**: Art installations, kiosks, local development

**Development Profile** (Default in debug builds)
* Localhost-only access
* Optional PIN authentication
* Basic rate limiting
* **Use case**: Local development and testing

**Production Profile** (Default in release builds)
* Full authentication required
* Restricted network access
* Comprehensive logging and monitoring
* **Use case**: Public deployments, networked applications

#### 11.1.2 One-Line Security Configuration

```gdscript
# In your project's autoload or main scene
func _ready():
    # For isolated networks (art installations, kiosks)
    SettingsManager.configure_for_isolated_network()
    
    # For development
    SettingsManager.configure_for_development()
    
    # For production (default)
    SettingsManager.configure_for_production()
```

### 11.2 HTML5 Security Considerations

* **PostMessage**: Validate origin in production environments
* **localStorage**: No sensitive data storage (client-accessible)
* **URL Parameters**: Read-only, suitable for initial configuration
* **External Proxy**: Use WSS for encrypted communication

### 11.3 Access Control Matrix (Updated)

| Operation | Local | Remote + PIN | OSC + Secret | OSC (Isolated) | HTML5 PostMessage | Guest |
|-----------|-------|--------------|--------------|----------------|-------------------|-------|
| Read parameters | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Modify parameters | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Save user preset | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Load user preset | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Reset to defaults | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Export preset | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Import preset | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Modify structure | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## 12  Testing Strategy (Enhanced)

### 12.1 Unit Tests (GUT)

| Area                 | Cases                                   |
| -------------------- | --------------------------------------- |
| Parameter.set\_value | clamp, signal emission, type coercion   |
| JSON round-trip      | to\_json → from\_json equality          |
| Merge logic          | default + user overrides                |
| Bind helper          | callable invoked initially & on change  |
| OSC Bridge           | send `/param/x` and verify root updated |
| Validation System    | rule creation, chain execution, error reporting |
| Dependency System    | cycle detection, update order, formula parsing  |
| History System       | undo/redo, batch operations, memory limits      |
| Security System      | authentication, authorization, rate limiting    |
| Threading System     | queue operations, thread safety, race conditions    |
| OSC Preset Ops       | save/load/reset via OSC, concurrent access          |

### 12.2 Performance Tests

```gdscript
# Updated performance test with realistic expectations
func test_100_parameters_load_time():
    var start_time = Time.get_time_usec()
    var preset = _generate_test_preset(100)  # Reduced from 10k
    SettingsManager.load_from_json(preset)
    var load_time = (Time.get_time_usec() - start_time) / 1000.0  # ms
    assert_lt(load_time, 50.0, "Load time should be under 50ms for 100 parameters")
```

### 12.3 Concurrency Tests

* Multiple OSC clients sending simultaneous parameter updates
* Web dashboard and OSC bridge concurrent access
* Preset save/load operations during parameter updates
* Thread safety validation under high load
* Race condition detection in parameter queue

---

## 13  Migration & Compatibility

### 13.1 Schema Migration

```gdscript
class ParameterMigrator:
    func migrate_v1_to_v2(data: Dictionary) -> Dictionary:
        # Add metadata section
        data["metadata"] = {
            "created": Time.get_datetime_string_from_system(),
            "version_migrated_from": 1
        }
        # Convert old validation format
        for group in data.groups:
            _migrate_validation_rules(group)
        return data
```

### 13.2 Backward Compatibility

* Parameter API maintains compatibility within major versions
* Deprecated features marked clearly with timeline for removal
* Migration tools provided for breaking changes
* Legacy preset support for at least one major version

---

## 14  Project Timeline (Updated)

| Week | Deliverable                                        |
| ---- | -------------------------------------------------- |
| 1-2  | Core data model + enhanced SettingsManager        |
| 3    | Validation system + basic editor dock             |
| 4    | In-game settings panel + dependency system        |
| 5    | Undo/redo + performance monitoring                |
| 6    | OSC bridge + enhanced security                     |
| 7    | Web dashboard + authentication                     |
| 8-9  | Performance optimization + mobile testing         |
| 10   | Documentation, security audit, v1.0 release       |

---

## 15  Acceptance Criteria (Enhanced)

1. Specified user stories U1-U5 pass manual QA on desktop export; U6 passes on local network.
2. Automated CI pipeline green (unit + integration tests).
3. `demo/parameter_toolkit_demo` runs in HTML5 export with default→user preset flow.
4. Memory leak scan (`--debug-leaks`) shows zero leaks after 1 h soak.
5. Performance benchmark: 100 parameter load < 50 ms on desktop, < 200 ms on RPi 4.
6. Security audit passes with no critical or high-severity findings.
7. Validation system handles edge cases without crashes or data corruption.
8. Dependency system prevents infinite loops and maintains consistency.
9. Undo/redo system works correctly with batched operations.
10. Performance monitoring accurately identifies bottlenecks.
11. OSC preset operations (save/load/reset) work reliably under concurrent access.
12. Thread-safe parameter updates handle high-frequency external input without data loss.
13. HTML5 export supports parameter updates via PostMessage and localStorage methods.
14. Security profiles can be switched with single function calls.
15. Isolated network mode works without any authentication on LAN.

---

## 16  Deliverables (Enhanced)

* `addons/parameter_toolkit/` source code
* JSON schema docs (`docs/schema.md`)
* Godot demo project
* README with getting-started & API reference
* Developer docs (`docs/dev_guide.md`) incl. migration guide
* CI configuration
* Test suite
* Change-log and semantic versioning starting at **v1.0.0**
* Security documentation and audit report
* Performance benchmarking results
* Migration guides for schema updates
* Accessibility compliance documentation
* Production deployment guide
* HTML5 parameter controller example page
* Security configuration guide for different deployment scenarios
* Network isolation detection and auto-configuration tools

---

### **End of Enhanced Specification v1.1**
