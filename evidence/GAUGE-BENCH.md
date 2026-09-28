# Increment gauge redraw replay

Source: approved public release `db3d2ea`; experimental branch only, not deployed.

The existing gauge `_process` submitted a full repaint every frame even when the four displayed values did not change. The new visual signature includes rounded displayed digits, threshold warning colors, integer bar pixel widths and control width. It requests a repaint when any changes. `src/tests/gauge_redraw.gd` asserts no repeated stationary draws, plus draw after CO2, battery, urine, O2 and resize changes.

Command: from `src/`, run `GAUGE_DYNAMIC=0 /path/to/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script tests/gauge_bench.gd` and repeat with 1. Before: 240 draws / 240 frames stationary and drifting. After: 1 / 240 stationary (99.58% fewer draw submissions) and 6 / 240 drifting (97.5% fewer). Wall time was ~1.642 seconds in all four runs, so there is no measured frame-time or FPS gain from this headless test. Physical phone remains unverified. Other headless tests `autoplay.gd`, `flow.gd`, `summary_card.gd`, `gauge_redraw.gd` passed after restoring four IBM Plex TTFs from IBM/plex (SIL OFL); fonts are local test dependencies excluded from this patch because the upstream repo intentionally does not carry them.

Failure-path review: warning thresholds and resize trigger redraw; `sim == null` skips it until assigned. We have not claimed an exact full-frame rendering improvement or device-level speedup. Critic: 7.5/10 for focused, tested reduction of redundant work; deductions for missing device proof and absence of FPS improvement.
