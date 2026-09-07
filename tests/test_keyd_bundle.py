#!/usr/bin/env python3
"""Exercise keyd bundle transactions in a rootless, host-read-only sandbox."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ('hyper', 'kana-hyper.conf', 'roba-hyper.conf')
if not shutil.which('bwrap') or not shutil.which('keyd'):
    print('SKIP: keyd bundle transactions require bubblewrap and keyd')
    raise SystemExit(0)


def snapshot(directory):
    return {p.name: p.read_bytes() for p in directory.iterdir()
            if p.is_file() and '.bak.' not in p.name}


with tempfile.TemporaryDirectory(prefix='hey-keyd-test-') as directory:
    work = Path(directory)
    configs = work / 'keyd'
    stubs = work / 'bin'
    configs.mkdir()
    stubs.mkdir()
    # Run the real keyd parser. Only daemon IPC/systemd are replaced: this
    # sandbox deliberately has no access to host services or input devices.
    for name, content in {
        'systemctl': '#!/bin/sh\nexit 0\n',
        'keyd': '''#!/bin/sh
if [ "$1" = check ]; then exec /usr/bin/keyd "$@"; fi
if [ "$1" = reload ] && [ -f /etc/keyd/fail-reload ]; then
    rm /etc/keyd/fail-reload
    exit 1
fi
[ "$1" = reload ]
''',
        'sudo': '#!/bin/sh\necho "unexpected privilege escalation" >&2\nexit 99\n',
    }.items():
        path = stubs / name
        path.write_text(content)
        path.chmod(0o755)

    def run(*args, success=True):
        result = subprocess.run([
            'bwrap', '--unshare-all', '--ro-bind', '/', '/',
            '--dev', '/dev', '--proc', '/proc', '--tmpfs', '/run',
            '--tmpfs', '/tmp', '--uid', '0', '--gid', '0',
            '--bind', str(configs), '/etc/keyd',
            '--ro-bind', str(stubs), '/tmp/test-bin',
            '--setenv', 'PATH', '/tmp/test-bin:/usr/bin:/bin',
            'bash', str(ROOT / 'setup-keyd.sh'), *args,
        ], capture_output=True, text=True)
        if success:
            assert result.returncode == 0, result.stdout + result.stderr
        else:
            assert result.returncode != 0, result.stdout + result.stderr
        return result

    def reset():
        for path in configs.iterdir():
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()

    # The shared include must be deployable on a host which doesn't have it.
    run()
    for name in FILES:
        assert (configs / name).read_bytes() == (ROOT / 'etc/keyd' / name).read_bytes()
    installed = snapshot(configs)
    run()
    assert snapshot(configs) == installed, 'reapply must retain original rollback ownership'
    run('--rollback')
    assert not snapshot(configs), 'fresh-install rollback must remove all bundle-owned files'
    print('PASS: fresh apply, reapply, and rollback preserve bundle ownership')

    # An already-present config remains unowned, but may need the shared file
    # that this install creates. Rollback must not strand that include.
    reset()
    (configs / 'roba-hyper.conf').write_bytes((ROOT / 'etc/keyd/roba-hyper.conf').read_bytes())
    run()
    installed = snapshot(configs)
    run('--rollback', success=False)
    assert snapshot(configs) == installed, 'rollback must preserve an unowned include consumer'
    print('PASS: unowned roBa configuration retains its shared Hyper dependency')

    # A later user edit blocks destructive rollback of the shared transaction.
    reset()
    run()
    with (configs / 'roba-hyper.conf').open('a') as stream:
        stream.write('\n[main]\nf12 = f11\n')
    edited = snapshot(configs)
    run('--rollback', success=False)
    assert snapshot(configs) == edited, 'rollback must preserve user edits and their includes'
    print('PASS: later user edits and shared dependencies survive rollback')

    # A failed activation must restore the prior complete configuration, not
    # leave the old kana config paired with a new shared layer or new IDs.
    reset()
    (configs / 'kana-hyper.conf').write_text('[ids]\n*\n[main]\na = b\n')
    (configs / 'roba-hyper.conf').write_text('[ids]\n1d50:615e\n[main]\nf12 = f11\n')
    (configs / 'hyper').write_text('[old:C]\n')
    before = snapshot(configs)
    (configs / 'fail-reload').touch()
    run(success=False)
    assert snapshot(configs) == before, 'failed activation must restore every prior file and ownership record'
    print('PASS: failed activation restores the whole prior configuration')

    # Existing installations have only the original two-line kana record.
    reset()
    original = b'[ids]\n*\n[main]\na = b\n'
    deployed = (ROOT / 'etc/keyd/kana-hyper.conf').read_bytes().replace(
        b'include hyper', (ROOT / 'etc/keyd/hyper').read_bytes())
    backup = 'kana-hyper.conf.bak.20260101-000000'
    (configs / backup).write_bytes(original)
    (configs / 'kana-hyper.conf').write_bytes(deployed)
    (configs / '.hey-omarchy-kana-hyper').write_text(
        '/etc/keyd/' + backup + '\n' + hashlib.sha256(deployed).hexdigest() + '\n')
    run('--rollback')
    assert (configs / 'kana-hyper.conf').read_bytes() == original
    assert not (configs / '.hey-omarchy-kana-hyper').exists()
    print('PASS: legacy kana-only ownership records still roll back')
