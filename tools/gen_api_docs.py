#!/usr/bin/env python3
"""Generates docs/API.md from src/hx/well/route/ApiRoute.hx.

Every route needs an entry in tools/api_descriptions.json ("METHOD /api/path"); the script fails when one is
missing or stale, so the reference cannot drift from the server. Run from the repository root.
"""
import json, re, sys

GROUPS = [
    ("Package install", "/api/package"),
    ("File system", "/api/fs"),
    ("System & processes", "/api/system|/api/process|/api/storage|/api/profile|/api/title"),
    ("Applications, media & saves", "/api/app|/api/media|/api/save"),
    ("Tasks & scripts", "/api/task|/api/script"),
    ("Statistics, decrypt & misc", "/api/stats|/api/decrypt|/api/server|/api/docs|/api/blank|/api/upload"),
]


def parse_routes(path):
    out, stack, orbis, brace, pend, pending_path = [], [], [], 0, None, None
    for line in open(path, encoding="utf-8").read().split("\n"):
        s = line.strip()
        if s.startswith("#if"):
            orbis.append(True)
        elif s == "#end" and orbis:
            orbis.pop()
        m = re.match(r'Route\.path\("([^"]+)"\)\.group\(\(\) -> \{', s)
        if m:
            stack.append((m.group(1), brace))
        m2 = re.match(r'Route\.path\("([^"]+)"\)$', s)
        if m2:
            pending_path = m2.group(1)
        elif s.startswith(".group(() -> {") and pending_path:
            stack.append((pending_path, brace))
            pending_path = None
        m = re.match(r'Route\.(get|post)\("([^"]+)"\)', s)
        if m:
            sub = m.group(2) if m.group(2).startswith("/") else "/" + m.group(2)
            pend = {"m": m.group(1).upper(), "p": "/api" + "".join(x for x, _ in stack) + sub,
                    "stream": False, "orbis": bool(orbis)}
            out.append(pend)
        if pend and ".setStream(true)" in s:
            pend["stream"] = True
        brace += line.count("{") - line.count("}")
        if s.startswith("});") and stack and brace == stack[-1][1]:
            stack.pop()
    return out


def main():
    routes = parse_routes("src/hx/well/route/ApiRoute.hx")
    desc = json.load(open("tools/api_descriptions.json", encoding="utf-8"))
    keys = {f"{r['m']} {r['p']}" for r in routes}
    missing = sorted(keys - desc.keys())
    stale = sorted(desc.keys() - keys)
    if missing or stale:
        print("missing descriptions:", missing, file=sys.stderr)
        print("descriptions for removed routes:", stale, file=sys.stderr)
        sys.exit(1)

    out = ["# AirPSX HTTP API\n",
           "Generated from `src/hx/well/route/ApiRoute.hx` by `tools/gen_api_docs.py`; edit `tools/api_descriptions.json` "
           "or `tools/api_extra.md`, not this file. All paths are relative to `http://<console-ip>:1214`.\n",
           "## Conventions\n",
           "- Requests and responses are JSON unless noted. Send `Content-Type: application/json` with POST bodies.",
           "- Handler errors are usually `200` with `{\"error\": \"...\"}` or `{\"success\": false, \"message\": \"...\"}`; "
           "validation failures return `422`; unknown routes fall back to the web UI.",
           "- **console only** routes exist only in console builds (the Linux host build used for development omits them).",
           "- **stream** routes read the request body themselves (uploads) and accept very large bodies.",
           "- There is no authentication. Anyone who can reach port 1214 can use every endpoint, so keep it on a trusted network.\n"]
    for title, pat in GROUPS:
        prefixes = pat.split("|")
        rows = [r for r in routes if any(r["p"].startswith(x) for x in prefixes)]
        if not rows:
            continue
        out += [f"## {title}\n", "| Method | Path | Flags | Description |", "|---|---|---|---|"]
        for r in rows:
            flags = ", ".join(f for f, c in (("console only", r["orbis"]), ("stream", r["stream"])) if c)
            out.append(f"| {r['m']} | `{r['p']}` | {flags} | {desc[r['m'] + ' ' + r['p']]} |")
        out.append("")
    placed = {r["p"] for g in GROUPS for r in routes if any(r["p"].startswith(x) for x in g[1].split("|"))}
    if placed != {r["p"] for r in routes}:
        print("routes outside every group:", sorted({r["p"] for r in routes} - placed), file=sys.stderr)
        sys.exit(1)
    out.append(open("tools/api_extra.md", encoding="utf-8").read())
    open("docs/API.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(f"docs/API.md written ({len(routes)} routes)")


main()
