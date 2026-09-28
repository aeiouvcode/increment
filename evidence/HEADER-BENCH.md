# Increment header update gate

On the prior local gauge checkpoint `1424018`, `main.gd:_process` rewrote three header labels every frame, even with the simulation clock held. The change tracks only the fields rendered in the header: day, integer clock minute, ceil minutes to orbital terminator, day/night state, and held-clock state. The existing `_header` remains unchanged and runs when one of those fields changes.

`tests/header_probe.gd` instantiates a test subclass that counts `_header()` calls for 240 held-clock frames. Baseline: 240 calls; optimized: 0 calls (the initial header is populated before the measurement). Three headless repetitions on each were 240/240/240 baseline and 0/0/0 optimized. Total elapsed over those 240 frame-paced iterations remained ~1.649-1.660 s, so no measured FPS gain. `tests/header_redraw.gd` asserts exact label changes for clock minute, hold/release, day change and a time jump, plus no redundant calls when held. Existing autoplay, flow, summary-card and gauge redraw tests pass with four IBM Plex TTFs loaded as local test dependencies; fonts are not included in this commit. No browser or device-level performance claim.

Critic: 7.5/10 for removing redundant label updates while preserving transitions; no demonstrated frame-rate improvement or physical-phone GPU test.
