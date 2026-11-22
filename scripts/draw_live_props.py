#!/usr/bin/env python3
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[1];DEST=ROOT/'layout/Library/Application Support/MowangDaFeiYuPet/LiveActions'
FONT='/usr/share/fonts/noto/NotoSansCJK-Bold.ttc'
# Self-authored prop art, NOT screenshots or emoji placeholders. Every required asset has a drawing branch.
def draw(name):
 im=Image.new('RGBA',(384,384));d=ImageDraw.Draw(im);S=3
 def b(v):return tuple(int(x*S) for x in v)
 def ellipse(r,c,o=None,w=2):d.ellipse(b(r),fill=c,outline=o,width=w*S)
 def rect(r,c,o=None,w=2):d.rectangle(b(r),fill=c,outline=o,width=w*S)
 def rr(r,c,o=None,w=2):d.rounded_rectangle(b(r),radius=6*S,fill=c,outline=o,width=w*S)
 def line(p,c='#4A4250',w=3):d.line([(int(x*S),int(y*S)) for x,y in p],fill=c,width=w*S,joint='curve')
 def poly(p,c,o=None):d.polygon([(int(x*S),int(y*S)) for x,y in p],fill=c);line(p+[p[0]],o,2) if o else None
 def text(t,x=64,y=64,size=28,c='#4A4250'):d.text((x*S,y*S),t,font=ImageFont.truetype(FONT,size*S),fill=c,anchor='mm')
 def star(x,y,r,c):poly([(x+math.cos(-math.pi/2+i*math.pi/5)*r*(1 if i%2==0 else .42),y+math.sin(-math.pi/2+i*math.pi/5)*r*(1 if i%2==0 else .42)) for i in range(10)],c)
 def bowl(color='#F7F1DC',rice=False):ellipse((18,45,110,78),'#DADCE7','#585271');poly([(20,62),(37,104),(91,104),(109,62)],color,'#585271');ellipse((20,47,108,76),'#FFF9EC','#585271');ellipse((29,39,99,73),'#FFFFFF') if rice else None
 def plate():ellipse((7,36,121,111),'#F4F4FA','#6D6D93');ellipse((17,45,111,100),'#E6EFF7')
 def flower(x,y,r,c):
  for a in range(6):k=a*math.pi/3;cx=x+math.cos(k)*r*.6;cy=y+math.sin(k)*r*.6;ellipse((cx-r*.4,cy-r*.4,cx+r*.4,cy+r*.4),c)
  ellipse((x-r*.3,y-r*.3,x+r*.3,y+r*.3),'#FFD653')
 def cat(x=64,y=65):ellipse((x-33,y-25,x+33,y+29),'#E8B37D','#6C4D4D');poly([(x-32,y-12),(x-28,y-43),(x-6,y-25)],'#E8B37D','#6C4D4D');poly([(x+7,y-25),(x+28,y-42),(x+32,y-10)],'#E8B37D','#6C4D4D');ellipse((x-17,y-5,x-10,y+2),'#393344');ellipse((x+10,y-5,x+17,y+2),'#393344');poly([(x-4,y+8),(x+4,y+8),(x,y+13)],'#E9919C')
 def coin(x,y,r=18):ellipse((x-r,y-r,x+r,y+r),'#FFC94E','#CE8C25');ellipse((x-r+5,y-r+5,x+r-5,y+r-5),'#FFE48D','#CE8C25')
 if name in ['rice','congee','tangyuan','noodles']:
  bowl('#DDF0F5',name=='rice')
  if name=='congee':ellipse((22,48,106,73),'#CBA66B');[ellipse((x,y,x+4,y+4),'#783749') for x,y in [(36,57),(48,66),(68,53),(89,61)]]
  if name=='tangyuan':
   for x,y in [(40,57),(62,50),(82,61),(59,66)]:ellipse((x-10,y-7,x+10,y+7),'#FFFDF5','#DCCDC8')
  if name=='noodles':
   for k in range(7):line([(35+k*8,62),(37+k*8,52),(40+k*7,43),(38+k*7,29)],'#DEB356',2)
 elif name in ['lunch','dinner','toast','egg','cake','niangao','qingtuan','dumpling','mooncake','zongzi']:
  plate()
  if name in ['lunch','dinner']:
   ellipse((25,49,65,87),'#FFFFFF','#D9D1C7');ellipse((69,58,105,87),'#AE6D4C');flower(84,56,13,'#65AA73')
   if name=='dinner':line([(72,64),(97,80)],'#643E3F',4)
  elif name=='toast':rr((30,25,98,97),'#D99650','#895B38');rr((37,32,91,89),'#FBE4A6');rr((54,49,76,68),'#FFE35F')
  elif name=='egg':ellipse((27,45,103,96),'#FFFDF3','#CFB7A7');ellipse((50,53,82,84),'#FFC536')
  elif name in ['cake','niangao']:poly([(30,82),(31,48),(92,48),(102,91)],'#FFF0D9','#BE875E');rect((33,62,95,69),'#F0A2AD');ellipse((58,34,76,51),'#D9556C')
  elif name=='qingtuan':
   for x in [40,66,90]:ellipse((x-19,49,x+18,85),'#6CB76B','#426E4C')
  elif name=='dumpling':
   for x in [40,75]:ellipse((x-22,53,x+20,87),'#F8E6C5','#BF9777');line([(x-18,68),(x-10,58),(x,68),(x+8,58),(x+17,70)],'#BF9777',2)
  elif name=='mooncake':rr((34,43,98,96),'#BE783C','#80582D');rr((42,51,90,88),'#E7AD61');text('月',65,70,25,'#8B5B30')
  elif name=='zongzi':poly([(64,24),(26,94),(107,89)],'#4D9564','#376446');line([(50,49),(99,85)],'#F6DD94',4);line([(43,66),(88,83)],'#F6DD94',3)
 elif name=='watermelon':poly([(17,41),(112,41),(65,110)],'#E95C69','#468C63');line([(17,41),(65,110),(112,41)],'#70BB7E',7);[ellipse((x,y,x+3,y+7),'#52353F') for x,y in [(44,56),(66,65),(85,54),(62,83)]]
 elif name=='crab':ellipse((37,47,91,86),'#EA7D4F','#A94E43');[line([(40,61+i*7),(19,55+i*12),(8,65+i*10)],'#D46445',5) for i in range(3)];[line([(88,61+i*7),(110,55+i*12),(120,65+i*10)],'#D46445',5) for i in range(3)];ellipse((19,23,44,50),'#E8794F');ellipse((88,23,113,50),'#E8794F');ellipse((50,40,56,50),'#333447');ellipse((75,40,81,50),'#333447')
 elif name=='tanghulu':line([(66,20),(54,119)],'#B87943',4);[ellipse((46,20+i*24,81,53+i*24),'#DC4B60','#A63F47') for i in range(3)]
 elif name=='icecream':poly([(42,66),(91,66),(66,116)],'#E9B576','#AA7C52');[line([(45+i*8,71),(70+i*2,108)],'#BE895B',2) for i in range(5)];ellipse((34,24,98,80),'#F5ADC9','#C57C9F');ellipse((46,17,87,45),'#FFDBEA')
 elif name in ['snack','token','candy']:
  if name=='snack':rr((28,18,103,112),'#F7BF5A','#AD7654');poly([(39,19),(49,12),(63,20),(77,13),(92,20)],'#F9D785');ellipse((47,47,86,85),'#E8A24A');text('脆',66,65,23,'#FFF9DF')
  elif name=='token':coin(64,65,43);text('T',64,64,45,'#BB7A31')
  else:poly([(39,52),(14,35),(14,84),(39,71)],'#E99BD1');poly([(90,52),(115,35),(115,84),(90,71)],'#E99BD1');rr((34,40,95,85),'#F4B1D9','#A369B0');line([(48,43),(77,81)],'#FFF8EE',8)
 elif name=='hotpot':ellipse((15,44,114,104),'#A8564B','#6E434A');rr((5,56,27,74),'#97554E');rr((101,56,124,74),'#97554E');ellipse((17,30,112,77),'#E78E43','#6E434A');line([(64,34),(57,70)],'#E5C589',5);ellipse((30,44,47,58),'#D64540');ellipse((78,41,98,59),'#79B26C')
 elif name in ['chopsticks','pencil','needle','spoon','flute','toothbrush','bow','whip','thread']:
  if name=='chopsticks':line([(20,104),(101,18)],'#9C674B',5);line([(36,112),(112,26)],'#C18C59',5)
  elif name=='pencil':poly([(18,107),(31,81),(98,13),(109,24),(42,94)],'#F4C35B','#986C47');poly([(18,107),(25,88),(36,99)],'#E9C6A3');line([(94,18),(104,28)],'#E39EAB',9)
  elif name=='needle':line([(25,108),(104,22)],'#899AA9',3);ellipse((93,13,110,36),None,'#899AA9',3)
  elif name=='spoon':ellipse((63,15,100,60),'#A5BDCD','#63798C');line([(71,52),(28,112)],'#93AFC1',9)
  elif name=='flute':line([(15,83),(117,38)],'#AD835B',12);[ellipse((x,76-(x-28)*.44,x+5,81-(x-28)*.44),'#4C493F') for x in [28,44,60,76,92]]
  elif name=='toothbrush':line([(24,109),(91,39)],'#79B8D2',9);rr((76,20,104,53),'#FCFAEF','#85B4C6');line([(81,25),(100,42)],'#ADCFE2',7)
  elif name=='bow':line([(18,112),(110,20)],'#9D784E',6);line([(23,107),(106,24)],'#F3E3CA',2)
  elif name=='whip':line([(23,108),(48,73)],'#A77B50',8);line([(48,73),(81,64),(110,39),(90,18)],'#7A5E48',3)
  else:line([(13,100),(36,88),(53,97),(75,74),(75,42),(103,25)],'#D88DB5',3)
 elif name in ['desk','board','notebook','laptop','screen','menu','files','fu']:
  if name=='desk':rr((5,39,123,61),'#BA916E','#82604D');rect((17,61,26,118),'#AB805F');rect((101,61,110,118),'#AB805F')
  elif name=='board':rect((12,15,115,116),'#D8B879','#886E4C');[line([(20+i*11,23),(20+i*11,107)],'#8E7953',1) for i in range(9)];[line([(20,23+i*10),(108,23+i*10)],'#8E7953',1) for i in range(9)];[ellipse((x-5,y-5,x+5,y+5),c) for x,y,c in [(53,53,'#3A3A46'),(64,63,'#FFF9EE'),(75,73,'#3A3A46')]]
  elif name in ['laptop','screen']:rr((16,15,111,84),'#68798C','#46526B');rect((23,23,104,76),'#C8E8E9');line([(34,39),(48,32),(57,43),(43,54),(67,58),(89,40)],'#5486A6',3);poly([(16,84),(4,109),(123,109),(111,84)],'#A1AFBD','#53677D');line([(25,96),(101,96)],'#718297',3)
  elif name=='notebook':rr((20,13,109,116),'#9FC9D6','#5B869D');rect((30,22,101,108),'#FFF9E9');[line([(39,36+i*13),(93,36+i*13)],'#ACBEC4',2) for i in range(5)];[ellipse((19,28+i*20,29,34+i*20),'#E8ECEF','#5B869D') for i in range(4)]
  elif name=='menu':rr((24,12,107,118),'#FFF4E3','#C3956D');text('菜单',65,32,19);[line([(38,53+i*17),(91,53+i*17)],'#B19381',3) for i in range(3)]
  elif name=='files':
   for i in range(3):rr((12+i*9,44-i*12,103+i*4,111-i*8),['#D39E75','#8EBABD','#F3D38A'][i],'#927A61');line([(33,58),(94,58)],'#FFF8E7',3)
  else:poly([(64,4),(122,64),(64,123),(5,64)],'#D95559','#AA393F');text('福',64,64,47,'#FFE2A1')
 elif name=='cube':poly([(20,37),(61,15),(108,38),(64,62)],'#F4CB6B','#595465');poly([(20,37),(64,62),(64,114),(20,88)],'#75BD9F','#595465');poly([(64,62),(108,38),(108,88),(64,114)],'#E88E83','#595465');line([(34,30),(78,55),(78,106)],'#595465',2);line([(47,23),(93,46),(93,97)],'#595465',2);line([(20,55),(64,80),(108,57)],'#595465',2);line([(20,72),(64,97),(108,74)],'#595465',2)
 elif name=='controller':rr((10,37,118,97),'#A2A5CE','#55587C');ellipse((20,54,50,83),'#7279A5');line([(35,58),(35,78)],'#F8F5F0',5);line([(25,68),(45,68)],'#F8F5F0',5);ellipse((85,50,99,64),'#E28C9E');ellipse((98,66,112,80),'#91D4BA')
 elif name=='fan':poly([(65,93),(7,53),(25,22),(60,9),(100,24),(122,58)],'#A5D8CD','#568C8D');[line([(65,93),(x,y)],'#D8B789',2) for x,y in [(7,53),(25,22),(60,9),(100,24),(122,58)]];line([(65,89),(64,120)],'#AE895D',7)
 elif name in ['car','rockinghorse','swing','top','shuttlecock','ball','block','violin','watergun']:
  if name=='car':rr((12,56,118,94),'#DF8D85','#8B5E66');poly([(34,56),(46,31),(85,31),(103,56)],'#A7D4DC','#8B5E66');ellipse((23,80,48,105),'#5C5C77');ellipse((84,80,109,105),'#5C5C77')
  elif name=='rockinghorse':line([(13,106),(34,117),(92,117),(115,103)],'#9C795A',8);poly([(28,85),(39,54),(84,54),(91,26),(108,34),(111,62),(91,74),(85,95)],'#D1AC79','#8F7357');line([(44,82),(38,110)],'#A78C60',8);line([(83,84),(89,110)],'#A78C60',8);ellipse((99,36,103,40),'#4B3E44')
  elif name=='swing':line([(12,6),(12,105),(115,105),(115,6)],'#B18D64',4);rr((8,94,120,110),'#DDB57C','#8F7453')
  elif name=='top':line([(64,16),(64,114)],'#977148',7);ellipse((24,36,104,67),'#F3B860','#896F72');poly([(24,54),(64,109),(104,54)],'#92BFD3','#896F72');line([(35,70),(93,70)],'#D7AECC',7)
  elif name=='shuttlecock':ellipse((42,91,88,115),'#C95A67','#8F4C5B');[poly([(60,94),(17+i*20,17),(39+i*16,15),(72,94)],c) for i,c in enumerate(['#B8D6DE','#EFBC9A','#A9CDB3','#DBA5C7'])]
  elif name=='ball':ellipse((16,16,112,112),'#F4BB78','#BC8061');poly([(65,17),(65,64),(21,85),(17,56),(33,27)],'#A8CBBE');poly([(65,64),(110,43),(110,84),(80,109)],'#D599C0');ellipse((52,53,75,76),'#FFF2C9')
  elif name=='block':rr((21,21,109,109),'#D3B0DE','#8D73A5');line([(21,41),(108,41)],'#B890C6',4);star(64,70,22,'#FFF2B6')
  elif name=='violin':ellipse((32,59,85,111),'#B77E4C','#704E43');ellipse((39,35,77,80),'#CD9656','#704E43');line([(59,46),(91,7)],'#8F6147',10);line([(48,93),(91,10)],'#F6DEB4',2);line([(47,70),(68,82)],'#684E43',3)
  elif name=='watergun':rr((20,46,114,77),'#81BBD2','#547E9D');rr((21,27,63,49),'#E9A97E','#B67C68');poly([(45,77),(39,113),(65,113),(76,77)],'#B4D5BC','#547E9D');rect((103,48,123,66),'#EFB38B')
 elif name in ['bird','cat','butterfly','bee','whale','lion','ghost']:
  if name=='cat':cat()
  elif name=='bird':ellipse((34,43,96,91),'#E9E7F5','#B2A4CC');poly([(60,61),(28,9),(17,25),(37,71)],'#EAEAF8','#B2A4CC');poly([(75,63),(113,12),(120,33),(93,77)],'#EAEAF8','#B2A4CC');poly([(94,53),(116,61),(96,68)],'#D8A565');ellipse((81,51,88,58),'#57526F')
  elif name=='butterfly':ellipse((5,15,62,80),'#DAACD8','#9C7BB6');ellipse((66,15,122,80),'#B1CEEB','#7B99BD');ellipse((19,66,60,113),'#E7BCD7','#9C7BB6');ellipse((68,66,110,113),'#BCDCCB','#7B99BD');line([(64,35),(64,101)],'#605375',7)
  elif name=='bee':ellipse((27,35,71,71),'#DEEAF6','#A7C4D6');ellipse((64,28,103,65),'#DEEAF6','#A7C4D6');ellipse((21,56,109,99),'#F0C25C','#8A7255');line([(48,60),(48,96)],'#645660',8);line([(73,60),(73,96)],'#645660',8);ellipse((91,66,97,73),'#524A57')
  elif name=='whale':ellipse((12,29,100,99),'#85ACDA','#5C7FAA');poly([(91,67),(121,33),(119,83),(97,93)],'#85ACDA','#5C7FAA');ellipse((26,65,80,96),'#C3DCEB');ellipse((30,49,37,56),'#3F5279');poly([(56,69),(78,66),(75,94)],'#6C95C5')
  elif name=='lion':rr((11,30,118,110),'#DF7660','#A85552');ellipse((20,7,53,43),'#EAB273','#A85552');ellipse((79,7,111,43),'#EAB273','#A85552');ellipse((24,34,58,72),'#FFF1D8','#AF5F58');ellipse((74,34,109,72),'#FFF1D8','#AF5F58');ellipse((39,45,48,60),'#53475C');ellipse((84,45,93,60),'#53475C');rr((33,78,97,101),'#FFF2D1','#AF5F58');line([(37,88),(92,88)],'#AF5F58',3)
  else:ellipse((22,12,107,103),'#E4EBF4','#A3AFD1');poly([(22,61),(22,115),(39,105),(53,117),(69,106),(86,119),(107,105),(107,61)],'#E4EBF4');ellipse((44,43,54,62),'#716B96');ellipse((76,43,86,62),'#716B96');ellipse((59,72,71,87),'#B7A5CF')
 elif name in ['flower','chrysanthemum','zhuyu','tree','leaves','snowman','pumpkin','moon','sky_lantern','riverlantern']:
  if name in ['flower','chrysanthemum','zhuyu']:
   line([(64,118),(64,40)],'#60936A',6);poly([(63,91),(28,74),(35,104),(63,108)],'#7DB67F');poly([(65,82),(99,66),(92,96),(65,100)],'#91BD85')
   if name=='zhuyu':
    for x,y in [(47,38),(62,27),(78,38),(59,48)]:ellipse((x-9,y-9,x+9,y+9),'#D96B70','#A04E59')
   else:flower(64,40,33,'#E5B65E' if name=='chrysanthemum' else '#DC9DBC')
  elif name=='tree':rect((55,100,74,126),'#967454');poly([(64,6),(20,53),(37,53),(8,89),(31,89),(12,112),(117,112),(97,90),(120,90),(92,53),(109,53)],'#7DAA8C','#527A6A');star(64,14,13,'#F7D27C');[ellipse((x-5,y-5,x+5,y+5),c) for x,y,c in [(40,64,'#E9A0A0'),(83,80,'#F7D27C'),(50,99,'#B0D4EA')]]
  elif name=='leaves':
   for x,y,a in [(30,27,0),(82,47,1),(46,89,2),(100,108,3)]:poly([(x,y-17),(x+15,y-3),(x+9,y+15),(x-6,y+10),(x-15,y-1)],['#CD9862','#D9B56C','#C88C72','#B5A473'][a])
  elif name=='snowman':ellipse((24,57,105,122),'#F6F6F1','#B2C4D1');ellipse((37,15,94,74),'#F6F6F1','#B2C4D1');poly([(68,42),(94,49),(68,54)],'#DA9E64');ellipse((49,34,55,40),'#5E6271');ellipse((75,34,81,40),'#5E6271');rect((34,64,97,75),'#D78F99');line([(38,87),(8,66)],'#977C67',4);line([(94,87),(120,64)],'#977C67',4)
  elif name=='pumpkin':ellipse((9,30,119,115),'#D99859','#A66A4E');ellipse((32,29,97,114),None,'#B97D50',3);rect((57,15,70,38),'#7B945C');poly([(28,60),(43,46),(52,67)],'#6E5357');poly([(77,65),(90,46),(103,60)],'#6E5357');poly([(28,82),(44,95),(57,85),(71,95),(84,84),(101,82),(86,105),(44,103)],'#6E5357')
  elif name=='moon':ellipse((15,11,116,113),'#F8E4A4','#D6C18D');ellipse((31,30,53,50),'#EFDA99');ellipse((73,72,101,101),'#EFDA99');ellipse((79,25,95,41),'#EFDA99')
  elif name=='sky_lantern':rr((21,12,108,92),'#E6A578','#A96F62');poly([(21,75),(108,75),(91,112),(38,112)],'#F4C295','#A96F62');line([(38,112),(91,112)],'#A96F62',4);ellipse((55,93,76,114),'#FFE3A1')
  else:ellipse((8,86,121,120),'#85B6C5');poly([(64,96),(14,76),(42,60),(29,37),(60,50),(64,22),(76,48),(103,38),(93,64),(115,77)],'#D5A0C4','#9B78A1');ellipse((54,58,76,88),'#FFE1A0')
 elif name in ['gift','redpacket','moneybag','emptybag','mirror','hat','cards','swatches','ornament']:
  if name=='gift':rr((14,41,116,114),'#B1C9D9','#6D91A8');rect((7,34,122,56),'#C3DBE7','#6D91A8');rect((58,35,74,114),'#E8A7B9');ellipse((28,11,66,37),None,'#D292A7',6);ellipse((67,11,103,37),None,'#D292A7',6)
  elif name=='redpacket':rr((28,11,103,119),'#D9646C','#A14E5A');poly([(29,31),(65,56),(102,31)],'#E18785');coin(65,73,18)
  elif name in ['moneybag','emptybag']:poly([(43,40),(33,13),(95,13),(84,40)],'#D8B077','#A58059');ellipse((18,35,113,121),'#E2C28D','#A58059');line([(36,39),(94,39)],'#AF755F',7);text('$' if name=='moneybag' else '空',65,82,35,'#9D784E')
  elif name=='mirror':ellipse((24,9,104,88),'#D6DFE8','#9C83A6',6);ellipse((34,19,94,78),'#BCDCE3');line([(42,57),(73,25)],'#F4F5EE',6);rr((56,84,73,123),'#BDA5C8','#9C83A6')
  elif name=='hat':ellipse((9,83,120,119),'#7B7196','#554A72');poly([(30,96),(22,18),(106,18),(99,96)],'#8D82A7','#554A72');rect((28,65,102,81),'#D8A7B6')
  elif name=='cards':
   for x,y in [(12,39),(39,17),(65,38)]:rr((x,y,x+45,y+68),'#FFF9EB','#B8A9C5');text('♥',x+22,y+31,28,'#CC7A96')
  elif name=='swatches':
   for i,c in enumerate(['#769CDF','#6F707C','#DEDCE0','#C79787','#8FB8CE','#AD9DD1','#6C86A7','#D59CB6']):rr((9+i*13,20+abs(i-4)*6,21+i*13,102),c,'#716D89')
  else:ellipse((28,25,100,111),'#D995A7','#A16B84');rect((51,12,78,30),'#D5BA79');star(65,67,19,'#FFE8B6')
 elif name in ['bubbles','foam','water','waves','cloud','dust','snow','drop','sweat','tear']:
  if name in ['bubbles','foam']: 
   for x,y,r in [(40,46,25),(81,32,20),(88,79,24),(38,93,15)]:ellipse((x-r,y-r,x+r,y+r),'#DBEFF2A0','#A6CCD7',2);ellipse((x-r*.5,y-r*.5,x-r*.1,y-r*.1),'#FFFFFFC0')
  elif name=='waves':
   for j in range(3):line([(5+i*5,33+j*28+math.sin(i*.7)*7) for i in range(24)],'#91BFCE',5)
  elif name=='cloud':ellipse((5,55,123,100),'#DAE9F1','#A5B9D2');ellipse((31,30,87,94),'#DAE9F1');ellipse((73,42,118,90),'#DAE9F1')
  elif name in ['drop','sweat','tear']:poly([(63,11),(31,63),(29,90),(48,112),(78,112),(102,90),(98,63)],'#A7CFDF','#729EB8');ellipse((39,72,54,88),'#E2F1F7')
  elif name=='water':line([(8+i*5,69+math.sin(i*.7)*12) for i in range(23)],'#80BAD0',8);[ellipse((x,y,x+8,y+10),'#ABD4E1') for x,y in [(20,29),(70,20),(100,86)]]
  elif name=='snow':
   for x,y in [(29,35),(86,30),(63,88)]:line([(x-16,y),(x+16,y)],'#CFDFED',3);line([(x,y-17),(x,y+17)],'#CFDFED',3);line([(x-12,y-12),(x+12,y+12)],'#CFDFED',3)
  else:[ellipse((x,y,x+25,y+20),'#DCCBB5B0') for x,y in [(12,73),(45,55),(79,64)]]
 elif name in ['heart','sparkle','notes','question','thought','chat','sleepy','surprise','anger','tickle','blush','impact','shards','confetti','fireworks','coin','stone']:
  if name=='heart':ellipse((17,19,67,69),'#E6A0B5');ellipse((62,19,112,69),'#E6A0B5');poly([(18,53),(111,53),(65,112)],'#E6A0B5')
  elif name=='sparkle':star(65,65,44,'#F4D786');star(20,21,12,'#F1B6C4');star(111,103,10,'#A5C9DF')
  elif name=='notes':line([(43,91),(43,27),(95,16),(95,79)],'#9481B5',6);ellipse((20,79,49,103),'#9481B5');ellipse((72,67,101,91),'#9481B5')
  elif name=='question':text('?',64,61,95,'#AA98CA')
  elif name in ['thought','chat']:rr((8,12,120,90),'#E7E3F1','#A49BC0');poly([(65,88),(87,114),(90,88)],'#E7E3F1','#A49BC0');[ellipse((x,42,x+12,54),'#ADA0C1') for x in [31,58,85]]
  elif name=='sleepy':text('Z',43,78,52,'#A7ADD1');text('z',91,33,28,'#BCC5DF')
  elif name=='surprise':text('!',64,64,95,'#E7BA74')
  elif name=='anger':line([(23,38),(50,47),(47,17)],'#D78C8C',8);line([(81,17),(78,45),(111,38)],'#D78C8C',8);line([(23,91),(50,82),(47,113)],'#D78C8C',8);line([(81,112),(78,82),(111,90)],'#D78C8C',8)
  elif name=='tickle':line([(17,87),(37,72),(26,48),(48,31)],'#DAB089',6);line([(69,93),(91,73),(81,51),(105,32)],'#DAB089',6)
  elif name=='blush':ellipse((10,42,55,83),'#E7A3B880');ellipse((73,42,118,83),'#E7A3B880')
  elif name=='impact':star(65,66,51,'#E9C382');star(65,66,31,'#FFF1C7')
  elif name=='shards':
   for p in [[(12,24),(48,32),(30,67)],[(69,16),(111,38),(77,52)],[(59,64),(105,71),(85,117)],[(17,84),(43,79),(28,113)]]:poly(p,'#CBB0DC','#9C83B6')
  elif name in ['confetti','fireworks']:
   for i in range(12):a=i*math.pi/6;x=64+math.cos(a)*45;y=64+math.sin(a)*45;line([(64+math.cos(a)*19,64+math.sin(a)*19),(x,y)],['#DCA8BD','#A5C5D3','#E9CD8D'][i%3],4);star(x,y,5,['#DCA8BD','#A5C5D3','#E9CD8D'][i%3])
  elif name=='coin':coin(64,64,45)
  else:ellipse((20,20,108,108),'#5F5B72','#3C3A4C');ellipse((37,34,63,48),'#9490A4')
 else:return None
 return im.resize((128,128),Image.Resampling.LANCZOS)

# Supplemental unique drawings (no label-only fallback).
_base_draw=draw
def draw(name):
 if name not in ['balloon','cloth','kite']:return _base_draw(name)
 im=Image.new('RGBA',(384,384));d=ImageDraw.Draw(im)
 if name=='kite':
  d.polygon([(195,9),(330,129),(192,267),(66,129)],fill='#B9CDE5',outline='#7E92BA',width=7);d.polygon([(195,9),(330,129),(195,129)],fill='#DEA6BC');d.polygon([(66,129),(192,267),(195,129)],fill='#EDCD95');d.line([(195,9),(192,267),(153,303),(210,336),(168,375)],fill='#9D8AAE',width=5)
 elif name=='balloon':
  d.ellipse((57,9,327,294),fill='#E7B0D5',outline='#B48CAA',width=6);d.ellipse((93,42,147,129),fill='#F8E9F3');d.polygon([(192,282),(172,312),(213,312)],fill='#B48CAA');d.line([(192,306),(184,330),(204,354),(192,381)],fill='#A3ACC5',width=5)
 else:
  d.polygon([(42,120),(141,42),(339,117),(267,321),(42,285)],fill='#AAD1CE',outline='#7BA6AB',width=6)
  d.line([(42,120),(189,174),(267,321)],fill='#CEE5DD',width=7)
 return im.resize((128,128),Image.Resampling.LANCZOS)

def main():
 clips=json.loads((DEST/'actions.json').read_text())['clips'];props=sorted({p for c in clips for p in c['props']});out=DEST/'props';out.mkdir(exist_ok=True)
 failed=[]
 for name in props:
  im=draw(name)
  if im is None:failed.append(name);continue
  im.save(out/(name+'.png'))
 assert not failed,failed
 # Each object is animated in one of these coordinate spaces, then gets action-specific choreography.
 near={'bow','pencil','toothbrush','fan','mirror','watergun','flute','needle','tanghulu','icecream','snack','redpacket','mooncake','zongzi','qingtuan','cake','niangao','ornament','zhuyu','spoon','chopsticks','cloth','whip','stone'}
 far={'pumpkin','rice','congee','tangyuan','noodles','lunch','dinner','crab','hotpot','notebook','cube','controller','violin','moneybag','emptybag','menu','toast','egg','dumpling','watermelon','candy','cards','fu','thread'}
 ground={'desk','board','car','rockinghorse','swing','snowman','tree','riverlantern','waves','top','laptop','screen','files','hat'}
 ambient={'sparkle','blush','anger','tickle','surprise','sleepy','notes','bubbles','foam','water','dust','cloud','whale','flower','chrysanthemum','balloon','kite','bird','cat','bee','butterfly','shards','impact','heart','leaves','moon','fireworks','snow','drop','coin','confetti','sky_lantern','ghost','question','thought','chat','sweat','tear','swatches','block','gift','lion','ball','shuttlecock','token'}
 assert set(props)==near|far|ground|ambient, set(props)^(near|far|ground|ambient)
 spec={}
 for name in props:
  anchor='near' if name in near else 'far' if name in far else 'ground' if name in ground else 'ambient'
  size=30 if anchor in ['near','far'] else 64
  if name in ['pencil','needle','spoon','chopsticks','toothbrush','flute','bow','whip','thread']:size=39
  if name in ['rice','congee','noodles','hotpot','lunch','dinner','tangyuan']:size=43
  if name in ['desk','laptop','screen','board','rockinghorse','swing','tree','snowman']:size=90
  spec[name]={'file':'props/'+name+'.png','anchor':anchor,'size':size}
 # Bow is a far-side instrument bow; intentionally distinct from near-held violin body.
 (DEST/'props.json').write_text(json.dumps({'version':1,'props':spec},ensure_ascii=False,separators=(',',':'))+'\n')
 sheet=Image.new('RGB',(9*150,math.ceil(len(props)/9)*162),'#F2F1F7');d=ImageDraw.Draw(sheet)
 for i,name in enumerate(props):
  im=Image.open(out/(name+'.png'));x=(i%9)*150+11;y=(i//9)*162;sheet.paste(im,(x,y),im);d.text((x+64,y+132),name,font=ImageFont.truetype(FONT,12),fill='#50475F',anchor='mt')
 target=ROOT/'build/live-actions-props-preview.jpg';target.parent.mkdir(exist_ok=True);sheet.save(target,quality=90)
 print('Wrote',len(props),'transparent prop images and placement metadata; preview',target)
if __name__=='__main__':main()
