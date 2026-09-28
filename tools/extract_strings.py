# -*- coding: utf-8 -*-
"""Извлечение русских строковых литералов из .gd файлов (для локализации)."""
import io
import json
import re

FILES = [
    'src/world/world_map.gd',
    'src/battle/battle_arena.gd',
]

STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
CYR = re.compile(r'[А-Яа-яЁё]')

out = {}
for f in FILES:
    s = io.open(f, encoding='utf-8').read()
    for m in STR_RE.finditer(s):
        t = m.group(1)
        if CYR.search(t):
            out[t] = out.get(t, 0) + 1

fmt = [t for t in out if '%s' in t or '%d' in t or '%%' in t]
print('unique:', len(out), '| formatted:', len(fmt))
with io.open('tools/_ru_strings.json', 'w', encoding='utf-8') as fh:
    json.dump(sorted(out.keys()), fh, ensure_ascii=False, indent=1)
print('saved tools/_ru_strings.json')
