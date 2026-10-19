#!/usr/bin/env python3
"""Compact bar migration preserves widget settings and unrelated configuration."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    config_path = Path(directory) / 'shell.json'
    fragment_path = Path(directory) / 'fragment.json'
    custom_widget = {'id': 'hey-omarchy', 'name': 'main-monitor', 'userColor': '#abcdef'}
    clock = {'id': 'omarchy.clock', 'format': 'HH:mm:ss'}
    network = {'id': 'omarchy.network', 'userSetting': 'kept'}
    unrelated_plugin = {'id': 'local.example', 'setting': 42}
    config = {
        'bar': {'position': 'bottom', 'centerAnchor': 'omarchy.clock', 'layout': {
            'left': ['omarchy.menu', 'omarchy.workspaces', custom_widget], 'center': [clock], 'right': [
                {'id': 'hey-omarchy', 'name': 'fcitx-en'}, network, 'omarchy.power']}},
        'plugins': [unrelated_plugin],
        'disabledPlugins': ['local.disabled', 'hey-omarchy'],
        'idle': {'lock': 300, 'customSetting': True},
        'unrelatedSetting': {'enabled': True},
    }
    fragment = {
        'plugins': [{'id': 'hey-omarchy'}, {'id': 'hey-omarchy-lock'}],
        'barSettings': {'centerAnchor': ''},
        'barRemovals': ['omarchy.workspaces', 'hey-omarchy'],
        'barMoves': [
            {'widget': 'omarchy.clock', 'section': 'left', 'after': 'omarchy.menu'},
        ],
        'barReplacements': [
            {'widget': 'omarchy.network', 'entry': {'id': 'reoring.network'}},
            {'widget': 'omarchy.power', 'entry': {'id': 'reoring.power'}},
            {'widget': 'omarchy.monitor', 'entry': {'id': 'reoring.monitor'}},
        ],
        'barAdditions': [
            {'section': 'right', 'before': 'reoring.network', 'entry': {
                'id': 'hey-omarchy'}},
        ],
        'barWidgetSettings': {'reoring.power': {'showPercentage': True}},
        'idle': {'lock': 900},
        'disabledPlugins': ['omarchy.lock'],
        'cloneSourceRestores': ['hey-omarchy-lock'],
    }
    config_path.write_text(json.dumps(config))
    fragment_path.write_text(json.dumps(fragment))

    def apply():
        result = subprocess.run([sys.executable, str(root / 'merge-shell-config.py'),
                                 str(config_path), str(fragment_path)],
                                capture_output=True, text=True, check=True)
        config_path.write_text(result.stdout)
        return json.loads(result.stdout)

    first = apply()
    assert first['bar']['position'] == 'bottom'
    assert first['bar']['centerAnchor'] == ''
    assert first['bar']['layout']['left'] == ['omarchy.menu', clock]
    assert first['bar']['layout']['center'] == []
    assert first['bar']['layout']['right'] == [
        {'id': 'hey-omarchy'}, {'id': 'reoring.network', 'userSetting': 'kept'},
        {'id': 'reoring.power', 'showPercentage': True}], \
        'clones must take the stock position and settings; a removed stock widget stays absent'
    assert unrelated_plugin in first['plugins']
    assert first['unrelatedSetting'] == config['unrelatedSetting']
    assert first['idle'] == {'lock': 900, 'customSetting': True}
    assert first['disabledPlugins'] == ['local.disabled', 'omarchy.lock']
    assert first['cloneSourceRestores'] == ['hey-omarchy-lock']
    assert apply() == first, 'reapplication must retain positions and avoid duplicate widgets/plugins'
    stale = json.loads(config_path.read_text())
    del stale['bar']['layout']['right'][2]['showPercentage']
    config_path.write_text(json.dumps(stale))
    assert apply() == first, 'bundle-owned widget options must reach clones swapped in by an earlier apply'
print('PASS: compact bar migration preserves widget settings and is idempotent')
