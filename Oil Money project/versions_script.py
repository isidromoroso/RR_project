#!/usr/bin/env python3
import os
import re
import sys
import subprocess
from importlib import import_module
from importlib.metadata import version, PackageNotFoundError

# 1. List your Python files here
FILES = [
    "Oil Money CAD.py",
    "Oil Money NOK.py",
    "Oil Money COP.py",
    "oil_money_trading_backtest.py",
    
    # add more .py paths as needed
]

def parse_python_imports(path):
    """
    Return a set of top-level module names imported in a .py file.
    """
    modules = set()
    imp_re  = re.compile(r'^\s*import\s+(.+)')
    from_re = re.compile(r'^\s*from\s+([\w\.]+)\s+import')
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = imp_re.match(line)
            if m:
                for part in m.group(1).split(','):
                    name = part.strip().split()[0].split('.')[0]
                    modules.add(name)
            m = from_re.match(line)
            if m:
                modules.add(m.group(1).split('.')[0])
    return modules

def get_installed_version(pkg_name):
    """
    Try multiple ways to find a package's version:
      1) importlib.metadata.version
      2) pip show
      3) module.__version__ (if in site-packages)
      4) stdlib
      5) not installed
    """
    # 1) metadata
    try:
        return version(pkg_name)
    except PackageNotFoundError:
        pass

    # 2) pip show
    try:
        out = subprocess.check_output(
            [sys.executable, "-m", "pip", "show", pkg_name],
            stderr=subprocess.DEVNULL
        ).decode()
        for line in out.splitlines():
            if line.startswith("Version:"):
                return line.split(":",1)[1].strip()
    except subprocess.CalledProcessError:
        pass

    # 3) __version__ or 4) stdlib
    try:
        mod = import_module(pkg_name)
        mod_file = getattr(mod, "__file__", "") or ""
        # stdlib modules live outside site-packages / dist-packages
        if "site-packages" not in mod_file and "dist-packages" not in mod_file:
            return "stdlib"
        return getattr(mod, "__version__", "unknown")
    except ImportError:
        return "not installed"

def main(py_files):
    all_mods = set()
    for p in py_files:
        if not os.path.isfile(p):
            print(f"[!] File not found: {p}")
            continue
        if not p.lower().endswith(".py"):
            print(f"[!] Skipping non-.py file: {p}")
            continue

        mods = parse_python_imports(p)
        print(f"--- {p} imports {len(mods)} modules ---")
        for m in sorted(mods):
            print(f"  {m}")
        print()
        all_mods |= mods

    print(f"=== Installed versions for {len(all_mods)} modules ===")
    for pkg in sorted(all_mods):
        ver = get_installed_version(pkg)
        print(f"  {pkg}: {ver}")

if __name__ == "__main__":
    main(FILES)
