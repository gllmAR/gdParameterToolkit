# **Parameter Toolkit for Godot 4.4**

### *Software-Engineering Specification v1.0*

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

---

## 6  Non-Functional Requirements (NFR)

* **NFR-1 (Performance)** – Load & merge ≤ 10 k parameters in < 50 ms on desktop; < 200 ms on Raspberry Pi 4.
* **NFR-2 (Footprint)** – Add-on must not increase exported binary size by > 500 kB (excluding Web UI assets).
* **NFR-3 (Thread Safety)** – All public API callable from main thread only; emit warnings if mis-used.
* **NFR-4 (Portability)** – Works in desktop, HTML5, Android, iOS export templates (Web UI optional on mobile due to HTTPServer limitation in HTML5).
* **NFR-5 (Security)** – Web dashboard only binds to `localhost` by default; CORS disabled; no file-system access exposed.
* **NFR-6 (Localization)** – GUI labels support Godot’s translation strings.

---

## 7  High-Level Architecture

```text
+--------------------------------------------------------------+
|                         SettingsManager                      |
| (autoload)                                                   |
| • Root ParameterGroup                                        |
| • Persistence (JSON)                                         |
| • Bridge registry                                            |
| • bind(path,Callable) helper                                 |
+---^--------------^--------------------^--------------^-------+
    |              |                    |              |
    | signals      | signals            | OSC msgs     | WS messages
+---+----+  +------+-----+      +-------+-----+  +------+-----+
| GUI    |  | Editor Dock |      | OSC Bridge |  | Web Dash   |
| Panel  |  | (tool mode) |      | (Node)     |  | (HTTP+WS)  |
+--------+  +------------+      +-------------+  +-----------+
```

* **SettingsManager** is **source of truth**.
* GUI, OSC, Web all subscribe to signals; no direct cross-talk.
* Bridges are modular (`IBridge` interface).

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

---

## 9  Detailed Design

### 9.1 Data Model

```jsonc
{
  "$schema": "https://example.com/parameter.schema.json",
  "version": 1,
  "groups": [
    {
      "name": "visual",
      "params": [
        {
          "name": "brightness",
          "type": "float",
          "value": 0.8,
          "min": 0.0,
          "max": 2.0,
          "exposed": true
        }
      ],
      "groups": []
    }
  ]
}
```

* **`exposed`** flag: included in OSC/Web listing.
* Future versions must be up-convertible via `SettingsMigrator`.

### 9.2 Class Contracts

#### 9.2.1 `Parameter`

| Method                         | Description                               |
| ------------------------------ | ----------------------------------------- |
| `set_value(v:Variant) -> void` | Clamp/validate, store, emit `changed(v)`. |
| `to_json() -> Dictionary`      | Serialise to Dict.                        |
| `from_json(dict)`              | Populate fields.                          |

#### 9.2.2 `ParameterGroup`

| Method                                | Description                                 |
| ------------------------------------- | ------------------------------------------- |
| `get_param(path:String) -> Parameter` | O(log n) or O(1) access via hash map.       |
| `to_json()/from_json()`               | Recursive.                                  |
| `merge_json(dict, overwrite=false)`   | Merge with incoming JSON (for user preset). |

#### 9.2.3 `SettingsManager` (autoload)

| Property | Type             | Description              |
| -------- | ---------------- | ------------------------ |
| `root`   | `ParameterGroup` | Populated on `_ready()`. |

| Method                     | Description                              |
| -------------------------- | ---------------------------------------- |
| `load_defaults()`          | Read `DEFAULT_PATH`.                     |
| `merge_user()`             | Apply user preset (non-destructive).     |
| `save_default()`           | Overwrite default JSON (editor only).    |
| `save_user()`              | Write `user://settings.json`.            |
| `reset_user()`             | Delete user file and reload default.     |
| `bind(path, callable)`     | Shortcut: connect signal + initial call. |
| `get_value(path, default)` | Safe fetch without raising.              |

### 9.3 OSC Bridge

* Config via project settings (`parameter_toolkit/osc/port`, default 7000).
* **Message Types**

| Address         | Payload      | Action                                              |
| --------------- | ------------ | --------------------------------------------------- |
| `/param/<path>` | single value | Set parameter                                       |
| `/get/<path>`   | (empty)      | Bridge replies `/param/<path>` current value        |
| `/list`         | (empty)      | Bridge replies JSON blob listing all exposed params |

### 9.4 Web Dashboard

* **HTTPServer** on configurable port (default 8000, disabled in HTML5 export).
* REST endpoints:

  * `GET /api/list` → JSON of exposed params + metadata
  * `PUT /api/param/<path>` `{value: …}`
* Single WebSocket `/ws` broadcasting `{path, value}` on change; accepts same to set.

### 9.5 Settings Panel (UI)

* Built with **scene-generation**: iterate through `root`, instanciate widget prefab according to param type.
* **Input navigation spec** (for kiosk remotes):

  * `Enter` → toggles panel visibility
  * `Up/Down` → focus previous/next widget
  * `Left/Right` → adjust (± step)
  * `S` key / gamepad `Start` → **Save**
  * `R` key / gamepad `Back` → **Reset**

### 9.6 Editor Dock

* Runs in **tool mode**.
* Offers tree view + context menu:

  * Add Param / Group
  * Rename
  * Delete
* Bottom toolbar: Save Default, Import, Export, Revert, Validate.

---

## 10  Error Handling

| Condition                             | Result                                                                               |
| ------------------------------------- | ------------------------------------------------------------------------------------ |
| Missing or corrupt default preset     | Fatal error in editor; at runtime fall back to hard-coded NULL preset and log error. |
| Invalid user preset (schema mismatch) | Log warning, ignore offending entries, continue.                                     |
| Attempt to set value outside min/max  | Clamp and log once-per-param to avoid spam.                                          |
| Osc/Web path not found                | Reply with `/error "unknown_path"` and 404 respectively.                             |

---

## 11  Security Considerations

* Web dashboard off by default; must be enabled in *Project Settings*.
* When enabled, listen on `127.0.0.1` unless `allow_remote=true`.
* Require random 6-digit PIN for first remote connection if `allow_remote=true`.
* No file upload/download endpoints exposed.

---

## 12  Testing Strategy

### 12.1 Unit Tests (GUT)

| Area                 | Cases                                   |
| -------------------- | --------------------------------------- |
| Parameter.set\_value | clamp, signal emission, type coercion   |
| JSON round-trip      | to\_json → from\_json equality          |
| Merge logic          | default + user overrides                |
| Bind helper          | callable invoked initially & on change  |
| OSC Bridge           | send `/param/x` and verify root updated |

### 12.2 Integration Tests

* Launch headless Godot with SettingsManager, send OSC packets via Python, assert JSON state.
* Web dashboard e2e using Playwright: open page, move slider, assert WebSocket echo.

---

## 13  CI/CD

* GitHub Actions:

  * **Build matrix**: Linux, macOS, Windows.
  * Run GUT tests on each push.
  * Lint with `gdformat` + GDScript warnings as errors.
* Deploy `demo/` Web build to GitHub Pages on `main`.

---

## 14  Project Timeline (Indicative)

| Week | Deliverable                                   |
| ---- | --------------------------------------------- |
| 1    | Core data model + SettingsManager skeleton    |
| 2    | JSON persistence + unit tests                 |
| 3    | Editor dock MVP                               |
| 4    | In-game settings panel                        |
| 5    | OSC bridge complete                           |
| 6    | Web dashboard alpha                           |
| 7    | Performance & portability pass (HTML5/mobile) |
| 8    | Documentation, samples, v1.0 tag              |

---

## 15  Acceptance Criteria

1. Specified user stories U1-U5 pass manual QA on desktop export; U6 passes on local network.
2. Automated CI pipeline green (unit + integration tests).
3. `demo/parameter_toolkit_demo` runs in HTML5 export with default→user preset flow.
4. Memory leak scan (`--debug-leaks`) shows zero leaks after 1 h soak.
5. Performance benchmark: 10 k parameter load < 200 ms on RPi 4.

---

## 16  Deliverables

* `addons/parameter_toolkit/` source code
* JSON schema docs (`docs/schema.md`)
* Godot demo project
* README with getting-started & API reference
* Developer docs (`docs/dev_guide.md`) incl. migration guide
* CI configuration
* Test suite
* Change-log and semantic versioning starting at **v1.0.0**

---

### **End of Specification**
