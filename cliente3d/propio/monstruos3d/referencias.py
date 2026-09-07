"""Create a contact sheet from original outfit frames without editing the atlas."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--ids', nargs='+', type=int, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--animation', action='store_true')
args = parser.parse_args()
index = json.loads((root/'assets/sprites772/indice.json').read_text(encoding='utf-8'))
names = json.loads((root/'assets/monster_names772.json').read_text(encoding='utf-8'))
columns = max(len(index['outfits'][str(oid)]['c'][2]) for oid in args.ids) if args.animation else 4
canvas = Image.new('RGB',(200*columns,180*len(args.ids)),(35,42,47))
draw = ImageDraw.Draw(canvas)
for row, oid in enumerate(args.ids):
    outfit = index['outfits'][str(oid)]
    print(oid,names[str(oid)],'phases',[len(d) for d in outfit['c'][:4]])
    sequences = [[frame] for frame in outfit['c'][2]] if args.animation else outfit['c'][:4]
    for direction, frames in enumerate(sequences):
        rect = frames[0]
        sheet = Image.open(root/'assets/sprites772'/('lamina_%02d.png'%rect['l']))
        sprite = sheet.crop((rect['x'],rect['y'],rect['x']+rect['w'],rect['y']+rect['h']))
        sprite.thumbnail((140,140),Image.Resampling.NEAREST)
        scale = min(140//sprite.width,140//sprite.height)
        if scale>1:
            sprite = sprite.resize((sprite.width*scale,sprite.height*scale),Image.Resampling.NEAREST)
        x,y = direction*200+(200-sprite.width)//2,row*180+28
        canvas.paste(sprite,(x,y),sprite)
        draw.text((direction*200+8,row*180+8),'%d %s %s'%(oid,names[str(oid)],('frame %d'%direction) if args.animation else 'NESW'[direction]),fill='white')
canvas.save(args.output)