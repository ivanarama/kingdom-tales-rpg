# -*- coding: utf-8 -*-
"""Извлечение русских строковых литералов из .gd и видимых текстов из .tscn (для локализации).

Сканируются все скрипты и сцены src/: строки из сцен Godot переводит сам (auto_translate),
а строки скриптов — через tr() или те же автопереводимые свойства Label/Button.
"""
import glob
import io
import json
import re

FILES = sorted(glob.glob('src/**/*.gd', recursive=True))
SCENES = sorted(glob.glob('src/**/*.tscn', recursive=True))

STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
# В сценах — только свойства, которые видит игрок
PROP_RE = re.compile(r'^(?:text|tooltip_text|placeholder_text|title|dialog_text) = "((?:[^"\\]|\\.)*)"', re.M)
CYR = re.compile(r'[А-Яа-яЁё]')

out = {}
for f in FILES:
    s = io.open(f, encoding='utf-8').read()
    for m in STR_RE.finditer(s):
        t = m.group(1)
        if CYR.search(t):
            out[t] = out.get(t, 0) + 1
for f in SCENES:
    s = io.open(f, encoding='utf-8').read()
    for m in PROP_RE.finditer(s):
        t = m.group(1)
        if CYR.search(t):
            out[t] = out.get(t, 0) + 1

fmt = [t for t in out if '%s' in t or '%d' in t or '%%' in t]
print('files:', len(FILES), '+ scenes:', len(SCENES), '| unique:', len(out), '| formatted:', len(fmt))
with io.open('tools/_ru_strings.json', 'w', encoding='utf-8') as fh:
    json.dump(sorted(out.keys()), fh, ensure_ascii=False, indent=1)
print('saved tools/_ru_strings.json')
