#!/usr/bin/env python3
"""Rewrite Windows home paths inside JSON files to the Linux home.

    C:\\Users\\shubh\\x\\y  or  c:/Users/shubh/x/y   ->   /home/<you>/x/y

Keys are rewritten too (Claude's per-project map); when two Windows spellings land on the
same Linux path, their settings are merged. MCP server launchers (node.exe, npx.cmd,
"cmd /c ...") become their Linux equivalents.
"""
import json
import os
import re
import sys

HOME = os.path.expanduser("~")
WIN_HOME = re.compile(r"^[A-Za-z]:[\\/]+Users[\\/]+[^\\/]+", re.I)
LINUX_LAUNCHERS = {"node", "npx", "npm", "python", "python3", "uv", "uvx", "bun", "bunx", "deno", "docker"}


def fix_str(s):
    m = WIN_HOME.match(s)
    if not m:
        return s
    return HOME + s[m.end():].replace("\\", "/")


def fix_mcp(server):
    cmd = server.get("command")
    if not isinstance(cmd, str):
        return
    args = list(server.get("args") or [])
    if os.path.basename(cmd).lower() in ("cmd", "cmd.exe") and args[:1] and str(args[0]).lower() == "/c":
        cmd, args = args[1], args[2:]
    stem = re.sub(r"\.(exe|cmd|bat)$", "", os.path.basename(cmd.replace("\\", "/")), flags=re.I)
    if stem.lower() in LINUX_LAUNCHERS:
        cmd = stem.lower()
    server["command"], server["args"] = cmd, args


def walk(o):
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            nk, nv = fix_str(k), walk(v)
            if nk in out and isinstance(out[nk], dict) and isinstance(nv, dict):
                merged = dict(nv)
                merged.update(out[nk])
                nv = merged
            out[nk] = nv
        servers = out.get("mcpServers")
        if isinstance(servers, dict):
            for server in servers.values():
                if isinstance(server, dict):
                    fix_mcp(server)
        return out
    if isinstance(o, list):
        return [walk(v) for v in o]
    if isinstance(o, str):
        return fix_str(o)
    return o


for path in sys.argv[1:]:
    if not os.path.isfile(path):
        continue
    try:
        with open(path, encoding="utf-8-sig") as f:
            data = json.load(f)
    except (ValueError, OSError) as e:
        print(f"  skip {path}: {e}")
        continue
    fixed = walk(data)
    if fixed != data:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(fixed, f, indent=2, ensure_ascii=False)
        print(f"  fixed {path}")
