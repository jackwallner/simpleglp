#!/usr/bin/env python3
"""Inspect release outputs without revealing embedded public SDK keys."""
from __future__ import annotations

import hashlib
from pathlib import Path
import re
import struct
import sys
import zipfile


def elf_alignments(data: bytes) -> list[int]:
    assert data[:4] == b"\x7fELF", "Native library is not ELF"
    order = "<" if data[5] == 1 else ">"
    if data[4] == 2:
        offset = struct.unpack_from(order + "Q", data, 32)[0]
        size, count = struct.unpack_from(order + "HH", data, 54)
        align_offset, fmt = 48, "Q"
    else:
        offset = struct.unpack_from(order + "I", data, 28)[0]
        size, count = struct.unpack_from(order + "HH", data, 42)
        align_offset, fmt = 28, "I"
    return [
        struct.unpack_from(order + fmt, data, offset + index * size + align_offset)[0]
        for index in range(count)
        if struct.unpack_from(order + "I", data, offset + index * size)[0] == 1
    ]


def verify(path: Path) -> None:
    native_count = 0
    play_keys: set[bytes] = set()
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if name.endswith(".so"):
                alignments = elf_alignments(archive.read(name))
                assert alignments and all(value >= 16384 for value in alignments), f"16 KiB alignment failed: {name}"
                native_count += 1
            if name.endswith(".dex"):
                data = archive.read(name)
                assert not re.search(rb"(?:test_|appl_|sk_)[A-Za-z0-9]{20,}", data), "Wrong-platform or secret key in release DEX"
                assert all(flag not in data for flag in (b"test_pro", b"test_reset", b"seed_pill", b"seed_shot")), "Debug launch hook in release DEX"
                play_keys.update(re.findall(rb"goog_[A-Za-z0-9]{20,}", data))
    assert native_count > 0, "Expected Compose native graphics libraries"
    assert len(play_keys) == 1, "Expected exactly one Play SDK key in release"
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f"{path.name}: {path.stat().st_size} bytes, {native_count} native libraries aligned for 16 KiB, Play key only, no test hooks, SHA-256 {digest}")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    paths = [Path(value) for value in sys.argv[1:]] or [
        root / "android/app/build/outputs/apk/release/app-release.apk",
        root / "android/app/build/outputs/bundle/release/app-release.aab",
    ]
    for path in paths:
        verify(path)


if __name__ == "__main__":
    main()
