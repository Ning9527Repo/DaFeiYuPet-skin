#import "MWPetActionProps.h"
@interface MWPetActionProps ()
@property(nonatomic,readwrite,copy) NSString *failure;
@property(nonatomic,strong) NSDictionary *spec;
@property(nonatomic,strong) NSDictionary<NSString *,UIImage *> *images;
@end
@implementation MWPetActionProps
- (instancetype)initWithRoot:(NSString *)root required:(NSSet<NSString *> *)required {
 if(!(self=[super init]))return nil;
 NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"props.json"]];
 NSDictionary *json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
 if(![json isKindOfClass:NSDictionary.class]||![json[@"props"] isKindOfClass:NSDictionary.class]){self.failure=@"Invalid prop manifest";return self;}
 self.spec=json[@"props"];NSMutableDictionary *images=[NSMutableDictionary new];
 for(NSString *name in required){
  NSDictionary *s=self.spec[name];NSString *file=s[@"file"];double size=[s[@"size"] doubleValue];
  if(![s isKindOfClass:NSDictionary.class]||![file isKindOfClass:NSString.class]||![file isEqual:[NSString stringWithFormat:@"props/%@.png",name]]||![ @[@"near",@"far",@"ground",@"ambient"] containsObject:s[@"anchor"]]||!isfinite(size)||size<=0||size>128){self.failure=@"Invalid prop placement";return self;}
  UIImage *image=[UIImage imageWithContentsOfFile:[root stringByAppendingPathComponent:file]];
  if(!image){self.failure=[@"Missing action prop: " stringByAppendingString:name];return self;}images[name]=image;
 }
 self.images=images;return self;
}
- (void)drawProps:(NSArray<NSString *> *)names kind:(NSString *)kind variant:(NSInteger)variant phase:(double)phase elapsed:(double)t space:(NSString *)space {
 double fade=MWCurve(phase/.08)*(1-MWCurve((phase-.91)/.09));if(fade<=0)return;
 NSUInteger index=0;
 for(NSString *name in names){
  NSDictionary *s=self.spec[name];if(![s[@"anchor"] isEqual:space]){index++;continue;}
  double size=[s[@"size"] doubleValue],x=105,y=203,angle=0,alpha=fade;
  unsigned count=1;
  if([space isEqual:@"near"]){x=104;y=207;size*=.8;}
  else if([space isEqual:@"far"]){x=160;y=201;size*=.9;}
  else if([space isEqual:@"ground"]){x=133;y=237;}
  else{x=67+index*38;y=52;size=42;}
  if([space isEqual:@"near"]&&[name isEqual:@"bow"]){x=103;y=215;angle=.5*sin(t*5);}
  if([kind isEqual:@"brush"]&&[name isEqual:@"foam"]){x=151;y=146;size=26;alpha*=.65;}
  if([name isEqual:@"cloth"]){x=102;y=207;angle=.2*sin(t*5);}
  if([name isEqual:@"stone"]){size=8;x=105;y=208;}
  if([name isEqual:@"fan"]){angle=.3*sin(t*8);size=43;}
  if([name isEqual:@"thread"]){size=38;angle=.2*sin(t*4);}
  if([kind isEqual:@"cube"]){angle=.25*sin(t*3.8);}
  if([kind isEqual:@"ride"]&&[name isEqual:@"rockinghorse"]){x=128;y=222;angle=.1*sin(t*4);}
  if([kind isEqual:@"swing"]&&[name isEqual:@"swing"]){x=128;y=212;angle=.13*sin(t*3);}
  if([name isEqual:@"block"]){x=148;y=22;alpha*=1-MWCurve((phase-.35)/.08);}
  if([name isEqual:@"shards"]){x=148;y=36+phase*40;alpha*=MWCurve((phase-.35)/.08);size=70;}
  if([name isEqual:@"impact"]){x=51;y=251;size=38;alpha*=pow(fmax(0,sin(t*4)),5);}
  if([name isEqual:@"ball"]&&[kind isEqual:@"juggle"]){count=3;size=17;}
  if([name isEqual:@"shuttlecock"]){x=163;y=214-fabs(sin(t*3))*66;size=23;angle=t*2;}
  if([name isEqual:@"coin"]){count=[kind isEqual:@"money"]&&variant==0?7:3;size=17;}
  if([name isEqual:@"bubbles"]){count=4;size=26;}
  if([name isEqual:@"leaves"]){count=7;size=37;}
  if([name isEqual:@"snow"]){count=8;size=13;}
  if([name isEqual:@"confetti"]){count=3;size=65;}
  if([name isEqual:@"whale"]){x=67+sin(t)*12;y=57;size=114;}
  if([name isEqual:@"waves"]){x=133;y=250;size=120;}
  if([name isEqual:@"cat"]){size=[kind isEqual:@"petcat"]?52:32;x=91;y=[kind isEqual:@"petcat"]?233:223;}
  if([name isEqual:@"bird"]){x=154+sin(t*3)*47;y=66-cos(t*3)*20;size=35;}
  if([name isEqual:@"butterfly"]||[name isEqual:@"bee"]){x=132+cos(t*2+index)*88;y=70+sin(t*3+index)*18;size=25;}
  if([name isEqual:@"flower"]||[name isEqual:@"chrysanthemum"]){x=185;y=230;size=57*MWCurve(phase/.25);}
  if([name isEqual:@"moon"]){x=219;y=30;size=53;}
  if([name isEqual:@"sky_lantern"]){x=187;y=183-phase*155;size=64*(1-.5*phase);}
  if([name isEqual:@"riverlantern"]){x=185+sin(t)*15;y=250;size=52;}
  if([name isEqual:@"kite"]){x=210+sin(t*2)*12;y=29+sin(t)*9;size=56;}
  if([name isEqual:@"balloon"]){x=187;y=115-phase*70;size=20+phase*50;}
  if([name isEqual:@"fireworks"]){count=3;size=58;}
  if([name isEqual:@"water"]){x=210;y=165;size=65;alpha*=fmax(0,sin(t*6));}
  if([name isEqual:@"ghost"]){x=70;y=92+sin(t*3)*15;size=82;alpha*=.8;}
  if([name isEqual:@"lion"]){x=139;y=76;size=114;}
  if([name isEqual:@"swatches"]){x=195;y=153;size=55;angle=.1*sin(t*2);}
  if([name isEqual:@"gift"]){x=154;y=220;size=57;}
  if([name isEqual:@"thought"]||[name isEqual:@"chat"]){x=196;y=60;size=52;}
  if([name isEqual:@"sleepy"]){x=195;y=49;size=35;}
  if([name isEqual:@"surprise"]||[name isEqual:@"question"]||[name isEqual:@"anger"]){x=197;y=55;size=34;}
  if([name isEqual:@"blush"]){x=143;y=129;size=38;}
  if([name isEqual:@"drop"]){x=173;y=187+fmod(t,1)*40;size=15;}
  if([name isEqual:@"sweat"]||[name isEqual:@"tear"]){x=173;y=101+fmod(t,1)*34;size=14;}
  if([name isEqual:@"dust"]){x=111;y=251;size=56;}
  if([name isEqual:@"cloud"]){x=128;y=257;size=78;}
  for(unsigned i=0;i<count;i++){
   double px=x,py=y,a=angle,sc=1;
   if([name isEqual:@"ball"]){double q=fmod(t*.7+i/3.0,1);px=90+80*q;py=197-90*sin(M_PI*q);a=t*2+i;}
   if([name isEqual:@"coin"]){double q=fmod(t*.6+i*.19,1);px=147+sin(i*2.3)*34;py=145+100*q;sc=.6+.4*fabs(sin(t*4+i));}
   if([name isEqual:@"leaves"]||[name isEqual:@"snow"]){double q=fmod(t*.18+i*.137,1);px=35+i*29+sin(t+i)*8;py=5+245*q;a=t+i;}
   if([name isEqual:@"bubbles"]){double q=fmod(t*.2+i*.24,1);px=156+q*60+sin(t+i)*8;py=139-q*95;sc=.5+.6*q;}
   if([name isEqual:@"fireworks"]){px=45+i*87;py=30+(i%2)*25;sc=.3+.7*fabs(sin(t*2-i));}
   if([name isEqual:@"confetti"]){px=50+i*80;py=20+fmod(t*.25+i*.3,1)*130;a=t;}
   CGContextRef c=UIGraphicsGetCurrentContext();CGContextSaveGState(c);CGContextTranslateCTM(c,px,py);CGContextRotateCTM(c,a);CGContextScaleCTM(c,sc,sc);CGContextSetAlpha(c,alpha);
   [self.images[name] drawInRect:CGRectMake(-size*.5,-size*.5,size,size)];CGContextRestoreGState(c);
  }
  index++;
 }
}
@end
