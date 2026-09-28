# -*- coding: utf-8 -*-
import io

p = '_p_r1.py'
s = io.open(p, encoding='utf-8').read()
t = chr(9)
old = (
    "'''"
    + t + "merchant_cell = Vector2i(-99, -99)\n"
    + t + "merchant_offers.clear()\n"
    + t + "merchant_offers.clear()\n"
    + t + "pending_battle.clear()''',"
)
new = (
    "'''"
    + t + "merchant_cell = Vector2i(-99, -99)\n"
    + t + "merchant_offers.clear()\n"
    + t + "fallen_units.clear()\n"
    + t + "pending_battle.clear()''',"
)
assert s.count(old) == 1, s.count(old)
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('start_chapter hunk fixed (dedupe + fallen)')
