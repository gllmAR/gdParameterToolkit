# Parameter Toolkit for Godot 4.4

A reusable add-on that gives Godot 4.4 projects a parameter-centric workflow comparable to ofParameter + ofxGui in openFrameworks.

This repository only contains the add-on. See
[parameter-toolkit-demo](https://github.com/parameter-toolkit/parameter-toolkit-demo)
for the demonstration project.

## Features

- **Parameter-centric workflow**: Create and edit parameters in the editor with default presets
- **Live parameter editing**: Change values in real-time through in-game settings, OSC, or Web UI
- **Dual preset system**: Artist defaults (`res://settings/default.json`) + user overrides (`user://settings.json`)
- **Multiple control interfaces**: In-game panel, OSC messages, optional Web dashboard
- **Hot-reload support**: Immediate feedback when parameters change
- **Export/Import presets**: Share configurations as JSON files
- **A/B testing**: Quick switching between parameter sets
- **Type safety**: Supports float, int, bool, enum, color, and string parameters

## Installation

### Using the Asset Library

- Open the Godot editor.
- Navigate to the **AssetLib** tab at the top of the editor and search for
  "Parameter Toolkit".
- Install the
  [*Parameter Toolkit*](https://godotengine.org/asset-library/asset/ASSETLIB_ID)
  plugin. Keep all files checked during installation.
- In the editor, open **Project > Project Settings**, go to **Plugins**
  and enable the **Parameter Toolkit** plugin.

### Manual installation

Manual installation lets you use pre-release versions of this add-on by
following its `master` branch.

- Clone this Git repository:

```bash
git clone https://github.com/parameter-toolkit/parameter-toolkit.git
```

Alternatively, you can
[download a ZIP archive](https://github.com/parameter-toolkit/parameter-toolkit/archive/master.zip)
if you do not have Git installed.

- Move the `addons/` folder to your project folder.
- In the editor, open **Project > Project Settings**, go to **Plugins**
  and enable the **Parameter Toolkit** plugin.

## Usage

1. **Enable the plugin** and add the SettingsManager autoload
2. **Create parameters** using the Parameter Toolkit dock in the editor
3. **Save default preset** to ship with your project
4. **Bind to parameter changes** in your scripts:
   ```gdscript
   SettingsManager.bind("visual/brightness", _on_brightness_changed)
   ```
5. **Add settings panel** to your game for runtime adjustments
6. **Optional**: Enable OSC bridge or Web dashboard for remote control

See the [documentation](docs/) and [demo project](https://github.com/parameter-toolkit/parameter-toolkit-demo) for detailed usage examples.

## License

Copyright © 2024 Parameter Toolkit Contributors

Unless otherwise specified, files in this repository are licensed under the
MIT license. See [LICENSE.md](LICENSE.md) for more information.
