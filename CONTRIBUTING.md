# Guidelines for contributing

Thanks for your interest in contributing! Before contributing, be sure to know
about these few guidelines:

- Follow the
  [GDScript style guide](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_styleguide.html).
- Use [GDScript static typing](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/static_typing.html) whenever possible.
  - Also use type inference whenever possible (`:=`) for more concise code.
- Make sure to update the changelog for any user-facing changes, keeping the
  [changelog format](http://keepachangelog.com/en/1.0.0/) in use.
- Don't bump the version yourself. Maintainers will do this when necessary.

## Design goals

This add-on aims to:

- Provide a parameter-centric workflow comparable to ofParameter + ofxGui in openFrameworks
- Enable fast iteration for creative coders and artists with minimal boilerplate
- Support live parameter editing through multiple interfaces (GUI, OSC, Web)
- Maintain clean separation between default (artist) and user presets
- Offer plug-and-play integration (copy to addons/, enable plugin, add autoload)
- Ensure deterministic state and reproducible configurations for QA
- Support remote tweaking for exhibition and installation scenarios

## Non-goals

For technical or simplicity reasons, this add-on has no plans to:

- Support parameter types beyond float, int, bool, enum, color, and string
- Provide complex GUI layout systems (focus is on auto-generated interfaces)
- Include advanced networking features beyond OSC and basic Web dashboard
- Support parameter animation or tweening (use Godot's Tween nodes instead)
- Implement complex access control or multi-user collaboration features
- Support real-time synchronization across multiple game instances
