#!/usr/bin/env python3
"""Rename Claude Code project folders from Windows keys to Linux keys so memory follows the projects.

    C--Users-shubh--Active-Projects-NO-SUS   ->   -home-shubh--Active-Projects-NO-SUS

Claude derives the key from the project path by replacing every non-alphanumeric character
with '-', so keeping ~/_Active_Projects at the same place keeps the rest of the key identical.
"""
import os
import re
import shutil
import sys

root = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.claude/projects")
if not os.path.isdir(root):
    sys.exit(0)
linux_prefix = re.sub(r"[^A-Za-z0-9]", "-", os.path.expanduser("~"))
win_prefix = re.compile(r"^[A-Za-z]--Users-[A-Za-z0-9]+")

for name in sorted(os.listdir(root)):
    m = win_prefix.match(name)
    if not m:
        continue
    new = linux_prefix + name[m.end():]
    src, dst = os.path.join(root, name), os.path.join(root, new)
    if not os.path.exists(dst):
        os.rename(src, dst)
    else:
        # A Linux folder already exists (Claude ran here first): merge without overwriting.
        for dirpath, _, files in os.walk(src):
            target_dir = os.path.join(dst, os.path.relpath(dirpath, src))
            os.makedirs(target_dir, exist_ok=True)
            for f in files:
                target = os.path.join(target_dir, f)
                if not os.path.exists(target):
                    shutil.move(os.path.join(dirpath, f), target)
        shutil.rmtree(src, ignore_errors=True)
    print(f"  {name}  ->  {new}")
