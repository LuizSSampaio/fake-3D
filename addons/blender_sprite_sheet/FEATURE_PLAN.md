# Blender Sprite Sheet Addon Feature Plan

## Goal

Create a Godot 4.6 editor addon that imports or previews 3D assets, renders them from a user-defined camera setup, and exports the result as 2D sprite images or sprite sheets. The addon must support still models and animated models, render with a transparent background by default, and optionally let the user choose a solid background color.

## Target Users

The addon is for game developers and artists who want to convert 3D assets into 2D sprites without leaving the Godot editor. The main workflows are:

- Render one 3D model into a fixed set of 2D frames.
- Render an animation into a sprite sheet using a requested frame count.
- Preview camera angle, lighting, background, and animation timing before export.
- Export transparent sprites for direct use in 2D games.

## Supported Input Assets

Initial supported source formats:

- Godot scenes: `.tscn`, `.scn`
- Godot imported 3D assets: `.glb`, `.gltf`
- Common 3D formats imported through Godot: `.obj`, `.fbx`
- Blender files, when the local Godot editor import setup supports `.blend`

Implementation notes:

- The addon should rely on Godot's existing import pipeline wherever possible.
- Unsupported or failed imports must produce clear editor-facing errors.
- The renderer should operate on instantiated `Node3D` content, not on raw file parsing.

## Editor UI Specification

The addon should add a dock or editor panel named `Sprite Sheet Renderer`.

Required UI sections:

### Source

- Asset picker for a 3D scene or imported 3D resource.
- Reload button for refreshing the preview after source changes.
- Import status message area.

### Preview

- Embedded 3D preview viewport.
- Play/pause control for animations.
- Animation selector when the asset contains multiple animations.
- Timeline scrubber for previewing animation frames.
- Frame index indicator.

### Camera

- Camera position fields: `x`, `y`, `z`.
- Camera rotation fields: pitch, yaw, roll.
- Field of view control.
- Orthographic/perspective mode selector.
- Orthographic size control when orthographic mode is active.
- Button to frame the model automatically.
- Button to capture the current preview camera as the render camera.

### Render Settings

- Output frame width.
- Output frame height.
- Total frame count.
- Columns per sprite sheet row.
- Frame padding or spacing in pixels.
- Transparent background toggle, enabled by default.
- Background color picker, enabled only when transparent background is disabled or when the user explicitly wants a colored backdrop.
- Optional lighting preset selector.
- Optional model rotation controls for turntable-style sprite generation.

### Export

- Output path picker.
- Output format selector.
- Export button.
- Progress indicator.
- Export result summary with generated file paths.

## Output Formats

Required export formats:

- PNG sprite sheet with alpha.
- Individual PNG frames with alpha.

Planned export formats:

- WebP sprite sheet, if Godot runtime support is available.
- JPEG sheet for opaque background exports only.
- Metadata JSON containing frame rectangles, frame count, animation name, source asset path, and render settings.
- Godot `SpriteFrames` resource generation for direct use with `AnimatedSprite2D`.

PNG with transparency is the primary format and must be implemented first.

## Rendering Requirements

### Background

- The default render output must use a transparent background.
- The user must be able to disable transparency and choose a background color.
- Transparent exports must preserve alpha in the final image.
- The preview should visually indicate transparency with a neutral checkerboard or editor-safe background, while the actual render target keeps alpha.

### Camera

- The user must be able to set the camera position and rotation numerically.
- The preview must update when camera settings change.
- The export render must use the same camera configuration shown in preview.
- The addon should provide an automatic framing option based on the model bounding box.

### Frame Count

- The user must choose the amount of frames to render.
- For static models, the frame count can represent repeated still frames or optional turntable steps.
- For animated models, the frame count samples the selected animation evenly across the selected animation range.
- The first implementation should render frames from `0` to `frame_count - 1`.

### Animation

- If the asset has animations, the user must be able to select one.
- The selected animation must play in the preview.
- Export must sample the animation over its duration according to the requested frame count.
- The renderer must seek to the exact animation timestamp for each frame before capturing.
- Looping animations should include an option to avoid duplicating the first frame at the end of the cycle.

### Sprite Sheet Layout

- The user must choose or accept an automatically calculated column count.
- The addon must calculate rows from frame count and columns.
- Empty trailing cells in the sheet must remain transparent.
- Frame spacing must be supported.
- The generated sheet dimensions must be reported before export.

## Proposed Code Organization

Keep code inside `addons/blender_sprite_sheet/`.

Suggested files:

- `blender_sprite_sheet.gd`: small `EditorPlugin` entrypoint that creates and removes the dock.
- `sprite_sheet_renderer_dock.gd`: editor UI and workflow coordination.
- `sprite_sheet_preview.gd`: preview viewport, camera controls, animation playback.
- `sprite_sheet_capture.gd`: offscreen rendering and frame capture.
- `sprite_sheet_exporter.gd`: sprite sheet assembly and file output.
- `sprite_sheet_settings.gd`: resource or data object for render/export settings.
- `sprite_sheet_import_utils.gd`: helper functions for loading and validating source assets.

Lifecycle methods in the plugin entry script should stay small and delegate to these files.

## Rendering Pipeline

1. User selects a supported 3D asset.
2. Addon instantiates the asset into an isolated preview scene.
3. Addon detects meshes, bounds, available animations, and optional skeleton data.
4. User configures camera, frame count, background, output size, and export format.
5. Preview viewport reflects the current camera and animation state.
6. On export, addon creates or reuses an offscreen `SubViewport`.
7. For each frame:
   - Seek selected animation to the required timestamp.
   - Update scene and viewport.
   - Capture viewport texture as an `Image`.
   - Store the image as an individual frame.
8. Exporter assembles frames into the requested layout.
9. Exporter writes the sprite sheet, optional individual frames, and optional metadata.
10. Addon reports success or failure in the editor UI.

## Settings Data Model

The settings object should include:

- `source_path`
- `animation_name`
- `camera_position`
- `camera_rotation`
- `camera_projection`
- `camera_fov`
- `camera_orthographic_size`
- `frame_width`
- `frame_height`
- `frame_count`
- `columns`
- `frame_spacing`
- `transparent_background`
- `background_color`
- `output_path`
- `output_format`
- `export_individual_frames`
- `export_metadata`
- `avoid_duplicate_loop_frame`

Settings should be serializable later so users can save presets.

## Error Handling

The addon must show clear messages for:

- Missing or invalid source asset.
- Source asset cannot be instantiated as 3D content.
- No visible mesh found.
- Requested animation does not exist.
- Invalid frame count, frame size, output path, or format.
- Export path is not writable.
- Image encoding failed.

Errors should not leave preview nodes, temporary viewports, or generated partial state behind.

## Performance Requirements

- Large frame counts should show progress and allow cancellation.
- Export should avoid blocking the editor without feedback.
- Offscreen viewports and temporary nodes must be freed after export.
- The addon should avoid reimporting or reinstantiating the model unless the source asset or import settings change.

## Manual Validation Checklist

Run these checks before considering the feature complete:

- Enable and disable the addon from Project Settings without stale docks or nodes.
- Open the editor with `godot --editor`.
- Run the headless smoke check with `godot --headless --quit`.
- Load a static `.glb` or `.obj` model and export a transparent PNG sheet.
- Load an animated model and export a sheet with a specific frame count.
- Confirm alpha transparency in the exported PNG.
- Disable transparency, choose a background color, and confirm the exported image is opaque.
- Change camera position and confirm preview and export match.
- Export individual frames and verify file names are stable and ordered.
- Export metadata and verify frame rectangles match the sheet layout.

## Implementation Phases

### Phase 1: Editor Dock and Static Preview

- Add editor dock.
- Implement asset picker.
- Instantiate supported 3D scenes in a preview viewport.
- Add camera controls.
- Add transparent or colored preview background controls.

### Phase 2: Static Sprite Export

- Add output settings.
- Capture a still model from the configured camera.
- Export PNG sprite sheet and individual PNG frames.
- Add basic validation and error reporting.

### Phase 3: Animation Sampling

- Detect `AnimationPlayer` or compatible animation data.
- Add animation selector and playback controls.
- Seek animation by timestamp during export.
- Generate sprite sheets from the requested frame count.

### Phase 4: Export Metadata and Godot Integration

- Generate metadata JSON.
- Optionally generate `SpriteFrames` resources.
- Add reusable settings presets.
- Improve file naming and overwrite handling.

### Phase 5: Polish and Robustness

- Add cancellation support.
- Improve auto-framing.
- Add lighting presets.
- Add turntable rendering for static models.
- Add richer validation for import failures and unsupported assets.

## Open Decisions

- Whether the first UI should be a dock, bottom panel, or modal export wizard.
- Whether `.blend` support should require Blender installed and configured externally, or only support already imported Godot resources.
- Whether turntable rendering is required in the first release or should wait until after animation export.
- Whether metadata JSON should follow a common atlas format or a project-specific schema.
- Whether generated `SpriteFrames` resources should be required in the initial version.
