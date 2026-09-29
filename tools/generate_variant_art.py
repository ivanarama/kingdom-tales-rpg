# -*- coding: utf-8 -*-
"""Генерация вариантного арта: тонировка существующих токенов/спрайтов/иконок.

Новые существа (пегас, каменный страж, лиса-оборотень) и новые заклинания
получают собственные изображения в том же стиле — оттенком базового арта.
Запуск из корня проекта:  python tools/generate_variant_art.py
"""
import os
from PIL import Image, ImageOps

# (источник, назначение, black, mid, white) — контрольные точки колоризации
JOBS = [
    # Юниты: токены и спрайты
    ("assets/art/ui/tokens/token_unit_griffin.png", "assets/art/ui/tokens/token_unit_pegasus.png",
     (40, 55, 100), (160, 180, 220), (245, 250, 255)),
    ("assets/art/units/unit_griffin.png", "assets/art/units/unit_pegasus.png",
     (40, 55, 100), (160, 180, 220), (245, 250, 255)),
    ("assets/art/ui/tokens/token_unit_treant.png", "assets/art/ui/tokens/token_unit_stone_guardian.png",
     (28, 30, 34), (125, 128, 136), (205, 210, 220)),
    ("assets/art/units/unit_treant.png", "assets/art/units/unit_stone_guardian.png",
     (28, 30, 34), (125, 128, 136), (205, 210, 220)),
    ("assets/art/ui/tokens/token_unit_wolf.png", "assets/art/ui/tokens/token_unit_fox_shifter.png",
     (70, 30, 8), (205, 110, 40), (255, 215, 140)),
    ("assets/art/units/unit_wolf.png", "assets/art/units/unit_fox_shifter.png",
     (70, 30, 8), (205, 110, 40), (255, 215, 140)),
    # Иконки заклинаний
    ("assets/art/spells/spell_fireball.png", "assets/art/spells/spell_lightning.png",
     (20, 40, 120), (90, 140, 255), (225, 240, 255)),
    ("assets/art/spells/spell_bless.png", "assets/art/spells/spell_stoneskin.png",
     (40, 35, 30), (135, 124, 104), (215, 210, 195)),
    ("assets/art/spells/spell_haste.png", "assets/art/spells/spell_scrying.png",
     (50, 20, 80), (160, 90, 230), (238, 214, 255)),
    ("assets/art/spells/spell_haste.png", "assets/art/spells/spell_blind.png",
     (120, 90, 10), (255, 210, 60), (255, 252, 225)),
    ("assets/art/spells/spell_bless.png", "assets/art/spells/spell_inspiration.png",
     (20, 70, 30), (140, 220, 90), (242, 255, 205)),
    ("assets/art/spells/spell_heal.png", "assets/art/spells/spell_shield_light.png",
     (20, 50, 90), (120, 180, 240), (232, 246, 255)),
    ("assets/art/spells/spell_fireball.png", "assets/art/spells/spell_retribution.png",
     (110, 40, 0), (255, 150, 30), (255, 238, 175)),
    # Канонические образы вместо плейсхолдеров: Лич (костяной древень) и Красный Дракон (багровый грифон)
    ("assets/art/ui/tokens/token_unit_treant.png", "assets/art/ui/tokens/token_unit_lich.png",
     (22, 26, 24), (140, 150, 142), (228, 236, 226)),
    ("assets/art/units/unit_treant.png", "assets/art/units/unit_lich.png",
     (22, 26, 24), (140, 150, 142), (228, 236, 226)),
    ("assets/art/ui/tokens/token_unit_griffin.png", "assets/art/ui/tokens/token_unit_red_dragon.png",
     (80, 10, 5), (205, 45, 25), (255, 185, 120)),
    ("assets/art/units/unit_griffin.png", "assets/art/units/unit_red_dragon.png",
     (80, 10, 5), (205, 45, 25), (255, 185, 120)),
    # Временный арт новых существ до настоящих иллюстраций (ТЗ: docs/art/tz_creatures.md):
    # жемчужные Единороги (пока — пегас), огненные Саламандры (волк), Магмовые големы (древень)
    ("assets/art/ui/tokens/token_unit_pegasus.png", "assets/art/ui/tokens/token_unit_unicorn.png",
     (70, 60, 105), (205, 195, 240), (255, 252, 255)),
    ("assets/art/units/unit_pegasus.png", "assets/art/units/unit_unicorn.png",
     (70, 60, 105), (205, 195, 240), (255, 252, 255)),
    ("assets/art/ui/tokens/token_unit_wolf.png", "assets/art/ui/tokens/token_unit_lava_salamander.png",
     (40, 5, 0), (225, 75, 20), (255, 225, 120)),
    ("assets/art/units/unit_wolf.png", "assets/art/units/unit_lava_salamander.png",
     (40, 5, 0), (225, 75, 20), (255, 225, 120)),
    ("assets/art/ui/tokens/token_unit_treant.png", "assets/art/ui/tokens/token_unit_magma_golem.png",
     (25, 10, 8), (150, 50, 20), (255, 170, 60)),
    ("assets/art/units/unit_treant.png", "assets/art/units/unit_magma_golem.png",
     (25, 10, 8), (150, 50, 20), (255, 170, 60)),
    # Дозаполнение иконок, чтобы у всех 10 заклинаний был различимый значок
    ("assets/art/spells/spell_haste.png", "assets/art/spells/spell_slow.png",
     (10, 35, 90), (80, 150, 235), (220, 240, 255)),
    ("assets/art/spells/spell_heal.png", "assets/art/spells/spell_restoration.png",
     (110, 70, 0), (250, 190, 50), (255, 245, 200)),
    # Улучшенные и близкие отряды не должны выглядеть как базовые: белые Королевские
    # Грифоны, сиреневые Королевские Феи, дубово-бурые Друиды (раньше — спрайт фей)
    ("assets/art/ui/tokens/token_unit_griffin.png", "assets/art/ui/tokens/token_unit_royal_griffin.png",
     (60, 50, 35), (215, 205, 180), (255, 252, 240)),
    ("assets/art/units/unit_griffin.png", "assets/art/units/unit_royal_griffin.png",
     (60, 50, 35), (215, 205, 180), (255, 252, 240)),
    ("assets/art/ui/tokens/token_unit_fairy_archer.png", "assets/art/ui/tokens/token_unit_royal_fairy.png",
     (45, 20, 70), (170, 120, 220), (250, 235, 255)),
    ("assets/art/units/unit_fairy_archer.png", "assets/art/units/unit_royal_fairy.png",
     (45, 20, 70), (170, 120, 220), (250, 235, 255)),
    ("assets/art/ui/tokens/token_unit_fairy_archer.png", "assets/art/ui/tokens/token_unit_druid.png",
     (40, 22, 8), (160, 95, 40), (245, 215, 150)),
    ("assets/art/units/unit_fairy_archer.png", "assets/art/units/unit_druid.png",
     (40, 22, 8), (160, 95, 40), (245, 215, 150)),
]


def tint(src_path, dst_path, black, mid, white):
    img = Image.open(src_path).convert("RGBA")
    alpha = img.getchannel("A")
    gray = ImageOps.grayscale(img)
    colored = ImageOps.colorize(gray, black=black, white=white, mid=mid)
    colored = colored.convert("RGBA")
    colored.putalpha(alpha)
    colored.save(dst_path)
    print("OK", dst_path)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for src, dst, black, mid, white in JOBS:
        tint(os.path.join(root, src), os.path.join(root, dst), black, mid, white)


if __name__ == "__main__":
    main()
