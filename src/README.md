# Increment - Godot source (branch refine-1, not deployed)

Godot 4.7.2 project for the web build on main. Recovered 2026-09-24 from the live build, then refined (see HANDOFF.md).

Fonts are not in this branch (binary). Put IBM Plex Sans (Regular, Medium, SemiBold) and IBM Plex Mono (Regular, Medium) TTFs in `src/fonts/`. They're under the SIL Open Font License: https://github.com/IBM/plex

Build: `godot --headless --export-release Web build/web/index.html`
