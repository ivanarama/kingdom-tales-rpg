# -*- coding: utf-8 -*-
"""Локализационный проход: оборачивает шаблонные строки в tr() и имена
существ/заклинаний/артефактов в tr() для перевода через CSV."""
import io
import re


def convert(path, rules):
    s = io.open(path, encoding='utf-8').read()
    for desc, pattern, repl in rules:
        s, n = re.subn(pattern, repl, s)
        print('%-28s %-38s -> %d' % (path.split('/')[-1], desc, n))
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# 1. Имена существ в боевых логах: X.data.name -> tr(X.data.name)
arena_rules = [
    ('unit names (data.name)', r'(?<!tr\()\b(\w+(?:_\w+)*)\.data\.name\b', r'tr(\1.data.name)'),
    ('spell names', r'(?<!tr\()\b(sdata\.name|spell\.name)\b', r'tr(\1)'),
]

# 2. Шаблонные строки: "текст %d..." % -> tr("текст %d...") %
FMT = r'"([^"\\\n]*%[sd][^"\\\n]*)"(\s*%)'
fmt_rule = ('formatted templates', '(?<!tr\()' + FMT, r'tr("\1")\2')

convert('src/battle/battle_arena.gd', arena_rules + [fmt_rule])

# 3. world_map: имена из данных, подвиги, навыки, события + шаблоны
wm_name_rules = [
    ('unit dict names', r'(?<!tr\()\b((?:udata|sel_udata|next_udata|slot_udata|up_udata))\.get\("name"[^)]*\)',
     r'tr(\0)'),
    ('unit attr names', r'(?<!tr\()\b((?:udata|sel_udata|next_udata))\.name\b', r'tr(\1.name)'),
    ('feat titles/descs', r'(?<!tr\()str\((feat\[")(title|desc)(")\]\)', r'tr(str(\1\2\3))'),
]
convert('src/world/world_map.gd', wm_name_rules + [fmt_rule])
print('done')
