# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.6 project focused on an editor addon. The active addon lives in `addons/blender_sprite_sheet/`.

- `addons/blender_sprite_sheet/plugin.cfg` declares the addon metadata and entry script.
- `addons/blender_sprite_sheet/blender_sprite_sheet.gd` contains the `EditorPlugin` implementation.
- `addons/blender_sprite_sheet/*.uid` files are Godot-generated resource IDs; keep them with their matching resource.
- `tests/` contains gdUnit4 test suites for addon behavior.
- `project.godot` enables the plugin for local development, but it is currently ignored by Git.

Add new addon code beside the existing plugin script unless it is shared across multiple plugins. Use clear feature-oriented names such as `sprite_sheet_importer.gd`.

## Build, Test, and Development Commands

Use the Godot editor for interactive development:

```sh
godot --editor
```

Run a headless project check before submitting changes:

```sh
godot --headless --editor --quit
```

Run the automated gdUnit4 suite in quiet headless mode:

```sh
godot --headless --quiet --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
```

That command should be the default test command for routine validation because it avoids opening a Godot window. It intentionally produces little or no output on success; rely on the process exit code. If you need failure details while debugging, remove `--quiet`.

This repository is an editor-addon project and currently has no main scene, so `godot --headless --quit` exits with `Can't run project: no main scene defined in the project` and does not validate plugin startup. Use the headless editor command above to compile tool scripts and initialize enabled editor plugins.

For focused addon workflow checks, run a temporary `SceneTree` script through the headless editor, for example:

```sh
godot --headless --editor --script /tmp/check_sprite_sheet_dock.gd
```

That style is useful for loading a fixture such as `res://SO_Book_01.fbx`, instantiating `sprite_sheet_renderer_dock.gd`, and checking source loading, camera framing, or material override behavior without opening the interactive editor.

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

gdUnit4 is the automated test framework for this project. Add new GDScript test suites under `tests/` with `extends GdUnitTestSuite`, mirroring the addon feature under test. Prefer tests that create small in-memory scenes, meshes, materials, or temporary resources over tests that depend on large imported fixtures.

Run the quiet headless gdUnit4 command above before submitting changes. Also run `godot --headless --editor --quit` when changing plugin startup, shutdown, tool scripts, or editor-only UI because the gdUnit4 runner validates addon behavior outside the editor dock lifecycle. When changing plugin startup or shutdown behavior, verify enabling and disabling the addon from Project Settings does not leave stale autoloads, editor UI, or resources behind.

When testing imported 3D assets, remember that formats such as FBX can import at very small scales or without embedded materials/textures. Prefer checking the instantiated `Node3D` content, mesh bounds, preview framing, and explicit material/texture override paths instead of assuming the raw imported scene is already camera-ready.

## Commit & Pull Request Guidelines

The current history only contains `Initial Commit`, so no strict commit convention is established. Use short, imperative commit subjects such as `Add sprite sheet importer` or `Fix plugin shutdown cleanup`.

Pull requests should include a concise summary, manual test steps, and screenshots or screen recordings for editor UI changes. Link related issues when available and call out any Godot version assumptions.
