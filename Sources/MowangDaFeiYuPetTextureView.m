#import "MowangDaFeiYuPetTextureView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface MWTexturePiece : NSObject
@property(nonatomic,copy) NSString *identifier, *parent;
@property(nonatomic,strong) UIImage *image;
@property(nonatomic) CGRect box;
@property(nonatomic) double z;
@property(nonatomic) BOOL multiply;
@end
@implementation MWTexturePiece
@end

@interface MowangDaFeiYuPetTextureView ()
@property(nonatomic,readwrite,copy) NSString *scheme, *failure;
@property(nonatomic,strong) NSDictionary *model;
@property(nonatomic,strong) NSArray<MWTexturePiece *> *pieces;
@property(nonatomic,strong) NSDictionary<NSString *, MWTexturePiece *> *features;
@property(nonatomic) CFTimeInterval time;
@property(nonatomic,copy) NSString *expression;
@property(nonatomic) BOOL dragging, flying, moving;
@property(nonatomic) double blink;
@end

@implementation MowangDaFeiYuPetTextureView
static BOOL MWNumbers(id a, NSUInteger n) {
    if(![a isKindOfClass:NSArray.class] || [a count]!=n) return NO;
    for(id v in a) if(![v isKindOfClass:NSNumber.class] || !isfinite([v doubleValue])) return NO;
    return YES;
}
static CGRect MWBox(NSArray *a) { return CGRectMake([a[0] doubleValue],[a[1] doubleValue],[a[2] doubleValue],[a[3] doubleValue]); }
- (UIImage *)texture:(NSString *)name root:(NSString *)root {
    // Only allowlisted scheme IDs and model-owned filenames; no preference path interpolation.
    NSString *path=[root stringByAppendingPathComponent:[NSString stringWithFormat:@"schemes/%@/%@.png",self.scheme,name]];
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) path=[root stringByAppendingPathComponent:[name stringByAppendingString:@".png"]];
    return [UIImage imageWithContentsOfFile:path];
}
- (MWTexturePiece *)feature:(NSString *)name rect:(NSArray *)rect root:(NSString *)root {
    if(!MWNumbers(rect,4)) return nil;
    NSDictionary *u=self.model[@"units"];
    double s=[u[@"S"] doubleValue], x0=[u[@"X0"] doubleValue], feet=[u[@"FEET"] doubleValue];
    // Facial rectangles are original-art x1,y1,x2,y2, NOT model x,y,width,height.
    CGRect r=CGRectMake(128+([rect[0] doubleValue]-x0)*s,256+([rect[1] doubleValue]-feet)*s,([rect[2] doubleValue]-[rect[0] doubleValue])*s,([rect[3] doubleValue]-[rect[1] doubleValue])*s);
    UIImage *image=[self texture:[@"feat/" stringByAppendingString:name] root:root];
    if(!image || r.size.width<=0 || r.size.height<=0) return nil;
    MWTexturePiece *p=[MWTexturePiece new]; p.identifier=name; p.parent=@"headFeat"; p.box=r; p.image=image; p.z=8.7; return p;
}
- (instancetype)initWithAssetRoot:(NSString *)root scheme:(NSString *)scheme {
    if(!(self=[super initWithFrame:CGRectZero])) return nil;
    self.userInteractionEnabled=NO; self.opaque=NO; self.backgroundColor=UIColor.clearColor;
    self.contentMode=UIViewContentModeRedraw;
    if(![@[@"deepseek",@"harness",@"chatgpt",@"claude",@"gemini",@"qwen",@"kimi",@"minimax"] containsObject:scheme]) { self.failure=@"Unknown texture scheme"; return self; }
    self.scheme=scheme;
    NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"model.json"]];
    id json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
    if(![json isKindOfClass:NSDictionary.class] || ![json[@"parts"] isKindOfClass:NSArray.class] || !MWNumbers(json[@"view"],4) || ![json[@"pivots"] isKindOfClass:NSDictionary.class]) { self.failure=@"Invalid original model"; return self; }
    self.model=json;
    for(NSString *key in @[@"S",@"X0",@"FEET"]) if(![json[@"units"][key] isKindOfClass:NSNumber.class]) { self.failure=@"Invalid coordinate units"; return self; }
    NSMutableArray *parts=[NSMutableArray new]; NSMutableDictionary *features=[NSMutableDictionary new];
    NSSet *parents=[NSSet setWithArray:@[@"body",@"hairSway",@"tailBend",@"armFar",@"legBack",@"skirt",@"legFront",@"skirtSit",@"armNear",@"finFar",@"bangsSway",@"headMid",@"headFeat",@"finNear",@"ahoge"]];
    for(NSDictionary *row in json[@"parts"]) {
        if(!MWNumbers(row[@"box"],4) || ![parents containsObject:row[@"parent"]]) { self.failure=@"Invalid part or unsupported parent"; return self; }
        MWTexturePiece *p=[MWTexturePiece new]; p.identifier=row[@"id"]; p.parent=row[@"parent"]; p.box=MWBox(row[@"box"]); p.z=[row[@"z"] doubleValue]; p.multiply=[row[@"blend"] isEqual:@"multiply"];
        p.image=[self texture:[@"tex/" stringByAppendingString:row[@"tex"]] root:root];
        if(!p.image) { self.failure=[@"Missing texture: " stringByAppendingString:p.identifier]; return self; }
        [parts addObject:p];
    }
    NSDictionary *feat=json[@"feat"];
    for(NSString *eye in @[@"eyeL",@"eyeR"]) for(NSString *kind in @[@"ball",@"iris",@"hl",@"lash"]) {
        NSString *key=[NSString stringWithFormat:@"%@_%@",eye,kind];
        MWTexturePiece *p=[self feature:key rect:feat[@"eyes"][eye][kind] root:root];
        if(!p) { self.failure=[@"Missing eye: " stringByAppendingString:key]; return self; } features[key]=p;
    }
    for(NSString *key in feat[@"sprites"]) {
        MWTexturePiece *p=[self feature:key rect:feat[@"sprites"][key] root:root];
        if(!p) { self.failure=[@"Missing expression: " stringByAppendingString:key]; return self; } features[key]=p;
    }
    self.pieces=[parts sortedArrayUsingComparator:^NSComparisonResult(MWTexturePiece *a,MWTexturePiece *b) { return a.z<b.z?NSOrderedAscending:(a.z>b.z?NSOrderedDescending:NSOrderedSame); }];
    self.features=features; self.expression=@"neutral"; return self;
}
// Apply hierarchy in original model coordinates. Flat z drawing is intentional:
// parenting geometry under one CALayer would wrongly pull all hair in front of face/arms.
- (CGPoint)pivot:(NSString *)name {
    NSArray *a=self.model[@"pivots"][name]; return MWNumbers(a,2)?CGPointMake([a[0] doubleValue],[a[1] doubleValue]):CGPointMake(128,256);
}
- (void)rotate:(CGContextRef)c pivot:(NSString *)name angle:(double)angle {
    CGPoint p=[self pivot:name]; CGContextTranslateCTM(c,p.x,p.y); CGContextRotateCTM(c,angle); CGContextTranslateCTM(c,-p.x,-p.y);
}
- (void)parent:(NSString *)parent context:(CGContextRef)c {
    double t=UIAccessibilityIsReduceMotionEnabled()?0:self.time;
    double breath=sin(t*2.1), walk=self.moving?sin(t*7):0;
    CGPoint body=[self pivot:@"body"];
    CGContextTranslateCTM(c,body.x,body.y);
    CGContextScaleCTM(c,1+.003*breath,1+.008*breath);
    CGContextRotateCTM(c,.009*sin(t*.85)+(self.dragging?.055*sin(t*3):0));
    CGContextTranslateCTM(c,-body.x,-body.y);
    BOOL head=[@[@"headMid",@"headFeat",@"hairSway",@"bangsSway",@"finNear",@"finFar",@"ahoge"] containsObject:parent];
    // model parents resolve as body → waist → neck → head{Back,Mid,Feat,Front}.
    // Arms inherit waist; tailBend inherits tail; leg/skirt roots inherit body.
    if(head || [parent isEqual:@"armNear"] || [parent isEqual:@"armFar"]) [self rotate:c pivot:@"waist" angle:.006*sin(t*1.1)];
    if(head) [self rotate:c pivot:@"neck" angle:.018*sin(t*1.2)];
    if([parent isEqual:@"hairSway"]) [self rotate:c pivot:@"head" angle:.022*sin(t*1.6-.4)];
    else if([parent isEqual:@"bangsSway"]) [self rotate:c pivot:@"head" angle:.009*sin(t*1.6-.2)];
    else if([parent isEqual:@"tailBend"]) [self rotate:c pivot:@"tail" angle:(self.dragging?.19:.075)*sin(t*2.6)];
    else if([parent isEqual:@"armNear"]) [self rotate:c pivot:parent angle:.025*sin(t*2)+.08*walk+(self.dragging?-.22:0)];
    else if([parent isEqual:@"armFar"]) [self rotate:c pivot:parent angle:-.02*sin(t*2)-.08*walk+(self.dragging?.18:0)];
    else if([parent isEqual:@"legBack"] || [parent isEqual:@"legFront"]) [self rotate:c pivot:parent angle:([parent isEqual:@"legBack"]?1:-1)*(.05*walk+(self.flying?.10:0))];
    else if([parent isEqual:@"skirt"] || [parent isEqual:@"skirtSit"]) [self rotate:c pivot:@"waist" angle:.012*sin(t*1.5)];
    else if([parent isEqual:@"finNear"] || [parent isEqual:@"finFar"]) [self rotate:c pivot:parent angle:.04*sin(t*2.2)];
    else if([parent isEqual:@"ahoge"]) [self rotate:c pivot:parent angle:.08*sin(t*2.8)];
}
- (void)drawPiece:(MWTexturePiece *)piece context:(CGContextRef)c openness:(double)openness {
    if(!piece) return;
    CGContextSaveGState(c); [self parent:piece.parent context:c];
    if(openness<1) { double y=CGRectGetMidY(piece.box); CGContextTranslateCTM(c,0,y); CGContextScaleCTM(c,1,fmax(.04,openness)); CGContextTranslateCTM(c,0,-y); }
    if(piece.multiply) CGContextSetBlendMode(c,kCGBlendModeMultiply);
    [piece.image drawInRect:piece.box]; CGContextRestoreGState(c);
}
- (void)drawFace:(CGContextRef)c {
    NSString *exp=self.expression;
    if(![exp isEqual:@"neutral"]) {
        for(NSString *part in @[@"eyeL",@"eyeR",@"mouth"]) [self drawPiece:self.features[[NSString stringWithFormat:@"%@_%@",exp,part]] context:c openness:1];
        return;
    }
    for(NSString *eye in @[@"eyeL",@"eyeR"]) {
        if(self.blink<.16) { [self drawPiece:self.features[[NSString stringWithFormat:@"sleep_%@",eye]] context:c openness:1]; continue; }
        // All eye components share ONE blink pivot; do not squash each around a different centre.
        MWTexturePiece *ball=self.features[[eye stringByAppendingString:@"_ball"]];
        CGContextSaveGState(c); [self parent:@"headFeat" context:c];
        double cy=CGRectGetMidY(ball.box);
        CGContextTranslateCTM(c,0,cy); CGContextScaleCTM(c,1,fmax(.04,self.blink)); CGContextTranslateCTM(c,0,-cy);
        CGContextSaveGState(c);
        NSDictionary *eyeModel=self.model[@"feat"][@"eyes"][eye];
        NSArray *lid=eyeModel[@"lidFit"], *rim=eyeModel[@"rimFit"], *bounds=eyeModel[@"ball"];
        double s=[self.model[@"units"][@"S"] doubleValue], x0=[self.model[@"units"][@"X0"] doubleValue], feet=[self.model[@"units"][@"FEET"] doubleValue];
        // Actual quadratic lid/rim fits mask iris/highlights to the eye opening.
        CGMutablePathRef opening=CGPathCreateMutable();
        for(int edge=0;edge<2;edge++) for(int i=0;i<=24;i++) {
            double fraction=edge?1-i/24.0:i/24.0;
            double x=[bounds[0] doubleValue]+([bounds[2] doubleValue]-[bounds[0] doubleValue])*fraction;
            NSArray *fit=edge?rim:lid;
            double y=[fit[0] doubleValue]*x*x+[fit[1] doubleValue]*x+[fit[2] doubleValue];
            CGPoint q=CGPointMake(128+(x-x0)*s,256+(y-feet)*s);
            if(edge==0 && i==0) CGPathMoveToPoint(opening,NULL,q.x,q.y); else CGPathAddLineToPoint(opening,NULL,q.x,q.y);
        }
        CGPathCloseSubpath(opening); CGContextAddPath(c,opening); CGContextClip(c); CGPathRelease(opening);
        BOOL highlights=NO; for(NSDictionary *scheme in self.model[@"schemes"]) if([scheme[@"id"] isEqual:self.scheme]) highlights=[scheme[@"eyeHighlights"] boolValue];
        for(NSString *kind in @[@"ball",@"iris",@"hl"]) {
            if([kind isEqual:@"hl"] && !highlights) continue;
            MWTexturePiece *p=self.features[[NSString stringWithFormat:@"%@_%@",eye,kind]]; [p.image drawInRect:p.box];
        }
        CGContextRestoreGState(c);
        MWTexturePiece *lash=self.features[[eye stringByAppendingString:@"_lash"]]; [lash.image drawInRect:lash.box];
        CGContextRestoreGState(c);
    }
    [self drawPiece:self.features[@"neutral_mouth"] context:c openness:1];
}
- (void)drawRect:(CGRect)rect {
    if(self.failure || !self.model) return;
    CGContextRef c=UIGraphicsGetCurrentContext(); if(!c) return;
    // view is xMin,yMin,xMax,yMax; part.box is x,y,width,height.
    NSArray *view=self.model[@"view"];
    CGRect v=CGRectMake([view[0] doubleValue],[view[1] doubleValue],[view[2] doubleValue]-[view[0] doubleValue],[view[3] doubleValue]-[view[1] doubleValue]);
    double scale=fmin(self.bounds.size.width/v.size.width,self.bounds.size.height/v.size.height);
    CGContextSaveGState(c);
    CGContextTranslateCTM(c,(self.bounds.size.width-v.size.width*scale)*.5,(self.bounds.size.height-v.size.height*scale)*.5);
    CGContextScaleCTM(c,scale,scale); CGContextTranslateCTM(c,-v.origin.x,-v.origin.y);
    BOOL faceDrawn=NO;
    for(MWTexturePiece *piece in self.pieces) {
        if(!faceDrawn && piece.z>8.7) { [self drawFace:c]; faceDrawn=YES; }
        // Maid standing pose: sit assets are alternate geometry, never simultaneous duplicates.
        if([piece.parent isEqual:@"skirtSit"]) continue;
        [self drawPiece:piece context:c openness:1];
    }
    if(!faceDrawn) [self drawFace:c];
    CGContextRestoreGState(c);
}
- (void)advanceToTime:(CFTimeInterval)time action:(NSString *)action dragging:(BOOL)dragging flying:(BOOL)flying {
    if(!isfinite(time) || self.failure) return;
    self.time=time; self.dragging=dragging; self.flying=flying;
    self.moving=[action containsString:@"zoulu"] || [action containsString:@"benpao"] || [action containsString:@"tabu"];
    NSString *exp=@"neutral";
    if(dragging) exp=@"drag";
    else if(flying) exp=@"surprised";
    else if([action containsString:@"shuijiao"] || [action containsString:@"sleep"] || [action containsString:@"chenmian"] || [action containsString:@"haqian"]) exp=@"sleep";
    else if([action containsString:@"jingya"] || [action containsString:@"beixiayitiao"] || [action containsString:@"jingxing"]) exp=@"surprised";
    else if([action containsString:@"kaixin"] || [action containsString:@"happy"] || [action containsString:@"tap"] || [action containsString:@"gege"] || [action containsString:@"queyue"]) exp=@"happy";
    else if([action containsString:@"love"]) exp=@"love";
    else if([action containsString:@"dizzy"]) exp=@"dizzy";
    self.expression=exp;
    double phase=fmod(time,4.3); self.blink=phase<.18?fabs(phase-.09)/.09:1;
    [self setNeedsDisplay];
}
@end
