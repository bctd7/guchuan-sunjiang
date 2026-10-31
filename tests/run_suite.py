#!/usr/bin/env python3
"""Curated Godot regressions. Run on a working copy: fixtures write res:// reports.
Headless groups inject Godot events; they do not claim human hardware or GPU QA.
Visual is opt-in and uses only no-focus/minimized fixtures.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

GROUPS = {
    'core': [('tests/' + x + '.gd', []) for x in ['run_tests', 'collision_tests', 'drag_input_tests', 'camera_tests']],
    'levels': [('tests/' + x + '.gd', []) for x in ['level01_rules_tests', 'level01_length_rules_tests', 'level01_trial_rules_tests', 'level01_input_tests', 'level02_rules_tests', 'level02_geometry_tests', 'level02_input_tests', 'level02_drag_tests', 'level03_geometry_tests', 'level03_input_tests', 'shipwright_story_tests', 'level01_failure_tests']],
    'classroom': [('tests/' + x + '.gd', []) for x in ['chapter_learning_tests', 'wood_material_entry_tests', 'chinese_font_tests', 'dynamic_integration_tests', 'force_gallery_tests', 'force_sequence_tests']] + [('classroom/science/test_education.gd', []), ('classroom/science/dynamic/test_dynamic.gd', [])],
    'campaign': [('tests/campaign_tests.gd', ['--phase=full']), ('tests/campaign_tests.gd', ['--phase=classroom']), ('tests/campaign_reentry_tests.gd', [])],
    'visual': [('tests/wood_material_entry_visual.gd', []), ('tests/level01_failure_visual.gd', [])],
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--godot', default=os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument('--group', action='append', choices=list(GROUPS) + ['all'])
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

    def run(name, command):
        start = time.monotonic()
        log = output / (name + '.log')
        with log.open('w') as stream:
            try:
                result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, env=env, timeout=args.timeout, check=False)
                code = result.returncode
                status = 'passed' if code == 0 else 'failed'
            except subprocess.TimeoutExpired:
                code, status = None, 'timeout'
            except OSError as error:
                stream.write(str(error))
                code, status = None, 'launch_error'
        # Godot may emit a script error yet exit zero; flag it for review.
        text = log.read_text(errors='replace')
        if status == 'passed' and ('SCRIPT ERROR:' in text or 'Parse Error:' in text):
            status = 'script_error'
        row = {'name': name, 'status': status, 'exit_code': code, 'seconds': round(time.monotonic()-start, 2), 'log': str(log), 'command': command}
        report['results'].append(row)
        (output / 'summary.json').write_text(json.dumps(report, indent=2))
        print(name, status, row['seconds'], flush=True)
        return status == 'passed'

    engine = [args.godot, '--path', str(project)]
    if not args.skip_import and not run('import', engine + ['--headless', '--editor', '--import', '--quit']):
        return 1
    for index, (group, script, extra) in enumerate(jobs):
        flags = ['--headless'] if group != 'visual' else ['--minimized', '--display-driver', 'macos', '--rendering-method', 'gl_compatibility', '--disable-vsync']
        run('%02d-%s-%s' % (index, group, Path(script).stem), engine + flags + ['--script', script] + (['--'] + extra if extra else []))
    print('Report:', output / 'summary.json')
    return int(any(r['status'] != 'passed' for r in report['results']))

if __name__ == '__main__':
    sys.exit(main())
