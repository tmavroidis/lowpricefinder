from PIL import Image, ImageDraw
import os

os.makedirs('assets/icon', exist_ok=True)

# 1. Generate master 1024x1024 icon
size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

margin = 64
radius = 180

def draw_rounded_rect(draw, bbox, radius, fill):
    x0, y0, x1, y1 = bbox
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.pieslice([x0, y0, x0 + radius * 2, y0 + radius * 2], 180, 270, fill=fill)
    draw.pieslice([x1 - radius * 2, y0, x1, y0 + radius * 2], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - radius * 2, x0 + radius * 2, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - radius * 2, y1 - radius * 2, x1, y1], 0, 90, fill=fill)

# Background card with deep slate/indigo tone (#1E293B)
draw_rounded_rect(draw, (margin, margin, size - margin, size - margin), radius, (30, 41, 59, 255))

# Barcode white card background
barcode_box = (180, 260, 844, 720)
draw_rounded_rect(draw, barcode_box, 24, (255, 255, 255, 255))

bar_pattern = [
    4, 2, 1, 3, 2, 4, 1, 2, 3, 1,
    2, 2, 4, 1, 3, 2, 1, 4, 2, 3,
    1, 2, 4, 2, 1, 3, 2, 1, 4, 2,
    3, 1, 2, 4, 2, 1, 3, 4, 2, 1
]

start_x = 230
end_x = 794
total_units = sum(bar_pattern)
available_width = end_x - start_x
unit_width = available_width / total_units

current_x = start_x
bar_y0 = 310
bar_y1 = 600

for i, width_units in enumerate(bar_pattern):
    w = int(width_units * unit_width)
    if i % 2 == 0:
        draw.rectangle([current_x, bar_y0, current_x + w, bar_y1], fill=(15, 23, 42, 255))
    current_x += w

# Vibrant red laser scan line
laser_y = 455
draw.rectangle([200, laser_y - 5, 824, laser_y + 5], fill=(239, 68, 68, 255))
draw.rectangle([200, laser_y - 2, 824, laser_y + 2], fill=(255, 255, 255, 255))

master_icon_path = 'assets/icon/app_icon.png'
img.save(master_icon_path)
print("Successfully generated master icon:", master_icon_path)

# 2. Generate Android mipmap icons
android_mipmaps = [
    ('mipmap-mdpi', 48),
    ('mipmap-hdpi', 72),
    ('mipmap-xhdpi', 96),
    ('mipmap-xxhdpi', 144),
    ('mipmap-xxxhdpi', 192),
]

for folder, dim in android_mipmaps:
    dir_path = os.path.join('android', 'app', 'src', 'main', 'res', folder)
    os.makedirs(dir_path, exist_ok=True)
    out_path = os.path.join(dir_path, 'ic_launcher.png')
    resized = img.resize((dim, dim), Image.ANTIALIAS)
    resized.save(out_path)
    print(f"Generated Android {folder}: {dim}x{dim}")

# 3. Generate iOS app icons
ios_dir = os.path.join('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
os.makedirs(ios_dir, exist_ok=True)

ios_icons = [
    ('Icon-App-20x20@1x.png', 20),
    ('Icon-App-20x20@2x.png', 40),
    ('Icon-App-20x20@3x.png', 60),
    ('Icon-App-29x29@1x.png', 29),
    ('Icon-App-29x29@2x.png', 58),
    ('Icon-App-29x29@3x.png', 87),
    ('Icon-App-40x40@1x.png', 40),
    ('Icon-App-40x40@2x.png', 80),
    ('Icon-App-40x40@3x.png', 120),
    ('Icon-App-60x60@2x.png', 120),
    ('Icon-App-60x60@3x.png', 180),
    ('Icon-App-76x76@1x.png', 76),
    ('Icon-App-76x76@2x.png', 152),
    ('Icon-App-83.5x83.5@2x.png', 167),
    ('Icon-App-1024x1024@1x.png', 1024),
]

for filename, dim in ios_icons:
    out_path = os.path.join(ios_dir, filename)
    resized = img.resize((dim, dim), Image.ANTIALIAS)
    resized.save(out_path)
    print(f"Generated iOS icon {filename}: {dim}x{dim}")

print("All Android and iOS barcode launcher icons successfully generated!")
