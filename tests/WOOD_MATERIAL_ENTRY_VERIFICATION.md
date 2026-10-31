> 历史验证证据：保留执行当时的结果与原路径，不作为最新需求或本轮重跑结果。最新要求与差异见[文档入口](../docs/README.md)（2026-10-31 整理）。

# Wood material campaign-entry verification — 2026-10-31

The user screenshot shows campaign -> chapter 1 -> Observe dovetail, not the standalone demo. Its visible grain matches the first material revision. The running Godot editor and game paths were verified as `/Users/bilibili/Documents/GitHub/guchuan-sunjiang`; the game was launched after that revision. This was not a different checkout or an unapplied first revision.

## Cause

- `ChapterWorkshop` shares the chapter World3D. Hiding the chapter does not unregister its WorldEnvironment. The classroom camera had no environment override, so the chapter environment won over the later classroom WorldEnvironment. The same entry rendered with a grey-green clear colour instead of the intended warm paper background.
- The first revision's 0.86–1.0 noise ramp was too restrained at the user's window size. Original OBJ files have no normal records, and their automatically smoothed display normals also made stock corners and cut faces look soft/plastic. Only the introduction previews previously repaired display normals.
- The first visual fixture exercised isolated classrooms, missing this campaign embedding difference.

## Correction

- Bind the classroom environment to its camera, keeping the source level environment intact.
- Share the same repaired, cached display mesh between classroom and introduction. Every original triangle position and order remains identical; collision shapes, collision guard, assembly state, input and mesh assets are unchanged. Only display normals and end-stock vertex colours change.
- Strengthen the longitudinal wood modulation to a 0.64/0.58/0.49–white ramp, sharpen triplanar blending, and tint transverse cut faces. Keep warm wood palette, matte StandardMaterial3D, and X-ray alpha behaviour.

## Evidence

`tests/wood_material_entry_visual.gd` enters the campaign, emits each actual lesson button, and captures all nine embedded classrooms, all nine transparent views, three introductions and three returned chapters. The before and after runs each produced 25 real Apple M1 OpenGL Compatibility GPU images using a minimized NO_FOCUS host; the host had no keyboard focus. No native desktop input or user's active window was used.

- `tests/evidence/wood-material-entry/dovetail-before-left-after-right.png`: same 1000 x 625 entry, before on left, after on right.
- `tests/evidence/wood-material-entry/nine-embedded-models-after.png`: actual embedded model crops, catalog order left to right, top to bottom.
- `before/report.json`, `after/report.json`: captured routes and environment probes.
- `pixel-comparison.json`: same-camera absolute RGB comparison restricted to mutual wood-colour pixels, excluding UI and paper backdrop. All nine specimens changed by a mean 24.5–40.0 RGB levels out of 255; this is an image-difference check, not a perceptual quality score.

Headless checks:

- `wood_material_tests.gd`: 217 passed, 0 failed; all 21 pieces, matching preview/classroom mesh/material, unchanged triangle positions, exact imported bounds and collision resources, X-ray restoration, all 12 movable pieces still insert and lock.
- `wood_material_entry_tests.gd`: 57 passed, 0 failed; real campaign embedding and level camera/environment/ship resources preserved on return across three chapters. Chapter 3's own source SubViewport is checked separately from the classroom viewport.
- `chapter_learning_tests.gd`: 410 passed, 0 failed.
- `drag_input_tests.gd`: 893 passed, 0 failed across all nine models and three camera views. The display mesh retains each original serialized surface AABB exactly: recomputing bounds from compressed decoded OBJ positions initially changed a symmetric pointer-picking tie; preserving the original surface bound eliminated that regression.
- `reset_baseline_tests.gd`: 1926 passed, 0 failed across four viewport shapes. Its existing output directory was created in the verification copy before running.

No commit or push. A game process launched before this correction continues to show its in-memory resources until restarted. The user's current game window is deliberately left running.
