#!/usr/bin/env python3
"""Import the Among Us game sounds (meetings, voting, ejection, sabotage, players leaving, the impostor's kill).

Usage: python3 scripts/import-game-sounds.py

Downloads the "General Sounds" and "Player" packs from
https://www.sounds-resource.com/pc_computer/amongus/ (uploaded by imJJ), converts the sounds below to
AAC with macOS `afconvert`, and stores them as data assets in IRLAmongUs/Assets.xcassets/Sounds.
"""
import io
import json
import subprocess
import tempfile
import zipfile
from pathlib import Path

PACKS = {
    'general': 'https://www.sounds-resource.com/media/assets/428/431696.zip',
    'player': 'https://www.sounds-resource.com/media/assets/428/431302.zip',
}
SOUNDS = {
    'SoundEmergencyMeeting': ('general', 'alarm_emergencymeeting.wav'),
    'SoundSabotageAlarm': ('general', 'Alarm_sabotage.wav'),
    'SoundEjectText': ('general', 'eject_text.wav'),
    'SoundVote': ('general', 'votescreen_avote.wav'),
    'SoundVoteLockIn': ('general', 'votescreen_lockin.wav'),
    'SoundVoteTimer': ('general', 'vote_timer.wav'),
    'SoundPanelAppear': ('general', 'Panel_GenericAppear.wav'),
    'SoundPanelDisappear': ('general', 'Panel_GenericDisappear.wav'),
    'SoundPlayerLeft': ('player', 'playerdisconnect.wav'),
    'SoundImpostorKill': ('player', 'impostor_kill.wav'),
}
ASSETS = Path(__file__).resolve().parents[1] / 'IRLAmongUs/Assets.xcassets/Sounds'


def download(url):
    data = subprocess.run(['curl', '-sfL', '-A', 'Mozilla/5.0', url], check=True, capture_output=True).stdout
    return zipfile.ZipFile(io.BytesIO(data))


ASSETS.mkdir(exist_ok=True)
(ASSETS / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
packs = {name: download(url) for name, url in PACKS.items()}
with tempfile.TemporaryDirectory() as temporary:
    for name, (pack, filename) in SOUNDS.items():
        member = next(m for m in packs[pack].namelist() if Path(m).name == filename)
        source = Path(temporary) / filename
        source.write_bytes(packs[pack].read(member))
        folder = ASSETS / (name + '.dataset')
        folder.mkdir(exist_ok=True)
        subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', '96000', str(source), str(folder / (name + '.m4a'))], check=True)
        (folder / 'Contents.json').write_text(json.dumps({'data': [{'filename': name + '.m4a', 'idiom': 'universal'}],
                                                          'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
        print(name, '<-', filename)
