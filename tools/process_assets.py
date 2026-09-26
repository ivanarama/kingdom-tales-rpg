import os
import math
import wave
import struct
from PIL import Image, ImageDraw, ImageFilter, ImageOps

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ART_DIR = os.path.join(BASE_DIR, "assets", "art")
AUDIO_DIR = os.path.join(BASE_DIR, "assets", "audio")

def remove_plain_background(img_path, tolerance=28):
    """Make light background of unit images transparent with soft alpha edge."""
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    
    # Sample background color from 4 corners
    corners = [img.getpixel((5, 5)), img.getpixel((w - 6, 5)), 
               img.getpixel((5, h - 6)), img.getpixel((w - 6, h - 6))]
    bg_r = sum(c[0] for c in corners) / 4.0
    bg_g = sum(c[1] for c in corners) / 4.0
    bg_b = sum(c[2] for c in corners) / 4.0
    
    data = img.getdata()
    new_data = []
    for item in data:
        r, g, b, a = item
        # Euclidean color distance to background
        dist = math.sqrt((r - bg_r)**2 + (g - bg_g)**2 + (b - bg_b)**2)
        if dist < tolerance:
            new_data.append((r, g, b, 0))
        elif dist < tolerance + 25:
            alpha = int(255 * (dist - tolerance) / 25.0)
            new_data.append((r, g, b, alpha))
        else:
            new_data.append((r, g, b, 255))
            
    img.putdata(new_data)
    return img

def create_circular_token(img_path, size=128, border_color=(235, 190, 80)):
    """Create a circular token with a golden ornate ring border for turn order initiative."""
    orig = Image.open(img_path).convert("RGBA")
    
    # Crop to center square
    w, h = orig.size
    min_side = min(w, h)
    left = (w - min_side) // 2
    top = (h - min_side) // 2
    orig = orig.crop((left, top, left + min_side, top + min_side))
    orig = orig.resize((size, size), Image.Resampling.LANCZOS)
    
    # Circular mask
    mask = Image.new("L", (size, size), 0)
    draw_mask = ImageDraw.Draw(mask)
    draw_mask.ellipse((4, 4, size - 5, size - 5), fill=255)
    
    token = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    token.paste(orig, (0, 0), mask=mask)
    
    # Draw golden ring
    draw = ImageDraw.Draw(token)
    # Outer dark shadow
    draw.ellipse((1, 1, size - 2, size - 2), outline=(40, 25, 10, 200), width=2)
    # Main gold ring
    draw.ellipse((3, 3, size - 4, size - 4), outline=border_color, width=3)
    # Inner gold highlight
    draw.ellipse((5, 5, size - 6, size - 6), outline=(255, 235, 160, 220), width=1)
    # Inner rim
    draw.ellipse((6, 6, size - 7, size - 7), outline=(90, 60, 20, 180), width=1)
    
    return token

def create_parchment_texture(w=600, h=400):
    """Generate a warm, fairy-tale parchment background texture with ornate border."""
    base = Image.new("RGBA", (w, h), (245, 232, 205, 255))
    draw = ImageDraw.Draw(base)
    
    # Warm parchment gradient
    for y in range(h):
        for x in range(0, w, 4):
            noise = ((x * 13 + y * 29) % 17) - 8
            r = min(255, max(0, 246 + noise - int(y * 12 / h)))
            g = min(255, max(0, 232 + noise - int(y * 18 / h)))
            b = min(255, max(0, 200 + noise - int(y * 22 / h)))
            draw.rectangle([x, y, x + 3, y], fill=(r, g, b, 255))
            
    # Aged vignette borders
    vignette = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    for i in range(16):
        alpha = int(140 * (1.0 - i / 16.0))
        vdraw.rectangle([i, i, w - 1 - i, h - 1 - i], outline=(140, 95, 45, alpha))
        
    base = Image.alpha_composite(base, vignette)
    
    # Inner decorative gold line
    draw = ImageDraw.Draw(base)
    inset = 18
    draw.rectangle([inset, inset, w - inset, h - inset], outline=(180, 135, 55, 220), width=2)
    draw.rectangle([inset + 3, inset + 3, w - inset - 3, h - inset - 3], outline=(225, 185, 95, 180), width=1)
    
    # Corner flourishes
    corner_size = 12
    for cx, cy in [(inset, inset), (w - inset, inset), (inset, h - inset), (w - inset, h - inset)]:
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(215, 165, 60, 255), outline=(100, 60, 20, 255))
        
    return base

def create_wood_button(w=260, h=64, label="Button", color_theme="oak"):
    """Generate a carved wooden button texture with golden frame."""
    btn = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(btn)
    
    # Outer dark shadow
    draw.rounded_rectangle([2, 4, w - 3, h - 1], radius=8, fill=(30, 18, 10, 180))
    # Wood base
    wood_col = (95, 55, 30, 255) if color_theme == "oak" else (130, 70, 35, 255)
    draw.rounded_rectangle([2, 2, w - 3, h - 4], radius=8, fill=wood_col)
    
    # Top highlight
    draw.rounded_rectangle([4, 4, w - 5, (h // 2)], radius=6, fill=(145, 90, 50, 120))
    
    # Golden border
    draw.rounded_rectangle([2, 2, w - 3, h - 4], radius=8, outline=(215, 175, 75, 240), width=2)
    draw.rounded_rectangle([4, 4, w - 5, h - 6], radius=6, outline=(255, 220, 120, 160), width=1)
    
    # Corner rivet studs
    for rx, ry in [(8, 8), (w - 9, 8), (8, h - 10), (w - 9, h - 10)]:
        draw.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(245, 205, 95, 255), outline=(60, 35, 15, 255))
        
    return btn

def create_spell_icon(name, bg_color, symbol_type):
    """Create a glowing fairy-tale spell icon with golden filigree frame."""
    size = 100
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    
    # Background circle
    draw.ellipse([4, 4, size - 5, size - 5], fill=bg_color)
    
    # Magical glow aura
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([15, 15, size - 16, size - 16], fill=(255, 255, 255, 140))
    glow = glow.filter(ImageFilter.GaussianBlur(8))
    icon = Image.alpha_composite(icon, glow)
    
    draw = ImageDraw.Draw(icon)
    cx, cy = size // 2, size // 2
    
    if symbol_type == "fire":
        # Flame symbol
        flame_pts = [
            (cx, cy - 26), (cx + 14, cy - 6), (cx + 18, cy + 14),
            (cx + 8, cy + 24), (cx, cy + 26), (cx - 8, cy + 24),
            (cx - 18, cy + 14), (cx - 14, cy - 6)
        ]
        draw.polygon(flame_pts, fill=(255, 220, 60, 255))
        draw.ellipse([cx - 8, cy, cx + 8, cy + 18], fill=(255, 255, 200, 255))
    elif symbol_type == "heal":
        # Golden-green cross with sparkles
        draw.rectangle([cx - 7, cy - 22, cx + 7, cy + 22], fill=(255, 255, 255, 255))
        draw.rectangle([cx - 22, cy - 7, cx + 22, cy + 7], fill=(255, 255, 255, 255))
        draw.rectangle([cx - 5, cy - 20, cx + 5, cy + 20], fill=(120, 245, 130, 255))
        draw.rectangle([cx - 20, cy - 5, cx + 20, cy + 5], fill=(120, 245, 130, 255))
    elif symbol_type == "bless":
        # Radiant star
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            x1 = cx + math.cos(rad) * 26
            y1 = cy + math.sin(rad) * 26
            draw.line([(cx, cy), (x1, y1)], fill=(255, 245, 140, 255), width=4)
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 255, 230, 255))
    elif symbol_type == "haste":
        # Wing / swift lightning
        pts = [(cx - 6, cy - 24), (cx + 16, cy - 6), (cx + 2, cy), (cx + 18, cy + 24), 
               (cx - 14, cy + 4), (cx, cy - 2)]
        draw.polygon(pts, fill=(255, 250, 120, 255))
        draw.line(pts, fill=(255, 255, 255, 255), width=2)
        
    # Gold border
    draw.ellipse([3, 3, size - 4, size - 4], outline=(235, 195, 75, 255), width=3)
    draw.ellipse([6, 6, size - 7, size - 7], outline=(255, 235, 150, 180), width=1)
    draw.ellipse([1, 1, size - 2, size - 2], outline=(40, 25, 10, 200), width=1)
    
    return icon

def generate_sound_effects():
    """Synthesize clean, warm procedural acoustic SFX for UI and combat."""
    sample_rate = 44100
    
    def write_wav(filename, samples):
        path = os.path.join(AUDIO_DIR, "sfx", filename)
        with wave.open(path, 'w') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(sample_rate)
            raw = b"".join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples)
            wav_file.writeframes(raw)
            
    # 1. Coin pickup (warm bell-like chimes)
    samples = []
    dur = 0.35
    total = int(sample_rate * dur)
    for i in range(total):
        t = i / sample_rate
        env = math.exp(-t * 12.0)
        s = 0.6 * math.sin(2 * math.pi * 987.77 * t) + 0.4 * math.sin(2 * math.pi * 1318.5 * t)
        if t > 0.08:
            t2 = t - 0.08
            env2 = math.exp(-t2 * 10.0)
            s += 0.7 * math.sin(2 * math.pi * 1975.5 * t2) * env2
        samples.append(s * env * 0.7)
    write_wav("coin.wav", samples)
    
    # 2. Wooden button click
    samples = []
    dur = 0.08
    total = int(sample_rate * dur)
    for i in range(total):
        t = i / sample_rate
        env = math.exp(-t * 55.0)
        s = math.sin(2 * math.pi * 220.0 * t) + 0.5 * math.sin(2 * math.pi * 330.0 * t)
        samples.append(s * env * 0.8)
    write_wav("click.wav", samples)
    
    # 3. Parchment page turn (gentle filtered noise)
    samples = []
    dur = 0.28
    total = int(sample_rate * dur)
    import random
    random.seed(42)
    last = 0.0
    for i in range(total):
        t = i / sample_rate
        env = math.sin(math.pi * (t / dur)) ** 1.5
        white = random.uniform(-1.0, 1.0)
        last = 0.85 * last + 0.15 * white
        samples.append(last * env * 0.5)
    write_wav("page_turn.wav", samples)
    
    # 4. Spell cast (magical shimmering chord)
    samples = []
    dur = 0.8
    total = int(sample_rate * dur)
    for i in range(total):
        t = i / sample_rate
        env = math.exp(-t * 3.5)
        # E major magical chord + shimmer modulation
        shimmer = 1.0 + 0.2 * math.sin(2 * math.pi * 12.0 * t)
        s = (0.35 * math.sin(2 * math.pi * 659.25 * t) +   # E5
             0.30 * math.sin(2 * math.pi * 830.61 * t) +   # G#5
             0.35 * math.sin(2 * math.pi * 987.77 * t) +   # B5
             0.25 * math.sin(2 * math.pi * 1318.5 * t))    # E6
        samples.append(s * env * shimmer * 0.6)
    write_wav("spell_cast.wav", samples)
    
    # 5. Sword clash / hit
    samples = []
    dur = 0.25
    total = int(sample_rate * dur)
    for i in range(total):
        t = i / sample_rate
        env = math.exp(-t * 18.0)
        s = 0.5 * math.sin(2 * math.pi * 180.0 * (1.0 - t * 2)) + 0.4 * random.uniform(-1, 1) + 0.3 * math.sin(2 * math.pi * 1400.0 * t)
        samples.append(s * env * 0.8)
    write_wav("sword_hit.wav", samples)
    
    # 6. Victory fanfare chord
    samples = []
    dur = 1.4
    total = int(sample_rate * dur)
    for i in range(total):
        t = i / sample_rate
        env = math.exp(-t * 2.0)
        s = (0.3 * math.sin(2 * math.pi * 523.25 * t) +  # C5
             0.3 * math.sin(2 * math.pi * 659.25 * t) +  # E5
             0.3 * math.sin(2 * math.pi * 783.99 * t) +  # G5
             0.35 * math.sin(2 * math.pi * 1046.50 * t)) # C6
        samples.append(s * env * 0.65)
    write_wav("victory.wav", samples)

def main():
    print("Processing assets...")
    
    # 1. Process units into transparent PNGs & circular initiative tokens
    units = [
        ("unit_griffin", os.path.join(ART_DIR, "units", "unit_griffin.jpg")),
        ("unit_fairy_archer", os.path.join(ART_DIR, "units", "unit_fairy_archer.jpg")),
        ("unit_treant", os.path.join(ART_DIR, "units", "unit_treant.jpg")),
        ("unit_wolf", os.path.join(ART_DIR, "units", "unit_wolf.jpg")),
        ("unit_goblin", os.path.join(ART_DIR, "units", "unit_goblin.jpg")),
        ("hero_alaric", os.path.join(ART_DIR, "portraits", "hero_alaric.jpg")),
    ]
    
    tokens_dir = os.path.join(ART_DIR, "ui", "tokens")
    os.makedirs(tokens_dir, exist_ok=True)
    
    for name, path in units:
        if os.path.exists(path):
            print(f"Creating token for {name}...")
            token = create_circular_token(path, size=120)
            token.save(os.path.join(tokens_dir, f"token_{name}.png"), "PNG")
            
            # Also save transparent cutouts for battlefield
            if name != "hero_alaric":
                print(f"Removing background for {name}...")
                cutout = remove_plain_background(path, tolerance=30)
                cutout.save(os.path.join(ART_DIR, "units", f"{name}.png"), "PNG")
                
    # 2. Generate UI assets
    ui_dir = os.path.join(ART_DIR, "ui")
    os.makedirs(ui_dir, exist_ok=True)
    
    print("Generating parchment panels...")
    parchment = create_parchment_texture(640, 420)
    parchment.save(os.path.join(ui_dir, "parchment_panel.png"), "PNG")
    
    parchment_scroll = create_parchment_texture(480, 160)
    parchment_scroll.save(os.path.join(ui_dir, "parchment_scroll.png"), "PNG")
    
    print("Generating wooden buttons...")
    btn_normal = create_wood_button(260, 64, color_theme="oak")
    btn_normal.save(os.path.join(ui_dir, "btn_wood_normal.png"), "PNG")
    
    btn_hover = create_wood_button(260, 64, color_theme="light_oak")
    btn_hover.save(os.path.join(ui_dir, "btn_wood_hover.png"), "PNG")
    
    # 3. Generate spell icons
    spells_dir = os.path.join(ART_DIR, "spells")
    os.makedirs(spells_dir, exist_ok=True)
    
    spells = [
        ("spell_fireball", (180, 45, 25, 255), "fire"),
        ("spell_heal", (35, 140, 65, 255), "heal"),
        ("spell_bless", (220, 165, 35, 255), "bless"),
        ("spell_haste", (35, 110, 210, 255), "haste"),
    ]
    for sname, scolor, stype in spells:
        print(f"Creating spell icon {sname}...")
        sicon = create_spell_icon(sname, scolor, stype)
        sicon.save(os.path.join(spells_dir, f"{sname}.png"), "PNG")
        
    # 4. Generate audio SFX
    print("Synthesizing fantasy SFX...")
    generate_sound_effects()
    
    print("Asset processing complete!")

if __name__ == "__main__":
    main()
