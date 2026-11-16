import importlib.util
from pathlib import Path
root=Path(__file__).resolve().parents[3]
path=root/'tests/run_suite.py'
spec=importlib.util.spec_from_file_location('suite',path);suite=importlib.util.module_from_spec(spec);spec.loader.exec_module(suite)
suite.GROUPS['visual'].append(('tests/evidence/seaside-background/backdrop_probe.gd',['--gpu']))
suite.VISUAL_REPORTS['backdrop_probe']='tests/evidence/chapter-tools/gpu.json'
raise SystemExit(suite.main())
