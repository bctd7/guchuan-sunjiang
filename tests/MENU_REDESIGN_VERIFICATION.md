# Directory visual redesign and welcome replay — 2026-11-18

The directory now uses three illustrated native Godot cards on a 1600×900 canvas, uniformly fitted to the viewport. Each card retains the existing `open_level` callback. Chapter loading, detachment, return/reset lifecycle, navigation visibility and next-chapter conditions are unchanged. Completion changes only the button caption. The ordinary directory hint is now empty; actual load errors remain visible. The requested top-right access note and bottom instruction are removed. Directory labels omit automatic pronunciation expansion to keep card headings within their layout; chapter reading support is unchanged.

The footer offers “重播欢迎片”. It reuses the startup video player in an overlay and retains the campaign instance and its dictionaries. Natural finish, skip, missing resource and decoder timeout use the existing exit path; replay mode emits a close signal instead of replacing the current scene. Ordinary startup still defaults to its original scene replacement. Duplicate replay is guarded. Background music pause/resume remains owned by the existing startup player.

Validation ran in `/private/tmp/guchuan-menu-ui`, isolated from project evidence and current local changes.

- Existing `campaign_loading_tests.gd`: 10 passed, 0 failed.
- Actual OpenGL UI rendering and injected pointer clicks: 1920×1080, 960×540, 1440×900; all three directory buttons entered their chapters and returned, no failures. Screenshots in `evidence/menu-redesign/`.
- Existing `campaign_reentry_tests.gd`: 146 passed, 1 failed (“operable GUI: 返回骨架”). The identical failure reproduced using the exact pre-change `campaign.gd`, with 146 passed / 1 failed. This is a pre-existing first-chapter inspector assertion, not a newly introduced directory regression. Both runs also emit existing exit resource warnings.
- `menu_replay_tests.gd`: 18 passed, 0 failed, with actual GPU video playback, natural `finished` signal, pointer skip/replay, duplicate invocation, missing-video fallback, retained completion state, audio preferences and subsequent chapter entry/return.

No gameplay assets, rules, assembly handlers or chapter scenes were changed for this task. Illustrations are decorative generated art, not captures of the playable models. Source/prompt: `assets/menu/README.md`.
