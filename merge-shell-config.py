#!/usr/bin/env python3
"""Merge the hey-omarchy fragment without replacing unrelated shell settings."""
import json
import sys
from pathlib import Path


def merge(config, fragment):
    config.setdefault('version', 1)
    config.setdefault('idle', {}).update(fragment.get('idle', {}))
    plugins = config.setdefault('plugins', [])
    enabled = set()
    for entry in fragment.get('plugins', []):
        enabled.add(entry['id'])
        if not any(plugin['id'] == entry['id'] for plugin in plugins):
            plugins.append(entry)

    bar = config.setdefault('bar', {})
    bar.update(fragment.get('barSettings', {}))
    layout = bar.setdefault('layout', {})
    for section in ('left', 'center', 'right'):
        layout.setdefault(section, [])

    def identity(entry):
        return (entry, None) if isinstance(entry, str) else (entry['id'], entry.get('name'))

    def matches(entry, selector):
        if isinstance(selector, str):
            return identity(entry)[0] == selector
        return identity(entry) == identity(selector)

    def insert(widgets, entry, placement):
        before = placement.get('before')
        after = placement.get('after')
        if before is not None:
            index = next((i for i, widget in enumerate(widgets) if matches(widget, before)), len(widgets))
        elif after is not None:
            index = next((i + 1 for i, widget in enumerate(widgets) if matches(widget, after)), len(widgets))
        else:
            index = len(widgets)
        widgets.insert(index, entry)

    for selector in fragment.get('barRemovals', []):
        for widgets in layout.values():
            widgets[:] = [widget for widget in widgets if not matches(widget, selector)]

    for move in fragment.get('barMoves', []):
        entry = None
        for widgets in layout.values():
            index = next((i for i, widget in enumerate(widgets)
                          if matches(widget, move['widget'])), None)
            if index is not None:
                entry = widgets.pop(index)
                break
        if entry is not None:
            insert(layout[move['section']], entry, move)

    for addition in fragment.get('barAdditions', []):
        entry = addition['entry']
        enabled.add(entry['id'])
        if any(identity(widget) == identity(entry)
               for widgets in layout.values() for widget in widgets):
            continue
        insert(layout[addition['section']], entry, addition)

    disabled = [plugin for plugin in config.get('disabledPlugins', []) if plugin not in enabled]
    for plugin in fragment.get('disabledPlugins', []):
        if plugin not in disabled:
            disabled.append(plugin)
    if disabled or 'disabledPlugins' in config:
        config['disabledPlugins'] = disabled

    restores = config.get('cloneSourceRestores', [])
    for plugin in fragment.get('cloneSourceRestores', []):
        if plugin not in restores:
            restores.append(plugin)
    if restores:
        config['cloneSourceRestores'] = restores
    return config


def main():
    config_path, fragment_path = map(Path, sys.argv[1:])
    if not config_path.exists():
        config_path = Path('/usr/share/omarchy/config/omarchy/shell.json')
    config = json.loads(config_path.read_text())
    fragment = json.loads(fragment_path.read_text())
    print(json.dumps(merge(config, fragment), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
