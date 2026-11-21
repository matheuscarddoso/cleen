"""Formats what scripts/diagnostics.sh reads from the server (JSON on stdin).

    diagnostics-view.py list      every problem, most recent first
    diagnostics-view.py group     one problem and the reports kept for it
    diagnostics-view.py ips       a crash report back as the .ips macOS wrote
"""

import json
import sys


def list_groups(data):
    groups = data["groups"]
    if not groups:
        print("No reports yet.")
    for g in groups:
        versions = ", ".join(f"{version} x{count}" for version, count in sorted(g["versions"].items()))
        seen = g["lastSeen"][:16].replace("T", " ")
        print(f"{seen}  {g['count']:>5}x  {g['installs']:>4} Macs  {g['kind']:<13} {g['signature']}")
        print(f"    {g['summary']}")
        print(f"    since {g['firstSeen'][:10]} · {versions}")


def show_group(data):
    g = data["group"]
    print(g["summary"])
    print(f"{g['kind']} · {g['count']}x on {g['installs']} Macs · {g['firstSeen'][:16]} -> {g['lastSeen'][:16]}")
    print()
    for name in data["samples"]:
        print(name)


def to_ips(report):
    if report["kind"] != "crash":
        sys.exit(f"Only crashes have an .ips; this one is a {report['kind']}.")
    header = {
        "app_name": report["process"],
        "app_version": report["app"]["version"],
        "build_version": report["app"]["build"],
        "bug_type": "309",
        "os_version": report["system"]["os"],
        "name": report["process"],
    }
    print(json.dumps(header))
    print(report["report"])


if __name__ == "__main__":
    views = {"list": list_groups, "group": show_group, "ips": to_ips}
    if len(sys.argv) != 2 or sys.argv[1] not in views:
        sys.exit(__doc__)
    views[sys.argv[1]](json.load(sys.stdin))
