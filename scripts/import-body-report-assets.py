#!/usr/bin/env python3
"""Extract original report sprites from the existing BeforeVoting atlas. Requires ImageMagick."""
import json
import subprocess
import tempfile
import urllib.request
from pathlib import Path

SOURCE = 'https://raw.githubusercontent.com/AlvajoyAsante/among-us-assets/main/Voting/BeforeVoting-sharedassets0.assets-196.png'
ASSETS = Path(__file__).resolve().parents[1] / 'IRLAmongUs/Assets.xcassets'
CROPS = {
    'BodyReportStreak': '948x435+0+0',
    'BodyReportLettering': '418x207+0+435',
    'BodyReportCorpse': '180x115+450+615',
    'BodyReportSkull': '119x111+630+612',
}
with tempfile.TemporaryDirectory() as temporary:
    atlas = Path(temporary) / 'BeforeVoting.png'
    atlas.write_bytes(urllib.request.urlopen(SOURCE).read())
    for name, crop in CROPS.items():
        folder = ASSETS / (name + '.imageset')
        folder.mkdir(exist_ok=True)
        subprocess.run(['magick', str(atlas), '-crop', crop, '+repage', str(folder / (name + '.png'))], check=True)
        (folder / 'Contents.json').write_text(json.dumps({
            'images': [{'filename': name + '.png', 'idiom': 'universal', 'scale': '1x'}],
            'info': {'author': 'xcode', 'version': 1},
        }, indent=2) + '\n')
