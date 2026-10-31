# 结构科普：独立、只读、定性显示层

## What is delivered

All nine catalog joints and all 12 movable parts have educational profiles. This is a **qualitative geometric explanation**, not a stress simulation, load-capacity analysis, equilibrium solution, full free-body diagram, or archaeological reconstruction.

- Orange solid arrow: a hypothetical applied force direction (F?), not measured force.
- Cyan surface: a **potential bearing face** extracted and clipped from the real imported mesh. It is not a heatmap. Existing model gaps mean this is not proof of current contact or pressure.
- Red dashed arrow plus stop bar: direction resisted after clearance closes.
- Green dashed arrow: geometrically permissible direction under stated assumptions, not a force.
- Force and motion arrows are hidden until the observed part and its dependencies are in their exact assembled poses. Candidate faces may be inspected while separated.
- Three-way lap middle-piece withdrawal is conditional on removing the upper member. With that member seated, its arrow stays red, not green.
- Runtime does not move wood, change states, invoke insertion, alter collision, set transparency, or create cross-sections. The round's permanent lock is explicitly explained as a game rule, not physical anti-withdrawal evidence.

## Integration contract

Mount `presenter.gd` as a **sibling**, not a child, of the assembly. `load_definition` deletes assembly children.

```gdscript
const SciencePresenter = preload("res://education/presenter.gd")
var science = SciencePresenter.new()
add_child(science)
science.configure(assembly)
var science_panel = science.create_panel()
# Add this ordinary Control to host CanvasLayer/layout, top right.
ui_root.add_child(science_panel)
```

The panel is collapsed by default (`结构科普`), 300 px minimum width, no full-screen input rectangle. Host is responsible for top-right anchoring, responsive margins and avoiding overlap with other controls. Expanded body has three independently switchable layers, two cases, and scrollable concise explanation. Existing wood transparency remains controlled by the existing assembly UI.

API:
- `configure(assembly: Node3D)` subscribes once to `changed` and disconnects a previous source.
- `set_enabled(bool)`; `set_layer("force"|"contact"|"motion", bool)`; `set_case(0|1)`.
- `create_panel() -> Control`; `summary() -> String`.
- `display_changed` updates presentation only.
- Reads `definition`, `specs`, `parts`, `selected`, `assembled_pose(id)` and `changed`. Does not depend on game-state string names or insert speed.
- Coordinates originate in assembly/model space; sibling follows assembly global transform. Face patches follow actual part transforms.

No hard-coded plate is drawn over a mortise hole: `contact_geometry.gd` selects actual coplanar mesh triangles and clips each triangle against the profile's bounds. A 0.003 model-unit offset avoids z-fighting. Normal depth testing stays enabled. Hidden surfaces remain occluded until the user deliberately uses the existing transparency view. Annotated areas are representative, not every possible contact.

## Independent review scene

Run `res://education/demo.tscn`. Pick a joint / movable part, expand `结构科普`, switch cases or layers. “全部置于到位姿态” is an explicit review fixture, not gameplay. “恢复分离姿态” must hide force/motion arrows. Existing transparency toggle exposes interior candidates without cuts.

## Automated checks

```sh
HOME=/tmp/joinery-education-home \
XDG_DATA_HOME=/tmp/joinery-education-home \
XDG_CACHE_HOME=/tmp/joinery-education-home \
godot --headless --path /workspace/shared/joinery-manual-upgrade \
  --script res://education/test_education.gd
```

Tests cover nine profiles, 12 movable parts, 16 nonempty mesh-derived patches, plane fidelity, nearby opposing actual mesh surface at each patch triangle centroid (within 0.065 model units), separated/assembled gating, conditional stacked withdrawal, both cases, independent layer switches, immutability of transforms/states, coordinate mapping, clearing overlays, and explicit scientific/archaeological caveats. See `test_results.txt` for actual final assertions.

Standalone scene compilation and startup tested headlessly. **Pixel-level visual QA is not claimed here**: this execution environment has no display server. Host integration, responsive positioning, visual legibility and exact occlusion should be reviewed in an interactive Godot run. No full application regression claim is made by these focused tests.

## Scope and sources

Primary geometry evidence: `models/generate_models.py`, `models/catalog.json`, actual `models/assets/*.obj` / Godot Mesh faces. Our model-specific allowed/resisted directions are geometric inferences from those files, not sourced historical facts. In particular, the present dovetail is an open-ended constant-section sliding dovetail; the L-shaped through member has no wedge; the zong corner is an expressly simplified dual-straight-tenon variant.

Primary explanatory references, accessed 2026-10-22:

1. OpenStax, University Physics vol. 1, **Common Forces**: normal contact force is perpendicular to the contact surface. https://openstax.org/books/university-physics-volume-1/pages/5-6-common-forces
2. OpenStax, University Physics vol. 1, **Friction**: friction is tangential and depends on contact conditions; no coefficient or friction capacity is inferred for these meshes. https://openstax.org/books/university-physics-volume-1/pages/6-2-friction
3. University of Melbourne, MSD Machine Workshop, **Dovetail joint**: the direction of loading and orientation of joint members matter. This reference concerns drawer-type dovetails, not evidence that the present open sliding slot blocks axial withdrawal. https://ms-kb.msd.unimelb.edu.au/machine-workshop/making/step-by-step/joining/dovetail-joint
4. Metropolitan Museum of Art (indexed source excerpt checked; full PDF retrieval exceeded the web tool size limit), **A Chinese Garden Court**: broader furniture/architectural mortise-and-tenon context, not proof that each of these models was used in ancient ships. https://resources.metmuseum.org/resources/metpublications/pdf/A_Chinese_Garden_Court.pdf

Catalog links to standards and cultural references are retained upstream but not independently authenticated as archaeological evidence in this task. No assertion that all nine are actual ancient ship joints is made.

## Files / ownership

Everything authored here is under `education/`: profiles and authoring helper, contact triangle extraction, presenter, opt-in panel, standalone review scene, tests and report. No core, model, interaction, workshop or project configuration is modified by this science-display task.
