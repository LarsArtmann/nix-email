#!/usr/bin/env python3
"""Force the converted DataStore descriptor at the LIVE store path.

The 0.15 management API serves the probe's EFFECTIVE settings, so the
DataStore path convert emits can point at the dump copy (--backup-dir
flow) instead of the live store. Recovery mode must migrate the LIVE
store; any other target leaves the first normal boot at the 0.16
multi-step panic (migrate-e2e run 6, 2026-10-18).
"""

import json
import sys


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {argv[0]} CONFIG LIVE_STORE", file=sys.stderr)
        return 64
    config_path, live = argv[1], argv[2]
    with open(config_path, encoding="utf-8") as handle:
        store = json.load(handle)
    if not isinstance(store, dict) or "path" not in store:
        return 0
    if store["path"] != live:
        print(
            f"note: DataStore path {store['path']} -> {live} "
            "(recovery mode targets the live store)",
            file=sys.stderr,
        )
        store["path"] = live
        with open(config_path, "w", encoding="utf-8") as handle:
            json.dump(store, handle, indent=2)
            handle.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
