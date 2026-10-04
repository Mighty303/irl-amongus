#!/usr/bin/env python3
"""Find visible visor components in the exact neck-kill frames; hide heads when the visor turns away."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
assets = root / 'IRLAmongUs/Assets.xcassets'

def head(image, left, right):
    pixels = image.load()
    points = set()
    for y in range(70, 125):
        for x in range(left, right):
            r, g, b = pixels[x, y]
            if b > r + 12 and g > r + 12 and b > 90:
                points.add((x, y))
    components = []
    while points:
        start = points.pop()
        todo, component = [start], [start]
        while todo:
            x, y = todo.pop()
            for point in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)]:
                if point in points:
                    points.remove(point)
                    todo.append(point)
                    component.append(point)
        components.append(component)
    largest = max(components, key=len, default=[])
    if len(largest) < 100:
        return None
    xs, ys = zip(*largest)
    return dict(x=(min(xs)+max(xs))/2-1.5, y=(min(ys)+max(ys))/2-3, width=32, rotation=0)

frames = []
for path in sorted((assets/'KillAnimation').glob('NeckKillFrame*.imageset/*.png')):
    image = Image.open(path).convert('RGB')
    frames.append(dict(attacker=head(image, 110, 150), victim=head(image, 165, 230)))
output = assets/'NeckKillFacePlacements.dataset'
output.mkdir(exist_ok=True)
(output/'placements.json').write_text(json.dumps(dict(width=image.width, height=image.height, frames=frames), indent=2)+'\n')
(output/'Contents.json').write_text(json.dumps(dict(data=[dict(filename='placements.json', idiom='universal')],
                                                   info=dict(author='xcode', version=1)), indent=2)+'\n')
print(f'{len(frames)} frames; {sum(f["victim"] is not None for f in frames)} visible victim heads')
