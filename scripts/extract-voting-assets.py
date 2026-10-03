import json, subprocess, sys
from pathlib import Path
src=sys.argv[1]
root=Path('IRLAmongUs/Assets.xcassets')
def asset(name, geometry, black=False, scale='1x'):
    folder=root/(name+'.imageset'); folder.mkdir(exist_ok=True)
    command=['magick',src,'-crop',geometry,'+repage','-transparent','#a800be']
    if black: command+=['-fill','none','-draw','color 0,0 floodfill']
    command += [str(folder/(name+'.png'))]
    subprocess.run(command,check=True)
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':name+'.png','idiom':'universal','scale':scale}], 'info':{'author':'xcode','version':1}},indent=2)+'\n')
asset('VotingTablet','856x579+8+8',scale='3x')
# Keep the original rail and render its round home button separately to prevent stretching it.
p=root/'VotingTablet.imageset/VotingTablet.png'
subprocess.run(['magick',str(p),'(',str(p),'-crop','64x80+782+140','+repage',')','-geometry','+782+240','-composite',str(p)],check=True)
asset('VotingTabletHome','50x50+799+267',black=True,scale='3x')
asset('VotingGlass','735x511+872+8',scale='3x')
asset('VotingPlayerCard','552x63+8+595',scale='3x')
asset('VotingStamp','36x36+241+665',black=True)
asset('VotingDeadCross','66x66+285+665',black=True)
asset('VotingReporter','70x70+359+665',black=True)
asset('VotingConfirm','51x51+569+665',black=True)
asset('VotingCancel','50x50+511+665',black=True)
asset('VotingChat','55x61+628+665',black=True)
asset('VotingSkip','110x37+995+665',black=True)
asset('VotingExit','65x65+1243+665',black=True)
asset('VotingCrewSource','43x44+20+665',black=True)
# Recolor only the red suit pixels; preserve the original visor and shading.
colors=[(227,89,184),(207,31,46),(117,64,191),(38,69,209),(92,224,48),
        (15,125,69),(125,87,56),(247,130,31),(242,224,56),(110,122,128)]
raw=subprocess.check_output(['magick',str(root/'VotingCrewSource.imageset/VotingCrewSource.png'),'-depth','8','rgba:-'])
for index,color in enumerate(colors):
    pixels=bytearray(raw)
    for offset in range(0,len(pixels),4):
        r,g,b,a=pixels[offset:offset+4]
        if r>70 and r>g*1.5 and r>b*1.5 and a:
            for channel in range(3): pixels[offset+channel]=round(color[channel]*r/255)
    name=f'VotingCrew{index}'
    folder=root/(name+'.imageset'); folder.mkdir(exist_ok=True)
    subprocess.run(['magick','-size','43x44','-depth','8','rgba:-',str(folder/(name+'.png'))],input=pixels,check=True)
    (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':name+'.png','idiom':'universal','scale':'1x'}], 'info':{'author':'xcode','version':1}},indent=2)+'\n')
