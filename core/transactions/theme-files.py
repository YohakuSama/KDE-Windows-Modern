# SPDX-License-Identifier: GPL-3.0-or-later
"""Owned-file validation, atomic replacement and rollback for theme writers.

Callers retain the existing writer lock and validate their own renderer
and configuration plans. This module is independent of color algorithms,
KDE settings, and Kvantum.
"""
import os
from pathlib import Path
import stat
import tempfile


def owned_file(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid():
        raise ValueError(f"Not a user-owned theme file: {path}")
    return path


def atomic_write(path, data):
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, name = tempfile.mkstemp(prefix=".wm-accent-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            os.fchmod(out.fileno(), mode)
            out.write(data)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def restore_pending(pending, written):
    failures = []
    for path in reversed(written):
        old, new = pending[path]
        try:
            if owned_file(path).read_bytes() != new:
                raise ValueError(f"Theme changed during accent rollback: {path}")
            atomic_write(path, old)
        except (OSError, ValueError) as error:
            failures.append(str(error))
    if failures:
        raise ValueError("; ".join(failures))


def write_pending(pending):
    written = []
    try:
        for path, (old, new) in pending.items():
            if owned_file(path).read_bytes() != old:
                raise ValueError(f"Theme changed during accent synchronization: {path}")
            atomic_write(path, new)
            written.append(path)
    except (OSError, ValueError):
        restore_pending(pending, written)
        raise
    return written
