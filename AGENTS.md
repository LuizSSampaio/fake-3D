# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.6 project focused on an editor addon. The active addon lives in `addons/blender_sprite_sheet/`.

- `addons/blender_sprite_sheet/plugin.cfg` declares the addon metadata and entry script.
- `addons/blender_sprite_sheet/blender_sprite_sheet.gd` contains the `EditorPlugin` implementation.
- `addons/blender_sprite_sheet/*.uid` files are Godot-generated resource IDs; keep them with their matching resource.
- `project.godot` enables the plugin for local development, but it is currently ignored by Git.

Add new addon code beside the existing plugin script unless it is shared across multiple plugins. Use clear feature-oriented names such as `sprite_sheet_importer.gd`.

## Build, Test, and Development Commands

Use the Godot editor for interactive development:

```sh
godot --editor
```

Run a headless project check before submitting changes:

```sh
godot --headless --quit
```

If your Godot binary has a version suffix, use it consistently, for example `godot4 --editor`.

There is no separate build system in this repository. Export presets are ignored, so local export settings should not be committed unless the project policy changes.

## Coding Style & Naming Conventions

Write GDScript using Godot conventions:

- Use tabs for indentation in `.gd` files.
- Use `snake_case` for functions, variables, and file names.
- Use `PascalCase` for class names when adding `class_name`.
- Keep lifecycle methods such as `_enter_tree()`, `_exit_tree()`, `_enable_plugin()`, and `_disable_plugin()` small and delegate feature logic to helper functions or separate scripts.

Text files are normalized to LF line endings through `.gitattributes`. Keep files UTF-8 encoded, matching `.editorconfig`.

## Testing Guidelines

No automated test framework is configured yet. For now, validate addon changes manually in the Godot editor and run the headless smoke check above. When changing plugin startup or shutdown behavior, verify enabling and disabling the addon from Project Settings does not leave stale autoloads, editor UI, or resources behind.

If tests are added later, place them in a predictable `tests/` directory and document the runner command here.

## Commit & Pull Request Guidelines

The current history only contains `Initial Commit`, so no strict commit convention is established. Use short, imperative commit subjects such as `Add sprite sheet importer` or `Fix plugin shutdown cleanup`.

Pull requests should include a concise summary, manual test steps, and screenshots or screen recordings for editor UI changes. Link related issues when available and call out any Godot version assumptions.
