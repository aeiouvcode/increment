# Increment - handoff

Source recovered 2026-09-24 from live index.pck (main 0ec14ce) with GDRE Tools 2.6.4. Build: Godot 4.7.2, web nothreads template.
Export: `godot --headless --export-release Web build/web/index.html`, then split index.wasm into index.wasm.part0/part1 (20,000,000 B) and use play.html shell from the live repo (update fileSizes).

## Branch refine-1 (not deployed)
- Title: station fills the screen above the start card, no grey dim, no empty band; cupola window capped to width; Earth texture linear + mipmaps (was pixelated).
- Clock holds at 06:00 each day until the first Begin (was already 8+ min late on arrival at 4x). Header shows CLOCK STARTS WHEN YOU BEGIN.
- First activity is active at day start (removed odd "Ahead of plan, in 0 min" state).
- msaa_2d off (unsupported on GLES3 web; removed console error spam, no visual change).
