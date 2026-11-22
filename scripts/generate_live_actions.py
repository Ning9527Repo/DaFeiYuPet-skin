#!/usr/bin/env python3
"""Hand-authored native reenactments. No GIF trace/extraction, network or AI synthesis.
Every catalog id gets an explicit semantic plan, keyed body timeline and actual drawn props.
Shared primitives represent the same motor skill (eating, writing), not claimed GIF parity.
"""
from pathlib import Path
import json, math, plistlib
ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'layout/Library/Application Support/MowangDaFeiYuPet'
# kind | expression | prop(s) | choreography distinction
PLANS='''
idle|neutral|-|0
look|neutral|-|0
drag|drag|-|0
hop|happy|sparkle|0
shy|surprised|blush|0
angry|neutral|anger|0
laugh|happy|tickle|0
wave|happy|-|0
walk|neutral|-|0
float|happy|cloud|0
run|neutral|dust|0
hum|happy|notes|0
stretch|neutral|-|0
tap|neutral|desk|0
squat|surprised|-|0
yawn|sleep|sleepy|0
sleep|sleep|sleepy|0
bow|happy|-|0
startle|surprised|surprise|0
turn|neutral|-|0
snack|surprised|snack|0
tail|happy|impact|0
do wake|sleep|sleepy|0
mirror|happy|mirror|0
palette|happy|swatches|0
write|neutral|notebook,pencil|0
type|neutral|laptop|0
fan|happy|fan|0
brush|happy|toothbrush,foam|0
cube|neutral|cube|0
car|happy|car|0
bubbles|happy|bubbles|0
smash|surprised|block,shards|0
game|neutral|controller,anger|0
water|happy|watergun,water|0
violin|happy|violin,bow|0
whale|surprised|whale,waves|0
dance|happy|-|0
dance|happy|notes|1
dance|happy|heart|2
balloon|surprised|balloon|0
animals|happy|cat,bird|0
kite|happy|kite|0
gift|surprised|gift,confetti|0
magic|surprised|hat,bird|0
cards|happy|cards|0
top|happy|top,whip|0
flute|happy|flute,notes|0
flowers|happy|butterfly,bee,flower|0
petcat|happy|cat|0
bloom|surprised|flower,sparkle|0
ride|happy|rockinghorse|0
juggle|happy|ball|0
kick|happy|shuttlecock|0
board|neutral|board,stone|0
swing|happy|swing|0
eat|happy|rice,chopsticks|0
eat|happy|snack|1
eat|surprised|token|2
eat|happy|toast,egg|3
eat|happy|lunch,chopsticks|4
eat|happy|dinner,chopsticks|5
icecream|surprised|icecream,drop|0
eat|happy|crab|6
eat|happy|tanghulu|7
noodles|happy|noodles,chopsticks|0
eat|happy|watermelon|8
hotpot|happy|hotpot,chopsticks|0
leaves|surprised|leaves|0
moon|happy|moon,mooncake|0
snowman|happy|snowman,snow|0
fireworks|surprised|fireworks|0
eat|happy|zongzi|9
eat|happy|niangao|10
eat|happy|qingtuan|11
eat|happy|congee,spoon|12
eat|happy|cake|13
redpacket|happy|redpacket,coin|0
write|happy|fu,pencil|1
needle|neutral|needle,thread|0
lion|happy|lion|0
pumpkin|happy|pumpkin,candy|0
plant|happy|chrysanthemum,zhuyu|0
river|happy|riverlantern,waves|0
ghost|surprised|ghost|0
tree|happy|tree,ornament|0
lantern|happy|sky_lantern|0
eat|happy|tangyuan,spoon|14
eat|happy|dumpling,chopsticks|15
choose|neutral|menu,question|0
think|neutral|thought|0
money|happy|moneybag,coin|0
money|happy|moneybag,coin|1
money|neutral|moneybag|2
money|neutral|moneybag,coin|3
money|surprised|emptybag|4
money|sleep|emptybag,tear|5
wipe|happy|desk,cloth|0
stare|neutral|thought|0
talk|happy|screen,chat|0
think|neutral|thought|1
type|neutral|screen|1
archive|happy|files|0
pace|neutral|-|0
hop|happy|confetti|1
sigh|sleep|sweat|0
'''.strip().splitlines()
CHANNELS=['x','y','angle','sx','sy','waist','head','armNear','armFar','legBack','legFront','tail','fin','ahoge','sit','yaw','lookX','lookY','mouth']
DEG=math.pi/180

def pose(**kw):
 d={k:0 for k in CHANNELS};d.update(sx=1,sy=1);d.update(kw)
 for k in ['angle','waist','head','armNear','armFar','legBack','legFront','tail','fin','ahoge']:d[k]*=DEG
 return d

def beat(kind,alt):
 # Neutral → preparation → contact → follow-through → recover. Values use original model's pivots.
 if kind=='idle':return [pose(head=-1,sy=1.006),pose(head=1,sy=.994),pose(head=-1),pose(head=1)]
 if kind=='tap':return [pose(armNear=40,head=8),pose(armNear=18,head=3),pose(armNear=50,head=9),pose(armNear=16,head=2)]
 if kind in ('walk','run','pace'):return [pose(y=-2,legBack=20,legFront=-22,armNear=-14,armFar=17,angle=4 if kind=='run' else 0),pose(y=1,legBack=-22,legFront=20,armNear=18,armFar=-15,angle=6 if kind=='run' else -2)]*2
 if kind=='float':return [pose(y=-12,armNear=24,armFar=-20,legBack=-12,legFront=10),pose(y=-5,armNear=12,armFar=-8)]*2
 if kind=='look':return [pose(head=-7,yaw=-.35,lookX=-3),pose(head=6,yaw=.4,lookX=3),pose(head=-3,lookY=-2),pose()]
 if kind=='drag':return [pose(angle=-7,armNear=60,armFar=-42,legBack=-12,legFront=14,tail=22),pose(angle=7,armNear=88,armFar=-60,legBack=14,legFront=-12,tail=-22)]*2
 if kind in ('hop','smash'):return [pose(y=6,sy=.96,armNear=-8),pose(y=-25-alt*3,armNear=80,armFar=-65,legBack=-16,legFront=14),pose(y=4,sx=1.03,sy=.96,armNear=25),pose()]
 if kind=='stretch':return [pose(armNear=30,armFar=-28,head=-6),pose(sy=1.04,armNear=125,armFar=-100,head=-14,tail=18),pose(sy=1.02,armNear=115,armFar=-90,angle=4),pose(armNear=15)]
 if kind in ('squat','car','board','snowman'):return [pose(y=8,sy=.97,armNear=12),pose(y=17,sit=1,armNear=40,armFar=-20,head=12),pose(y=17,sit=1,armNear=55,armFar=-10,head=7),pose(y=4,sit=.15)]
 if kind in ('sleep','do wake','yawn'):return [pose(head=7,armNear=5,sy=.99),pose(head=14,sit=.7 if kind!='yawn' else 0,y=11 if kind!='yawn' else 0,armNear=70 if kind=='yawn' else -3),pose(head=-12 if kind=='do wake' else 16,y=-8 if kind=='do wake' else 10,sit=0 if kind in ('do wake','yawn') else 1,armNear=65 if kind=='do wake' else 3),pose(head=2 if kind=='do wake' else 8)]
 if kind=='bow':return [pose(waist=10,head=8,armNear=-6,armFar=6),pose(y=6,waist=24,head=16,armNear=-12,armFar=10),pose(y=6,waist=24,head=16),pose(waist=8)]
 if kind=='turn':return [pose(yaw=.45,head=-3),pose(yaw=1,head=0),pose(yaw=-.7,head=3),pose(yaw=-.3)]
 if kind=='wave':return [pose(armNear=95,head=-5),pose(armNear=118,head=3),pose(armNear=92,head=-4),pose(armNear=116)]
 if kind in ('shy','angry','laugh','startle','tail','sigh','stare','hum','talk','think','choose'):
  return {
   'shy':[pose(head=8,armNear=-15,armFar=12),pose(head=-4,yaw=-.25,armNear=-22),pose(head=10,yaw=.2,armFar=18),pose(head=3)],
   'angry':[pose(head=-8,armNear=22,armFar=-18,fin=16),pose(angle=-3,head=8,armNear=30,tail=-12),pose(angle=3,head=-6,armFar=-25),pose(head=-4)],
   'laugh':[pose(y=-2,head=-6,armNear=16),pose(y=2,head=9,armFar=-22),pose(y=-3,head=-9,armNear=23),pose(y=2,head=5)],
   'startle':[pose(y=4,sy=.96),pose(y=-17,armNear=75,armFar=-65,tail=25,fin=-22,ahoge=-20),pose(y=2,armNear=35,head=5),pose(head=-4)],
   'tail':[pose(tail=20,head=-6),pose(tail=-35,armNear=12),pose(tail=18),pose(tail=-38,head=5)],
   'sigh':[pose(head=3),pose(head=18,sy=.98,armNear=-7,fin=-18,tail=-16),pose(y=3,head=12,armNear=-10),pose(head=9)],
   'stare':[pose(head=-4,lookY=-2),pose(head=3,lookX=2),pose(head=-2,lookX=-2),pose()],
   'hum':[pose(head=-6,angle=-2,mouth=.4),pose(head=6,angle=2,mouth=.7),pose(head=-4,mouth=.2),pose(head=4,mouth=.5)],
   'talk':[pose(armNear=16,head=-4,mouth=.7),pose(armNear=32,head=4,mouth=.2),pose(armNear=10,mouth=.8),pose(head=-2,mouth=.3)],
   'think':[pose(head=-9-alt*2,armNear=54,lookY=-2),pose(head=-5,armNear=64,lookX=-2),pose(head=4,armNear=56),pose(head=-8)],
   'choose':[pose(head=-5,armNear=45,lookX=-3),pose(head=4,armNear=20,lookX=3),pose(head=-7,armNear=60,lookY=-3),pose(head=3)]
  }[kind]
 if kind=='dance':return [pose(x=-4,angle=-4-alt*2,armNear=40+alt*15,armFar=-15,legFront=-13),pose(y=-5,angle=3+alt*2,armNear=12,armFar=-45-alt*10,legBack=15),pose(x=4,angle=5+alt,armNear=60,armFar=-10),pose(y=-3,angle=-3,armNear=22,armFar=-50)]
 # Contact-specific skills, never selected by a wildcard or unknown action.
 contact={
 'snack':(62,-12,8),'mirror':(54,-12,-5),'palette':(20,-18,-3),'write':(38,-16,10),'type':(35,-25,7),'fan':(85,-5,-5),'brush':(78,-7,4),'cube':(48,-35,8),'bubbles':(30,-12,-3),'game':(45,-38,5),'water':(62,-24,-5),'violin':(65,-60,-4),'whale':(90,-75,-10),'balloon':(66,-48,-4),'animals':(25,-15,-4),'kite':(88,-20,-10),'gift':(45,-35,7),'magic':(75,-12,-7),'cards':(52,-22,-3),'top':(75,-10,12),'flute':(83,-65,-3),'flowers':(38,-22,-7),'petcat':(26,-15,12),'bloom':(80,-40,-7),'ride':(40,-35,1),'juggle':(65,-55,-4),'kick':(20,-12,0),'swing':(90,-78,-4),'eat':(76,-28,3),'icecream':(66,-12,2),'noodles':(85,-22,8),'hotpot':(50,-18,10),'leaves':(70,-55,5),'moon':(60,-15,-12),'fireworks':(80,-50,-16),'redpacket':(42,-28,6),'needle':(52,-47,10),'lion':(112,-98,-7),'pumpkin':(36,-18,5),'plant':(44,-15,7),'river':(35,-30,9),'ghost':(85,-70,-6),'tree':(92,-35,-11),'lantern':(100,-85,-10),'money':(50,-30,8),'wipe':(45,-14,12),'archive':(52,-28,7)
 }
 if kind not in contact:raise ValueError('Unauthored skill: '+kind)
 n,f,h=contact[kind];out=[]
 for j in range(4):
  k=1 if j%2 else -1;d=pose(armNear=n+k*(6+alt%3),armFar=f-k*5,head=h+k*2,mouth=.7 if kind in ('eat','icecream','noodles','hotpot','snack','flute','balloon','bubbles','brush') else 0)
  if kind in ('kick','juggle'):d['legFront']=(-30 if j%2 else 12)*DEG;d['y']=-3 if j%2 else 0
  if kind in ('ride','swing'):d['sit']=1;d['y']=8+6*k;d['angle']=k*8*DEG
  if kind=='ghost':d['y']=-10+5*k
  if kind=='wipe':d['armNear']=(30+j*9)*DEG;d['x']=k*2
  if kind=='money' and alt>=4:d['head']=15*DEG;d['armNear']=(-5+j*4)*DEG;d['fin']=-12*DEG
  out.append(d)
 return out

def main():
 cat=plistlib.loads((ASSET/'catalog.plist').read_bytes());assert len(cat)==len(PLANS)==106
 clips=[]
 for a,plan in zip(cat,PLANS):
  kind,face,props,variant=plan.split('|');variant=int(variant);beats=beat(kind,variant)
  # Multiple body beats per source-length clip; every entry starts and ends neutral.
  keys=[{'t':0,'pose':pose()}]
  for i in range(12):keys.append({'t':.08+i*.073,'pose':beats[i%len(beats)]})
  keys.append({'t':1,'pose':pose()})
  clips.append({'id':a['id'],'title':a['title'],'category':a['category'],'duration':round(sum(a['durations']),4),'kind':kind,'variant':variant,'expression':face,'props':[] if props=='-' else props.split(','),'keys':keys})
 d={'version':1,'representation':'native keyframed reenactment, not original GIF or full upstream motion capture','channels':CHANNELS,'clips':clips}
 p=ASSET/'LiveActions/actions.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,separators=(',',':'))+'\n')
 print('Wrote',len(clips),'explicit action plans;',len(set(p for a in clips for p in a['props'])),'required props;',sum(len(a['keys']) for a in clips),'keyframes')
if __name__=='__main__':main()
