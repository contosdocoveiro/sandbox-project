<!-- fennara-agents-start -->
# Fennara MCP Guidelines

This project uses Fennara MCP for Godot-aware inspection, editing, runtime error capture, diagnostics, scene validation, screenshots, and project settings.

When working on Godot-specific files or behavior, always read `addons/fennara/ai/guidelines.md` first. This includes work involving `.tscn`, `.tres`, `.res`, `.gd`, `.cs`, `.gdshader`, `project.godot`, scenes, nodes, resources, shaders, project settings, gameplay, UI, animation, rendering, Fennara addon behavior, or Fennara MCP behavior.

For specialized visual, runtime, operational, or client-specific work, use `addons/fennara/ai/index.md` to find the one relevant page. Do not read every linked page by default. Live tool schemas define exact calls and results.
<!-- fennara-agents-end -->

## GDScript syntax and API reference

Do not answer Godot API or GDScript syntax questions from memory. Check the local mirror first:

- **Exact API for this engine build (4.7.2):** `N:\program-dungeon\tools\godot-docs\api\classes\<Class>.xml` — methods, signatures, properties, signals, constants.
- **Official 4.7 docs as text:** `N:\program-dungeon\tools\godot-docs\text\` (GDScript rules under `tutorials\scripting\gdscript`).
- **Verified syntax samples:** `N:\program-dungeon\tools\godot-docs\snippets\4.7\` — each file states a claim and is parse-checked by the installed engine.
- **Parse-check changed scripts:** `powershell -File N:\program-dungeon\tools\godot-docs\check-gd.ps1 -Project . <file.gd>` — catches syntax and static type errors with line numbers.

If a syntax form is not covered by a snippet, add one and run `verify-snippets.ps1` before using it in project code. The `teste-(4.6)` copy must be checked against 4.6, not this 4.7 mirror.

