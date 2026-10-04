"""Copies the task mini-game sprites and sounds into Assets.xcassets/Tasks.

Usage: python3 scripts/import-task-assets.py <sprites> <atlases> <sounds>

  sprites  unzipped "Tasks" sheet from https://www.spriters-resource.com/pc_computer/amongus/asset/141567/
  atlases  the Tasks folder of https://github.com/AlvajoyAsante/among-us-assets
  sounds   folder holding the unzipped "Task Panels" and "General Sounds" packs from
           https://www.sounds-resource.com/pc_computer/amongus/

Sprites are copied unchanged. Sounds are converted to AAC with macOS `afconvert` and stored as data assets.
"""
import json, shutil, subprocess, sys
from pathlib import Path

sprites, atlases, sounds = (Path(p) for p in sys.argv[1:4])
root = Path('IRLAmongUs/Assets.xcassets/Tasks')
root.mkdir(exist_ok=True)
(root/'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')

def image(name, source):
    folder = root/(name + '.imageset'); folder.mkdir(exist_ok=True)
    shutil.copyfile(source, folder/(name + '.png'))
    (folder/'Contents.json').write_text(json.dumps({'images': [{'filename': name + '.png', 'idiom': 'universal', 'scale': '1x'}],
                                                   'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')

def sound(name, source):
    folder = root/(name + '.dataset'); folder.mkdir(exist_ok=True)
    subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', '96000', str(source), str(folder/(name + '.m4a'))], check=True)
    (folder/'Contents.json').write_text(json.dumps({'data': [{'filename': name + '.m4a', 'idiom': 'universal'}],
                                                   'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')

# Fix Wiring
image('TaskWiresBack', sprites/'Fix Wiring/electricity_wiresBaseBack.png')
image('TaskWireEnd', sprites/'Fix Wiring/electricity_wires1.png')
# Upload Data
image('TaskUploadBase', sprites/'Upload Data/dataTransfer_Base.png')
for i in range(1, 6):
    image(f'TaskUploadFolderOpen{i}', sprites/f'Upload Data/dataTransfer_folderOpen000{i}.png')
image('TaskUploadFile', sprites/'Upload Data/dataTransfer_fileFill.png')
image('TaskUploadBar', sprites/'Upload Data/dataTransfer_progressBar.png')
image('TaskUploadButton', sprites/'Upload Data/dataTransfer_uploadButton.png')
# Start Reactor
image('TaskReactorBase', sprites/'Start Reactor/simonSaysBase.png')
image('TaskReactorScreen', sprites/'Start Reactor/simonSaysScreen.png')
image('TaskReactorKeypad', sprites/'Start Reactor/simonSaysButtonsShadow.png')
image('TaskReactorButton', sprites/'Start Reactor/ssbuton/ssbutton1.png')
image('TaskReactorLights', sprites/'Start Reactor/simonSaysLightsIndicationWShadows.png')
image('TaskReactorLight', sprites/'Start Reactor/sslights/sslights1.png')
# Swipe Card
image('TaskCardBackground', sprites/'Swipe Card/admin_BG.png')
image('TaskCardReaderTop', sprites/'Swipe Card/admin_sliderTop.png')
image('TaskCardReaderBottom', sprites/'Swipe Card/admin_sliderBottom.png')
image('TaskCard', sprites/'Swipe Card/admin_Card.png')
image('TaskCardWallet', sprites/'Swipe Card/admin_Wallet.png')
image('TaskCardWalletFront', sprites/'Swipe Card/admin_walletFront.png')
# Prime Shields
image('TaskShieldsScreen', sprites/'Prime Shields/shield_screen.png')
image('TaskShieldsHex', sprites/'Prime Shields/shield_Panel.png')
# Clean O2 Filter
image('TaskO2Base', sprites/'Clean O2 Filter/o2_bgBase.png')
image('TaskO2Top', sprites/'Clean O2 Filter/o2_bgTop.png')
for i in range(1, 8):
    image(f'TaskO2Leaf{i}', sprites/f'Clean O2 Filter/o2_leafs/o2_leaf{i}.png')
image('TaskO2ArrowFlashLeft', sprites/'Clean O2 Filter/leftArrow-o2_arrowFlash/leftArrow-o2_arrowFlash0005.png')
image('TaskO2ArrowFlashRight', sprites/'Clean O2 Filter/rightArrow-o2_arrowFlash/rightArrow-o2_arrowFlash0005.png')
image('TaskO2ArrowDoneLeft', sprites/'Clean O2 Filter/o2_arrowFinishedLeft.png')
image('TaskO2ArrowDoneRight', sprites/'Clean O2 Filter/o2_arrowFinishedRight.png')
# Submit Scan
image('TaskScanTop', sprites/'Submite Scan/medbayScan_panelTop.png')
image('TaskScanBottom', sprites/'Submite Scan/medbayScan_panelBottom.png')
# Divert Power (the accept panel is only in the atlas repo)
image('TaskDivertBase', sprites/'Divert Power/electricity_Divert_Base.png')
image('TaskDivertSwitch', sprites/'Divert Power/electricity_Divert_switch.png')
image('TaskDivertAcceptBase', atlases/'electricity_Receive_Bg-sharedassets0.assets-170.png')
image('TaskDivertAcceptSwitch', atlases/'electricity_Receive_switch-sharedassets0.assets-82.png')

panels, general = sounds/'Task Panels', sounds/'Among Us General Sounds'
sound('TaskSoundPanelOpen', general/'Panel_GenericAppear.wav')
sound('TaskSoundPanelClose', general/'Panel_GenericDisappear.wav')
sound('TaskSoundComplete', general/'task_Complete.wav')
sound('TaskSoundSelect', general/'UI_Select.wav')
for i in range(1, 4):
    sound(f'TaskSoundWire{i}', panels/f'panel_electrical_wire{i}.wav')
sound('TaskSoundReactorBeep', panels/'panel_reactorstart.wav')
sound('TaskSoundReactorFail', panels/'panel_reactor_startfail.wav')
sound('TaskSoundWalletOut', panels/'panel_admin_walletout.wav')
sound('TaskSoundCardMove', panels/'panel_admin_cardmove1.wav')
sound('TaskSoundCardAccept', panels/'panel_admin_cardaccept.wav')
sound('TaskSoundCardDeny', panels/'panel_admin_carddeny.wav')
sound('TaskSoundShieldOn', panels/'panel_sheildON.wav')
sound('TaskSoundShieldOff', panels/'panel_sheildOFF.wav')
sound('TaskSoundLeafGrab', panels/'panel_O2Grab.wav')
for i, name in enumerate(['panel_O2_suck1.wav', 'panel_O2_suck2.wav', 'panel_O2_Suck3.wav'], 1):
    sound(f'TaskSoundLeafSuck{i}', panels/name)
sound('TaskSoundScan', panels/'panel_medbayscan.wav')
sound('TaskSoundDivert', panels/'panel_divertpower_switch.wav')
sound('TaskSoundAccept', panels/'panel_electrical_Sabotageswitch.wav')
