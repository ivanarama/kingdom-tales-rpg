from PIL import Image
import numpy as np

def make_transparent(input_path, output_path, target_size=(64, 64)):
    img = Image.open(input_path).convert('RGBA')
    arr = np.array(img)
    r = arr[:, :, 0].astype(int)
    g = arr[:, :, 1].astype(int)
    b = arr[:, :, 2].astype(int)
    
    # White background threshold: high brightness and low saturation
    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    sat = max_c - min_c
    
    is_white = (r > 235) & (g > 235) & (b > 235) & (sat < 20)
    arr[is_white, 3] = 0
    
    # Bottom gray silhouettes in up_img
    is_gray_bottom = (r > 110) & (r < 140) & (g > 110) & (g < 140) & (b > 110) & (b < 140) & (sat < 10)
    # Only for y > 0.85
    y_indices = np.arange(arr.shape[0])[:, None]
    is_bottom = y_indices > int(arr.shape[0] * 0.88)
    arr[is_gray_bottom & is_bottom, 3] = 0

    cleaned = Image.fromarray(arr)
    bbox = cleaned.getbbox()
    if bbox:
        cropped = cleaned.crop(bbox)
        # Resize while keeping aspect ratio inside target_size
        cropped.thumbnail(target_size, Image.Resampling.LANCZOS)
        # Create centered canvas
        canvas = Image.new('RGBA', target_size, (0, 0, 0, 0))
        offset = ((target_size[0] - cropped.width) // 2, (target_size[1] - cropped.height) // 2)
        canvas.paste(cropped, offset)
        canvas.save(output_path, 'PNG')
        print(f"Saved: {output_path} ({canvas.size})")

make_transparent(
    r'C:\Users\ibrog\.gemini\antigravity-cli\brain\9c38f687-b7f6-469c-adb6-a4afd29e24c3\knight_horse_up_1790283033344.jpg',
    'assets/art/world/hero_up.png',
    (64, 64)
)

make_transparent(
    r'C:\Users\ibrog\.gemini\antigravity-cli\brain\9c38f687-b7f6-469c-adb6-a4afd29e24c3\knight_horse_down_1790283061518.jpg',
    'assets/art/world/hero_down.png',
    (64, 64)
)

# Also create hero_side.png centered at (64, 64)
side_orig = Image.open('assets/art/world/hero.png').convert('RGBA')
bbox_s = side_orig.getbbox()
if bbox_s:
    c_side = side_orig.crop(bbox_s)
    c_side.thumbnail((64, 64), Image.Resampling.LANCZOS)
    canvas_s = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    canvas_s.paste(c_side, ((64 - c_side.width) // 2, (64 - c_side.height) // 2))
    canvas_s.save('assets/art/world/hero_side.png', 'PNG')
    print("Saved: assets/art/world/hero_side.png")
