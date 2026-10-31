> 技术资料：描述现有模块或资料来源，不定义最新关卡需求或完成状态。最新要求与差异见[文档入口](../../../docs/README.md)（2026-10-31 整理）。

# Local planar force gallery

Eight local lessons, routed by the host's current catalog ID. The accepted
`classroom/science/dynamic/` dovetail remains separate and unchanged.

- `generate_profiles.py`: reads current catalog/OBJ only, extracts exact planar
  sections and orthographic triangles, records source SHA256. Run after intentional
  model changes, then run geometry and host tests. No Blender dependency.
- `profiles.json`: generated geometry, contacts, qualitative load paths and modes.
- `timeline.gd`: shared automatic 6-second load cycle, contact gating and reset.
- `pull_timeline.gd`: one blocked pull, contact hold, release and bounded return;
  6 seconds in plan. Zong uses its separate 13.2-second two-rail timeline.
- `pull_effects.gd`: orange outward arrows and source-normal blue reactions only.
- `diagram.gd`: planar drawing, fit, clipped short light bands; no scene cameras,
  physics bodies, assembly mutations, labels or numerical stress values.
- `presenter.gd`: `show_joint(id) -> bool`, `close()`,
  `lesson_visibility_changed(bool)`. Only the close icon is shown; load cases advance automatically. Closing stops
  advancement; reopening restarts. The host owns routing and input suspension.

Retained load cases play sequentially in one fixed picture (no manual switch):

| ID | First load | Following load |
| --- | --- | --- |
| blind_tenon | Downward tenon bearing | Inward blind-wall stop |
| through_tenon | Downward bearing through open mortise | — |
| cross_lap | Dark horizontal lower pulled +X; light upper fixed | Return, then light vertical upper pulled +Z; dark lower fixed |
| tongue_groove | Tongue bears on lower groove wall | — |
| three_way_lap | Horizontal member pulled +X; two actual oblique shoulders oppose the pull | — |
| zong_corner | X rail pulled outward +X; leg's long-tenon side blocks its socket wall | Z rail pulled outward +Z; short-tenon side blocks its corresponding socket wall |
| clamp_head | Apron bears on leg slot floor | — |
| l_through | Flat lower tenon bears in stepped mortise | — (no wedge) |

Zong uses `zong_diagram.gd`, `zong_timeline.gd` and the ID-specific
`zong_profile.py` builder. It stays in one continuous scene: whole corner,
gradual shell fade, exact section caps, X-rail pull and return, Z-rail pull
and return, gradual restoration, repeat.
Its front quadrant (x>.2 AND z>.2) is removed only in the educational drawing;
caps are extracted/triangulated from the actual OBJ sections. Long/short tenons,
matching mortise voids and diagonal shoulders remain in their original positions.
The unchanged orthographic projection, framing and part colors connect all stages.
No vertex morph, geometric stretching, exploded motion or scene swap is used.
A full zong presentation lasts 13.2 seconds. No force appears during shell
transitions. The long tenon starts at x=.4 and the socket wall at x=.38;
their side contact opposes +X. The rebuilt short tenon reaches Y=.76 and
starts at z=.4, meeting its socket wall initially at z=.38 to oppose +Z.
Both actual clearances close at .02 travel; no motion exceeds that stop.
The fixed leg and support coordinates stay anchored throughout both stages.
Only outward force and opposing reaction arrows appear; no contact dots,
pressure bands or other markers are used. The real model/profile coordinates
remain unchanged. `zong_display.gd` applies one fixed, strictly increasing
coordinate map to all three pieces after their real displacement, enlarging
the drawing's clearance and movement. Triangles split at map boundaries;
equal source contact points remain equal and separated interiors stay apart.
A pale gap window only fills the remaining section air and closes on contact.
The bounded return settling is also more visible. Targeted source
checks, actual host full-cycle results and rendered frames are recorded in
`.zong-reference-diagram-20261023/RESULTS.md`.

The three pull lessons display only this force opposition, with a brief blue
highlight on the real contact trace and no travelling load-path effect. Both lap
lessons retain exact (X,Z) top projection and upward-face depth ordering. Hidden
notches retain their source geometry. Cross-lap uses sequential lower +X and upper +Z pulls, each returning to its seated position before
the next stage. Each stage lasts 6 seconds; the full sequence lasts 12 seconds.
The fixed upper contacts X=-.42 in stage one (-X reaction); the fixed lower
contacts Z=-.42 in stage two (-Z reaction). Supports switch to the currently fixed
wood during the seated handover. +Z is screen vertical, distinct from the free +Y
assembly exit. Three-way lap uses the two physical oblique
surface normals; their sum opposes +X, rather than inventing a horizontal wall.

Only the loaded member translates; fixed members, support marks and picture
framing stay anchored. Source geometry, main camera, and assembly are unchanged.
Physical travel uses existing clearance: cross-lap lower X=0..+.020, upper Z=0..+.020,
three-way lower X=-.017..+.0172, zong X/Z rails each 0..+.02 along their own axis. Three-way's static
Y=-.0002 avoids exactly coincident bearing faces in the conservative continuous
triangle sweep; it has no Y animation or vertical force. This offset has zero
projection in the true plan view. The small return bounce remains inside each
verified interval. It is a qualitative tug/release, not computed elasticity.

Cross-lap alone exaggerates clearance in the educational drawing: the two slot
shoulders are drawn .12 further apart on each side and the .02 stroke is shown
as .14. The neck widths and final contact coordinates remain unchanged; continuous
sweeps validate both original solids and these display solids. A pale clearance
window distinguishes the slot floor from the wood. For the upper member's hidden
underside slot, dashed boundaries show this is a see-through clearance window,
not a hole cut through its top. Windows fade away before each handover. OBJ,
extracted profile vertices, collisions and real assembly are untouched.

These examples depend on the shown fixed-member boundary conditions. Cross-lap
can lift apart along its assembly axis, and the zong leg can withdraw along its
insertion path; the lesson makes no claim that every direction is locked.

These are qualitative load-path illustrations, not stress analysis, equilibrium
solutions, friction/glue/wedge models, strength promises or representations of
the application's permanent game lock. No removal/sliding/lift-off case is provided. No force magnitudes are computed. Orthographic overview
uses triangle depth sorting; a section is used where exact internal shape matters.

Validation: `.pull-force-review-20261023/` contains source-normal/contact checks,
continuous triangle sweeps in both directions and beyond each stop, full-cycle
timing and fixed-support checks, host natural loops, and actual renderer frames
at 1440x900 and 640x480. Its `RESULTS.md` records the current evidence.
`tests/force_profile_geometry.py` checks contacts and load-path samples
against original 3D OBJ, not just their projected outline. `tests/force_gallery_tests.gd`
exercises the actual host and Viewport input, lifecycle, four window sizes and
natural-time looping. Local engine screenshots and logs are in
`.force-local-20261023/`. Automated input/rendering is not human feel acceptance.

Current two-member cross-lap evidence: `.cross-lap-two-parts-20261023/RESULTS.md`.
The older `.cross-lap-merged-20261023/` and `.cross-lap-bidirectional-20261023/`
evidence describes the superseded same-member +/-X sequence.
