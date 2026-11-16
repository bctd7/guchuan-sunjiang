"""Runner contracts that prevent zero-exit, stale-report and wrong-renderer passes."""
import importlib.util
from pathlib import Path
import tempfile
import json
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('suite', Path(__file__).with_name('run_suite.py'))
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)

class RunnerTests(unittest.TestCase):
    def test_latest_cases_are_registered(self):
        levels = {Path(x).stem for x, _ in suite.GROUPS['levels']}
        self.assertTrue({'level01_orbit_tests','level01_inspector_tests','bulkhead_story_visual','hull_wood_normals_tests','level02_clarity_zoom_tests','level02_alignment_geometry_tests','level02_alignment_tests','level02_structure_geometry_tests','level02_structure_tests','observation_repeat_tests','repeat_lifecycle_tests'} <= levels)
        for script, extra in suite.GROUPS['visual']:
            self.assertIn(Path(script).stem, suite.VISUAL_REPORTS)
            if Path(script).stem in {'inspection_workspace_tests','level02_wrong_type_tests','level02_drag_tests','auxiliary_panel_tests','level02_clarity_zoom_tests','level02_alignment_tests','level02_structure_tests','observation_repeat_tests','repeat_lifecycle_tests'}:
                self.assertEqual(extra, ['--gpu'])
    def test_zero_exit_cannot_hide_script_or_resource_errors(self):
        self.assertEqual(suite.classify_log('SCRIPT ERROR: invalid method', 0)[0], 'script_error')
        self.assertEqual(suite.classify_log('ERROR: Failed loading resource: x', 0)[0], 'engine_error')
        self.assertEqual(suite.classify_log('ERROR: assertion failed', 0)[0], 'engine_error')
        self.assertEqual(suite.classify_log('', 1)[0], 'failed')
    def test_known_environment_warning_is_recorded(self):
        status, notes = suite.classify_log('ERROR: Condition "ret != noErr" is true. Returning: ""\n   at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)', 0)
        self.assertEqual(status, 'passed');self.assertEqual(len(notes), 1)
        self.assertEqual(suite.classify_log('ERROR: Cannot save file x', 0)[0], 'engine_error')
    def test_gpu_report_must_be_fresh_successful_and_unfocused(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)/'gpu.json'
            self.assertEqual(suite.validate_visual_report(p, None), 'report_missing_or_stale')
            p.write_text(json.dumps({'failed':0,'host_had_focus':False,'renderer':'macOS'}))
            self.assertEqual(suite.validate_visual_report(p, None), 'passed')
            self.assertEqual(suite.validate_visual_report(p, suite.fingerprint(p)), 'report_missing_or_stale')
            for data, status in [({'failed':1},'fixture_failed'),({'failed':0,'renderer':'headless'},'wrong_renderer'),({'failed':0,'renderer':'macOS','host_had_focus':True},'gpu_focus_error'),({'failed':0,'renderer':'macOS'},'gpu_focus_unverified'),({'failed':0,'host_had_focus':False},'wrong_renderer')]:
                p.write_text(json.dumps(data));self.assertEqual(suite.validate_visual_report(p, None), status)
    def test_timeout_cleanup_targets_only_unique_owned_job(self):
        engine='/Applications/Godot.app/Contents/MacOS/Godot'
        project=Path('/tmp/Review Project');log=Path('/tmp/Review Logs/unique.log')
        listing='123 '+engine+' --path /tmp/Review Project --log-file /tmp/Review Logs/unique.log --script tests/x.gd\n'
        listing+='456 '+engine+' --path /tmp/Review Project --editor\n'
        listing+='789 '+engine+' --path /tmp/Other --log-file /tmp/Review Logs/unique.log --script tests/x.gd\n'
        with mock.patch.object(suite.subprocess,'check_output',return_value=listing), mock.patch.object(suite.os,'kill') as kill:
            result=suite.terminate_owned_gpu(engine,project,log)
            self.assertEqual(result,{'stopped':[123]});kill.assert_called_once_with(123,suite.signal.SIGTERM)

    def test_native_and_background_launch_commands(self):
        cmd=suite.command_for('/Applications/Godot.app/Contents/MacOS/Godot', Path('/tmp/project'), 'tests/x.gd', ['--gpu'], True, Path('/tmp/unique.log'), 'darwin')
        self.assertEqual(cmd[:5], ['open','-g','-n','-W','-a'])
        self.assertIn('--log-file',cmd);self.assertIn('Dummy',cmd);self.assertEqual(cmd[-2:], ['--','--gpu'])
        headless=suite.command_for('godot',Path('/tmp/project'),'tests/x.gd',[],False,Path('/tmp/unique.log'),'linux')
        self.assertIn('--headless',headless);self.assertEqual(headless[0],'godot')

if __name__ == '__main__':unittest.main()
