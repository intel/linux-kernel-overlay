#!/usr/bin/env python3
"""Add missing Intel .cfg files to the config lists in amd64/defines.toml.

For every flavour's [flavour.build] config list, each *.cfg file in the
intel config directory that is not listed yet is appended after the last
existing 'amd64/intel/' entry (so flavour-specific entries such as
config.rt / config.test still come last). Existing entries and their order
are never changed; entries whose file no longer exists are only reported.

The file is edited textually so comments and layout elsewhere are kept.

Usage: sync-intel-configs.py [--check] DEFINES_TOML CFG_DIR
  --check  do not write; exit 1 if any file is missing from a list.
"""

import os
import re
import sys

PREFIX = 'amd64/intel/'

CONFIG_RE = re.compile(r'^(?P<indent>[ \t]*)config = \[\n(?P<body>.*?)^[ \t]*\]',
                       re.MULTILINE | re.DOTALL)
ENTRY_RE = re.compile(r"^\s*'([^']+)',?\s*$")


def cfg_files(cfg_dir):
    return sorted(PREFIX + n for n in os.listdir(cfg_dir)
                  if n.endswith('.cfg') and os.path.isfile(os.path.join(cfg_dir, n)))


def rewrite(text, files):
    added, stale = set(), set()

    def repl(m):
        indent = m.group('indent')
        entries = []
        for line in m.group('body').splitlines():
            if not line.strip():
                continue
            e = ENTRY_RE.match(line)
            if not e:
                raise SystemExit(f'error: cannot parse config entry: {line!r}')
            entries.append(e.group(1))
        missing = [f for f in files if f not in entries]
        stale.update(e for e in entries if e.startswith(PREFIX) and e not in files)
        if not missing:
            return m.group(0)
        added.update(missing)
        intel = [i for i, e in enumerate(entries) if e.startswith(PREFIX)]
        pos = intel[-1] + 1 if intel else 0
        entries[pos:pos] = missing
        lines = [f"{indent}    '{e}',\n" for e in entries]
        return f'{indent}config = [\n' + ''.join(lines) + f'{indent}]'

    new, count = CONFIG_RE.subn(repl, text)
    return new, count, sorted(added), sorted(stale)


def main(argv):
    check = '--check' in argv
    args = [a for a in argv if a != '--check']
    if len(args) != 2:
        sys.exit(__doc__.strip().split('\n\n')[-1])
    defines, cfg_dir = args

    with open(defines) as f:
        old = f.read()
    new, count, added, stale = rewrite(old, cfg_files(cfg_dir))
    if count == 0:
        sys.exit(f'error: no "config = [" lists found in {defines}')

    for e in stale:
        print(f'  warning: {e} is listed but not in {cfg_dir}')
    if new == old:
        print(f'{defines}: no missing intel configs')
        return 0
    for e in added:
        print(f'  + {e}')
    if check:
        print(f'{defines}: out of date, run "make sync-configs"')
        return 1
    with open(defines, 'w') as f:
        f.write(new)
    print(f'{defines}: appended {len(added)} config(s)')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
