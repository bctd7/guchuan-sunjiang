#!/usr/bin/env python3
"""Curated Godot regressions. Run on a working copy: fixtures write res:// reports.
Headless groups inject Godot events; they do not claim human hardware or GPU QA.
Visual is opt-in and uses only no-focus/minimized fixtures.
"""
import argparse
import datetime
import json
import os
import re
import hashlib
import shutil
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time

GROUPS = {
    'core': [('tests/' + x + '.gd', []) for x in ['run_tests', 'collision_tests', 'drag_input_tests', 'camera_tests']],
    'levels': [('tests/' + x + '.gd', []) for x in ['touch_gesture_tests', 'continuation_matrix_tests', 'opening_dimensions_tests', 'opening_navigation_tests', 'wood_grab_tests', 'drag_consistency_tests', 'three_group_tests', 'level01_rules_tests', 'level01_length_rules_tests', 'level01_trial_rules_tests', 'level01_input_tests', 'level01_orbit_tests', 'level01_inspector_tests', 'bulkhead_story_visual', 'level02_rules_tests', 'level02_assembly_outcome_tests', 'level02_contact_geometry_tests', 'boat_joint_geometry_tests', 'starter_joint_tests', 'starter_lock_geometry_tests', 'receiving_edge_tests', 'boat_joint_sweep_tests', 'boat_joint_recovery_tests', 'level02_plank_sequences_tests', 'boat_joint_interaction_tests', 'boat_joint_loose_tests', 'boat_joint_motion_tests', 'first_join_tests', 'starter_lock_tests', 'plank_context_tests', 'continuable_joint_tests', 'level02_wave_outcome_tests', 'level02_geometry_tests', 'opening_geometry_tests', 'hull_wood_normals_tests', 'timber_rendering_tests', 'level02_alignment_geometry_tests', 'level02_structure_geometry_tests', 'level02_structure_tests', 'observation_repeat_tests', 'repeat_lifecycle_tests', 'level02_alignment_tests', 'level02_clarity_zoom_tests', 'sea_trial_presentation_tests', 'stock_clearance_tests', 'trial_contact_tests', 'level02_wrong_type_tests', 'inspection_workspace_tests', 'level02_input_tests', 'level02_drag_tests', 'auxiliary_panel_tests', 'level03_geometry_tests', 'level03_input_tests', 'shipwright_story_tests', 'level01_failure_tests']],
    'classroom': [('tests/' + x + '.gd', []) for x in ['chapter_learning_tests', 'wood_material_entry_tests', 'chinese_font_tests', 'dynamic_integration_tests', 'force_gallery_tests', 'force_sequence_tests']] + [('classroom/science/test_education.gd', []), ('classroom/science/dynamic/test_dynamic.gd', [])],
    'campaign': [('tests/campaign_tests.gd', ['--phase=full']), ('tests/campaign_tests.gd', ['--phase=classroom']), ('tests/campaign_reentry_tests.gd', []), ('tests/campaign_loading_tests.gd', [])],
    'visual': [('tests/wood_material_entry_visual.gd', []), ('tests/level01_failure_visual.gd', []), ('tests/seven_stars_visual.gd', []), ('tests/bulkhead_story_visual.gd', [])] + [('tests/' + x + '.gd', ['--gpu']) for x in ['touch_gesture_tests', 'continuation_matrix_tests', 'opening_dimensions_tests', 'opening_navigation_tests', 'wood_grab_tests', 'drag_consistency_tests', 'three_group_tests', 'boat_joint_interaction_tests', 'boat_joint_loose_tests', 'boat_joint_motion_tests', 'first_join_tests', 'starter_lock_tests', 'plank_context_tests', 'continuable_joint_tests', 'inspection_workspace_tests', 'level02_wrong_type_tests', 'level02_drag_tests', 'auxiliary_panel_tests','level02_clarity_zoom_tests','level02_alignment_tests','level02_structure_tests','observation_repeat_tests','repeat_lifecycle_tests']],
}

VISUAL_REPORTS = {
    'touch_gesture_tests': 'tests/evidence/touch-gestures/gpu.json',
    'continuation_matrix_tests': 'tests/evidence/unified-fit/continuation-gpu.json',
    'opening_dimensions_tests': 'tests/evidence/direct-comparison/dimensions-gpu.json',
    'opening_navigation_tests': 'tests/evidence/comparison-navigation/gpu.json',
    'wood_grab_tests': 'tests/evidence/three-groups/grabs-gpu.json',
    'three_group_tests': 'tests/evidence/three-groups/gpu.json',
    'drag_consistency_tests': 'tests/evidence/three-groups/drag-gpu.json',
    'plank_context_tests': 'tests/evidence/plank-context/gpu.json',
    'starter_lock_tests': 'tests/evidence/starter-lock/gpu.json',
    'continuable_joint_tests': 'tests/evidence/continuable-joints/gpu.json',
    'first_join_tests': 'tests/evidence/first-join/gpu.json',
    'boat_joint_motion_tests': 'tests/evidence/joint-motion/gpu.json',
    'boat_joint_loose_tests': 'tests/evidence/boat-joint-redesign/loose-gpu.json',
    'boat_joint_interaction_tests': 'tests/evidence/boat-joint-redesign/gpu.json',
    'repeat_lifecycle_tests': 'tests/evidence/observation-repeat/lifecycle-gpu.json',
    'observation_repeat_tests': 'tests/evidence/observation-repeat/gpu.json',
    'level02_structure_tests': 'tests/evidence/hull-structure/gpu.json',
    'wood_material_entry_visual': 'tests/evidence/wood-material-entry/report.json',
    'level01_failure_visual': 'tests/evidence/whole-level-failure-r8/visual/report.json',
    'seven_stars_visual': 'tests/evidence/seven-stars/report.json',
    'bulkhead_story_visual': 'tests/evidence/bulkhead-story/gpu-report.json',
    'inspection_workspace_tests': 'tests/evidence/inspection-workspace/gpu.json',
    'level02_wrong_type_tests': 'tests/evidence/level02-late-fit/gpu.json',
    'level02_drag_tests': 'tests/level02_drag_gpu_report.json',
    'auxiliary_panel_tests': 'tests/evidence/chapter-tools/gpu.json',
    'level02_clarity_zoom_tests': 'tests/evidence/clarity-zoom/gpu.json',
    'level02_alignment_tests': 'tests/evidence/alignment/gpu.json',
}


def classify_log(text, code, importing=False):
    """Fail script AND engine errors; retain narrowly identified environment warnings."""
    if 'SCRIPT ERROR:' in text or 'Parse Error:' in text:
        return 'script_error', []
    warnings, errors = [], []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if not line.startswith('ERROR:'):
            continue
        certificate = line == 'ERROR: Condition "ret != noErr" is true. Returning: ""' and index+1 < len(lines) and 'get_system_ca_certificates (platform/macos/' in lines[index+1]
        editor_settings = importing and 'editor_settings-4.' in line and (
            line.startswith('ERROR: Cannot save file ') or line.startswith('ERROR: Error saving editor settings to '))
        (warnings if certificate or editor_settings else errors).append(line)
    if errors:
        return 'engine_error', warnings
    return ('passed' if code == 0 else 'failed'), warnings


def fingerprint(path):
    if not path.is_file():
        return None
    return (path.stat().st_mtime_ns, hashlib.sha256(path.read_bytes()).hexdigest())


def validate_visual_report(path, before):
    if not path.is_file() or fingerprint(path) == before:
        return 'report_missing_or_stale'
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return 'invalid_report'
    if data.get('failed') != 0 or data.get('failures'):
        return 'fixture_failed'
    if data.get('renderer') in (None, 'headless'):
        return 'wrong_renderer'
    if data.get('host_had_focus') or data.get('host_focus_reported'):
        return 'gpu_focus_error'
    if data.get('host_minimized') is False or data.get('no_focus_flag') is False or data.get('no_focus') is False:
        return 'gpu_focus_error'
    if not any(key in data for key in ['host_had_focus', 'host_focus_reported', 'no_focus_flag', 'no_focus']):
        return 'gpu_focus_unverified'
    return 'passed'


def command_for(engine, project, script, extra, visual, engine_log, platform=None):
    platform = platform or sys.platform
    flags = ['--minimized', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy'] if visual else ['--headless']
    arguments = ['--path', str(project)] + flags + ['--log-file', str(engine_log), '--script', script] + (['--'] + extra if extra else [])
    if visual and platform == 'darwin':
        # LaunchServices creates an independent, background app instance. open's exit
        # code is NOT Godot's exit code, so every visual job must emit a fresh report.
        binary = Path(shutil.which(engine) or engine).resolve()
        app = binary.parent.parent.parent
        if app.suffix != '.app' or not app.is_dir():
            raise ValueError('macOS GPU jobs require a Godot binary inside a .app bundle')
        return ['open', '-g', '-n', '-W', '-a', str(app), '--args'] + arguments
    return [engine] + arguments


def terminate_owned_gpu(engine, project, engine_log):
    """Only stop our exact binary/project/unique log combination, never other windows."""
    stopped = []
    try:
        listing = subprocess.check_output(['ps', '-axo', 'pid=,command='], text=True)
        expected_binary = str(Path(shutil.which(engine) or engine).resolve())
        for line in listing.splitlines():
            pid_text, _, command = line.strip().partition(' ')
            command = command.lstrip()
            # ps does not quote argv containing spaces. Match the exact binary
            # and complete unique flag values rather than splitting that text.
            if not command.startswith(expected_binary + ' '):
                continue
            owns_project = '--path ' + str(project) + ' ' in command
            owns_log = '--log-file ' + str(engine_log) + ' ' in command
            if owns_project and owns_log:
                os.kill(int(pid_text), signal.SIGTERM)
                stopped.append(int(pid_text))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        return {'stopped': stopped, 'error': str(error)}
    return {'stopped': stopped}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--godot', default=os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--group', action='append', choices=list(GROUPS) + ['all'])
    parser.add_argument('--case', action='append', help='Select registered script stems or paths within the chosen groups; repeatable')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--skip-import', action='store_true')
    parser.add_argument('--user-data-name', help='Temporary project only: write a NEW override.cfg with an isolated native Godot user-data name; refuses existing override')
    parser.add_argument('--allow-visual', action='store_true', help='Explicitly allow minimized, no-focus GPU fixtures')
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args()
    groups = args.group or ['all']
    if 'all' in groups:
        groups = list(dict.fromkeys(['core', 'levels', 'classroom', 'campaign'] + [g for g in groups if g != 'all']))
    if 'visual' in groups and not args.allow_visual and not args.list:
        parser.error('visual requires --allow-visual; all excludes visual')
    jobs = [(g, script, extra) for g in groups for script, extra in GROUPS[g]]
    if args.case:
        selected = {Path(name).stem for name in args.case}
        unknown = selected - {Path(script).stem for _, script, _ in jobs}
        if unknown:
            parser.error('cases not registered in selected groups: ' + ', '.join(sorted(unknown)))
        jobs = [job for job in jobs if Path(job[1]).stem in selected]
    if args.list:
        for group, script, extra in jobs:
            print(group, script, *extra)
        return 0
    project = args.project.resolve()
    if not (project / 'project.godot').is_file():
        parser.error('project.godot not found in --project')
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='guchuan-suite-'))
    output.mkdir(parents=True, exist_ok=True)
    if args.user_data_name:
        if not args.user_data_name.replace('-', '').replace('_', '').isalnum():
            parser.error('user-data-name must contain letters, digits, - or _')
        override = project / 'override.cfg'
        if override.exists():
            parser.error('refusing to replace existing override.cfg')
        override.write_text('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + args.user_data_name + '"\n')
        print('Temporary-project override retained:', override, flush=True)
    # XDG isolates user data on supported platforms. macOS may still use its native user-data directory; run in an appropriately permitted environment.
    env = dict(os.environ)
    env['XDG_DATA_HOME'] = str(output / 'user-data')
    env['XDG_CACHE_HOME'] = str(output / 'cache')
    report = {'project': str(project), 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'groups': groups, 'results': []}

    def run(name, command, visual_report=None, engine_log=None):
        start = time.monotonic()
        log = output / (name + '.log')
        before = fingerprint(visual_report) if visual_report else None
        cleanup = None
        with log.open('w') as stream:
            try:
                result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, env=env, timeout=args.timeout, check=False)
                code, status = result.returncode, 'passed'
            except subprocess.TimeoutExpired:
                code, status = None, 'timeout'
                if visual_report:
                    cleanup = terminate_owned_gpu(args.godot, project, engine_log)
            except OSError as error:
                stream.write(str(error))
                code, status = None, 'launch_error'
        text = log.read_text(errors='replace')
        if engine_log and engine_log.is_file():
            text += '\n' + engine_log.read_text(errors='replace')
        warnings = []
        if status == 'passed':
            status, warnings = classify_log(text, code, importing=name == 'import')
        if status == 'passed' and visual_report:
            status = validate_visual_report(visual_report, before)
            if status == 'passed':
                shutil.copyfile(visual_report, output / (name + '-report.json'))
        row = {'name': name, 'status': status, 'exit_code': code, 'seconds': round(time.monotonic()-start, 2), 'log': str(log), 'engine_log': str(engine_log) if engine_log else None, 'command': command, 'environment_warnings': warnings}
        if cleanup is not None:
            row['timeout_cleanup'] = cleanup
        report['results'].append(row)
        (output / 'summary.json').write_text(json.dumps(report, indent=2))
        print(name, status, row['seconds'], flush=True)
        return status == 'passed'

    engine = [args.godot, '--path', str(project)]
    if not args.skip_import and not run('import', engine + ['--headless', '--editor', '--import', '--quit']):
        return 1
    for index, (group, script, extra) in enumerate(jobs):
        name = '%02d-%s-%s' % (index, group, Path(script).stem)
        visual = group == 'visual'
        engine_log = output / (name + '-engine.log')
        try:
            command = command_for(args.godot, project, script, extra, visual, engine_log)
        except ValueError as error:
            parser.error(str(error))
        visual_report = project / VISUAL_REPORTS[Path(script).stem] if visual else None
        run(name, command, visual_report, engine_log)
        if report['results'][-1]['status'] == 'timeout' and visual:
            break  # Never launch another GPU fixture after an uncertain timeout cleanup.
    print('Report:', output / 'summary.json')
    return int(any(r['status'] != 'passed' for r in report['results']))

if __name__ == '__main__':
    sys.exit(main())
