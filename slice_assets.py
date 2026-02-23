from PIL import Image, ImageOps
import os

def remove_checkerboard(img):
    # This is a guestimate: if the pixel is near white or light gray in a pattern, make it transparent
    # Alternatively, most of these 'transparent' images from AI have a very specific gray/white grid.
    # We'll convert to RGBA and check color distance.
    img = img.convert("RGBA")
    datas = img.getdata()
    
    new_data = []
    for item in datas:
        # If it's very close to the common checkerboard colors:
        # White: (255, 255, 255)
        # Gray: (204, 204, 204) or similar
        # Since we want to preserve the actual content, we only remove if it's EXACTLY these or very close
        # and NOT part of the cat (which has black outlines)
        r, g, b, a = item
        if (r > 200 and g > 200 and b > 200): # White or light gray
            # Check if it's likely background
            new_data.append((r, g, b, 0)) # Make it transparent
        else:
            new_data.append(item)
    
    img.putdata(new_data)
    return img

def slice_new_guide():
    img = Image.open('prd/design_guide_2.png')
    w, h = img.size
    
    os.makedirs('frontend/static/assets/cats', exist_ok=True)
    os.makedirs('frontend/static/assets/icons', exist_ok=True)
    os.makedirs('frontend/static/assets/props', exist_ok=True)
    
    # 1. Cats (3x2 grid on the left half)
    cat_names = ['waving', 'thinking', 'celebrating', 'peeking', 'sleeping', 'jumping']
    cat_w, cat_h = 460, 460
    for i in range(2):
        for j in range(3):
            left = 30 + (j * 460)
            top = 40 + (i * 460)
            cat = img.crop((left, top, left + 430, top + 440))
            cat = remove_checkerboard(cat)
            cat.save(f'frontend/static/assets/cats/cat_{cat_names[i*3 + j]}.png')

    # 2. Big Taste Icons (Top right)
    taste_labels = ['salty', 'sweet', 'spicy', 'sour', 'oily']
    for i, label in enumerate(taste_labels):
        left = 1450 + (i * 270)
        top = 100
        icon = img.crop((left, top, left + 250, top + 300))
        icon = remove_checkerboard(icon)
        icon.save(f'frontend/static/assets/icons/taste_{label}.png')

    # 3. Big Veggies (Middle right)
    veg_labels = ['tomato', 'carrot', 'eggplant', 'mushroom', 'onion', 'pepper']
    for i, label in enumerate(veg_labels):
        left = 1450 + (i * 220)
        top = 480
        veg = img.crop((left, top, left + 200, top + 250))
        veg = remove_checkerboard(veg)
        veg.save(f'frontend/static/assets/props/prop_{label}.png')

    # 4. Small Small Icons (Bottom area)
    # Taste small
    for i, label in enumerate(taste_labels):
        left = 1450 + (i * 135)
        top = 830
        icon = img.crop((left, top, left + 130, top + 200)) # Small version with label might be here
        icon = remove_checkerboard(icon)
        icon.save(f'frontend/static/assets/icons/taste_small_{label}.png')

    # Category icons
    cat_labels = ['all', 'spicy_cat', 'soup', 'party', 'banchan']
    for i, label in enumerate(cat_labels):
        left = 1450 + (i * 135)
        top = 1100
        icon = img.crop((left, top, left + 130, top + 150))
        icon = remove_checkerboard(icon)
        icon.save(f'frontend/static/assets/icons/cat_{label}.png')

    # 5. Bottom row of props (from cat_imges top/bottom or design_guide bottom)
    # The bottom row has the tools: pot, pan, ladle, whisk, board
    tool_labels = ['pot', 'pan', 'ladle', 'whisk', 'board']
    for i, label in enumerate(tool_labels):
        left = 30 + (i * 300)
        top = 1150
        tool = img.crop((left, top, left + 280, top + 350))
        tool = remove_checkerboard(tool)
        tool.save(f'frontend/static/assets/props/tool_{label}.png')

if __name__ == '__main__':
    slice_new_guide()
    print("Clean slicing from design_guide_2.png complete!")
