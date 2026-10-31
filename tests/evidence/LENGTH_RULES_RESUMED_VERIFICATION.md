# Resumed length-rule and chapter-preview verification

Godot 4.7.2 stable, Windows console binary, headless only. All paths below are relative to the project root. No GUI or rendered visual-quality claim is made.

| Script | Passed | Failed | Evidence |
| --- | ---: | ---: | --- |
| `tests/level01_length_rules_tests.gd` | 2029 | 0 | `tests/evidence/level01_length_rules_tests-resumed.log`, `tests/level01_length_rules_report.json` |
| `tests/level01_rules_tests.gd` | 327 | 0 | `tests/evidence/level01_rules_tests-resumed.log`, `tests/level01_rules_report.json` |
| `tests/chapter_learning_tests.gd` | 389 | 0 | `tests/evidence/chapter_learning_tests-resumed.log` |

The new length-rule suite exercises all 27 combinations of short/correct/long across the three representative joint groups. Every valid length can attach, all seven automatic members inherit their demonstration's length, and counters include attached members. Wrong lengths fail final inspection with exact unstable group/member lists. Each short/long group is withdrawn and corrected, preserving the fixed keel and rib/brace withdrawal dependencies. Additional coverage includes automatic seating order and provenance, partial withdrawal, pending interaction gates, duplicates, wrong types, unsupported lengths, invalid connection records, foundation recovery, reset, and independent state instances.

The existing rule suite retains its meaningful assertions. Its unsupported-length rejection list now contains only unsupported values; short and long installation behavior is covered by the new suite.

The chapter-learning suite preserves the prior introduction/classroom/source lifecycle checks and verifies three real model previews per chapter against the original catalog definitions and mesh resources, initial part positions/rotations, transparent isolated viewports, disabled viewport input, no preview assembly/input script methods, and unchanged preview/source state after classroom round trips. The standalone classroom still contains all nine original lessons.

Reproduction (PowerShell):

```powershell
$godot = 'C:\Users\27902\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$project = 'C:\Users\27902\Documents\Codex\2026-10-27\task\ship-level1'
foreach ($suite in @('level01_length_rules_tests', 'level01_rules_tests', 'chapter_learning_tests')) {
    & $godot --headless --path $project --script "res://tests/$suite.gd" --log-file "$project\tests\evidence\$suite-resumed.log"
}
```

Only `tests/` was edited by the delegated test task. Production rules, preview implementation, and second-chapter staged fixes were not edited. No remaining blocker was found in these suites.

## Integrated type and length UI regression

The requested five existing test scripts were then adapted to explicit neutral type/length selection and the inspector's chapter-classroom entry. All runs used the same Godot console executable with `--headless`. Evidence logs are in `tests/evidence/`:

| Script / phase | Passed | Failed | Log |
| --- | ---: | ---: | --- |
| `level01_input_tests.gd` | 687 | 0 | `level01_input_tests-length-integrated.log` |
| `level01_length_observation_tests.gd` | 662 | 0 | `level01_length_observation_tests-length-integrated.log` |
| `level01_inspector_tests.gd` | 143 | 0 | `level01_inspector_tests-length-integrated.log` |
| `level01_orbit_tests.gd` | 55 | 0 | `level01_orbit_tests-length-integrated.log` |
| `campaign_tests.gd -- --phase=level01` | 126 | 0 | `campaign-level01-length-integrated.log` |
| `campaign_tests.gd -- --phase=classroom` | 124 | 0 | `campaign-classroom-length-integrated.log` |

Input and length-observation pass counts include repeated assertions while actual insertion animations are running, so they may vary slightly with frame timing. The classroom script can merge results into a preexisting full campaign report; its log's `supplementary_classroom` object gives the 124 checks from this run, independent of the preexisting aggregate.

Coverage preserves the prior mouse/touch drag suppression, early-close animation gating, automatic order and provenance, undo/reset cancellation, wrong-type rejection, completion/reentry, camera orbit limits, focus loss, touch capture, and source-state preservation checks. New checks verify no default type or length; type alone cannot install; both choices survive observation reopen, type/length changes, and replay; each family exposes all three measured lengths with distinct physical meshes; real controller placement accepts wrong lengths and all auto members inherit them; the full wrong-length frame fails stability inspection and returns control; withdrawal/reset clear both choices. Long pieces animate to the shared length-specific seated pose without rotating their joint axes. The length ruler remains outside the draggable orbit region. Classroom navigation uses the inspector entry in chapter one and retains the original entry in chapters two and three.

No production defect, script parse error, or remaining blocker was found by these runtime suites. Rendered appearance and hardware input remain outside these headless claims.
