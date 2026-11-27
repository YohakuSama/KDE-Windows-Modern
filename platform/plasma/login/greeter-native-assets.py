#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Transfer verified generated artwork from the desktop user to the greeter."""
import io
import os
from pathlib import Path, PurePosixPath
import runpy
import shutil
import sys
import tarfile
import tempfile

SCRIPTS = Path(__file__).absolute().parent
MARKER = '.windows-modern-greeter'
LIMIT = 64 * 1024 * 1024


def native_files(base):
    root = base / 'native-assets'
    verify = runpy.run_path(str(SCRIPTS / 'check-native-icon-import.py'))['verify_import']
    verify(root, SCRIPTS / 'native-assets-map.json')
    return [root / 'manifest.json', *sorted((root / 'icons').rglob('*.svg'))]


def shell_files(base):
    root = base / 'shell-assets'
    if not root.exists():
        return []
    manifest = root / 'manifest.json'
    report = runpy.run_path(str(SCRIPTS / 'icon-coverage.py'))['shell_inventory'](manifest)
    if (not report.get('declared_build_matches_reference') or
            any(report.get(key) for key in ('reference_sources_missing',
                                           'reference_sources_changed',
                                           'reference_outputs_missing_or_changed',
                                           'missing_or_changed_outputs'))):
        raise ValueError('Shell artwork does not match the recorded 26H2 reference')
    return [manifest, *(root / name for name in report['verified_outputs'])]


def export(base):
    paths = native_files(base)
    try:
        shell = shell_files(base)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'Greeter: not transferring unverified private shell artwork: {exc}', file=sys.stderr)
        shell = []
    if not shell:
        print('Greeter: verified private battery/portrait artwork not supplied.', file=sys.stderr)
    with tarfile.open(fileobj=sys.stdout.buffer, mode='w|') as archive:
        for path in paths + shell:
            data = path.read_bytes()
            info = tarfile.TarInfo(path.relative_to(base).as_posix())
            info.size = len(data)
            info.mode = 0o644
            archive.addfile(info, io.BytesIO(data))


def receive(base):
    if base.is_symlink():
        raise ValueError('Refusing a symlink at the system artwork directory')
    if not base.exists():
        base.mkdir(parents=True, mode=0o755)
        base.chmod(0o755)
    work = Path(tempfile.mkdtemp(prefix='.greeter-artwork-', dir=base))
    retain_backup = False
    try:
        stage = work / 'incoming'
        stage.mkdir()
        # Never extract archive paths, links, owners or permission metadata.
        # The producer runs as the desktop user; root writes only plain files.
        total = 0
        with tarfile.open(fileobj=sys.stdin.buffer, mode='r|') as archive:
            for member in archive:
                relative = PurePosixPath(member.name)
                parts = relative.parts
                allowed = (len(parts) >= 2 and parts[0] in ('native-assets', 'shell-assets')
                           and relative.suffix in ('.json', '.svg', '.png', '.jpg', '.bmp'))
                total += member.size
                if (not allowed or relative.is_absolute() or '..' in parts or
                        relative.as_posix() != member.name or not member.isfile() or
                        not 0 <= member.size <= LIMIT or total > 4 * LIMIT):
                    raise ValueError('Invalid greeter artwork member: ' + member.name)
                target = stage.joinpath(*parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as src, target.open('xb') as dst:
                    shutil.copyfileobj(src, dst)
        expected = set(native_files(stage) + shell_files(stage))
        if expected != {p for p in stage.rglob('*') if p.is_file()}:
            raise ValueError('Unexpected or missing greeter artwork files')
        names = sorted(p.name for p in stage.iterdir())
        if 'shell-assets' not in names:
            # Do not silently reuse an older, incompatible system import.
            shell_files(base)
        for name in names:
            target = base / name
            if target.is_symlink() or (target.exists() and not (target / MARKER).is_file()):
                raise ValueError('Refusing to replace unrelated artwork: ' + str(target))
            (stage / name / MARKER).touch()
        for p in stage.rglob('*'):
            p.chmod(0o755 if p.is_dir() else 0o644)
        previous = work / 'previous'
        previous.mkdir()
        moved, installed = [], []
        try:
            for name in names:
                target = base / name
                if target.exists():
                    target.rename(previous / name)
                    moved.append(name)
                (stage / name).rename(target)
                installed.append(name)
        except OSError:
            try:
                for name in installed:
                    (base / name).rename(stage / name)
                for name in moved:
                    (previous / name).rename(base / name)
            except OSError:
                retain_backup = True
                print(f"Greeter rollback incomplete; backup retained at {work}", file=sys.stderr)
                raise
            raise
    finally:
        if not retain_backup:
            shutil.rmtree(work)


if __name__ == '__main__':
    try:
        command, directory = sys.argv[1:]
        base = Path(directory)
        if command == 'export' and os.geteuid() != 0:
            export(base)
        elif command == 'install' and os.geteuid() == 0:
            receive(base)
        elif command == 'verify':
            native_files(base)
            shell_files(base)
        else:
            raise ValueError('Export as desktop user; install as root')
    except (OSError, ValueError, KeyError, TypeError, tarfile.TarError) as exc:
        sys.exit(f'Greeter artwork: {exc}')
