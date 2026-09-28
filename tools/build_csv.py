# -*- coding: utf-8 -*-
"""Сборка localization/translations.csv из словарей tr_dicts + данных."""
import csv
import io
import json
import re
import glob
import os

CYR = re.compile(r'[А-Яа-яЁё]')


def unescape(t):
    return (t.replace('\\n', '\n').replace('\\t', '\t')
             .replace('\\"', '"').replace('\\\\', '\\'))


# 1. Собираем переводы: старый CSV как база + батчи поверх
merged = {}
if os.path.exists('localization/translations.csv'):
    with io.open('localization/translations.csv', encoding='utf-8') as fh:
        for row in csv.DictReader(fh):
            k = (row.get('keys') or '').replace('\r\n', '\n')
            if k and row.get('en'):
                merged[k] = row['en']
for path in sorted(glob.glob('tools/tr_dicts/batch*.py')):
    ns = {}
    exec(io.open(path, encoding='utf-8').read(), ns)
    for k, v in ns['T'].items():
        if v:
            merged[k] = v

# 2. Кандидаты: извлечённые строки + строки из data-файлов
candidates = set()
rows = json.load(io.open('tools/_ru_strings.json', encoding='utf-8'))
for r in rows:
    candidates.add(unescape(r))

for f in ['src/core/unit_data.gd', 'src/core/spell_data.gd',
          'src/core/artifact_data.gd', 'src/core/game_state.gd']:
    s = io.open(f, encoding='utf-8').read()
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', s):
        t = unescape(m.group(1))
        if CYR.search(t):
            candidates.add(t)

# Строки из JSON-данных (encounters, dwellings) — тоже игроку видны
for f in glob.glob('data/*.json'):
    s = io.open(f, encoding='utf-8').read()
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"',
                         s):
        t = unescape(m.group(1))
        if CYR.search(t) and not t.startswith('Реестр'):
            candidates.add(t)

# 3. Пишем CSV (только те, где есть перевод)
os.makedirs('localization', exist_ok=True)
written = 0
with io.open('localization/translations.csv', 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['keys', 'en'])
    for k in sorted(candidates):
        if k in merged:
            w.writerow([k, merged[k]])
            written += 1

# 4. Отчёт о непереведённом
missing = sorted(c for c in candidates if c not in merged)
with io.open('tools/_missing_translations.txt', 'w', encoding='utf-8') as fh:
    for m in missing:
        fh.write(m.replace('\n', '\\n') + '\n')

print('rows written:', written, '| missing:', len(missing))
for m in missing[:40]:
    print('  ?', m.replace('\n', '\\n')[:110])
