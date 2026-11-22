#import "MowangDaFeiYuPetPomodoroController.h"
#import "MowangDaFeiYuPetPreferences.h"
#import "MowangDaFeiYuPetPomodoro.h"

/* pomoConfig = {task, workMin, restMin}; pomoState adds startedAt (Unix seconds).
 * Stop removes only pomoState. Save never mutates an active session.
 */
@interface MowangDaFeiYuPetPomodoroController ()
@property(nonatomic,strong) UITextField *taskField, *workField, *restField;
@property(nonatomic,strong) UILabel *countdown, *message;
@property(nonatomic,strong) NSTimer *timer;
@end

@implementation MowangDaFeiYuPetPomodoroController
- (UITextField *)field:(NSString *)placeholder keyboard:(UIKeyboardType)keyboard stack:(UIStackView *)stack {
    UILabel *label=[UILabel new]; label.text=placeholder; [stack addArrangedSubview:label];
    UITextField *field=[UITextField new]; field.placeholder=placeholder; field.borderStyle=UITextBorderStyleRoundedRect;
    field.keyboardType=keyboard; field.autocorrectionType=UITextAutocorrectionTypeNo;
    field.autocapitalizationType=UITextAutocapitalizationTypeNone; field.delegate=self;
    field.accessibilityLabel=placeholder; [stack addArrangedSubview:field]; return field;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"大肥鱼 · 番茄钟"; self.view.backgroundColor=UIColor.systemBackgroundColor;
    UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO;
    scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive; [self.view addSubview:scroll];
    UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=12;
    stack.translatesAutoresizingMaskIntoConstraints=NO; [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
    self.countdown=[UILabel new]; self.countdown.numberOfLines=0;
    self.countdown.font=[UIFont monospacedDigitSystemFontOfSize:24 weight:UIFontWeightSemibold];
    [stack addArrangedSubview:self.countdown];
    UILabel *note=[UILabel new]; note.numberOfLines=0; note.font=[UIFont systemFontOfSize:13];
    note.text=@"专注与休息自动循环，锁屏后按实际时间恢复。提醒仅在本机显示，不自动请求 AI。保存设置下次开始生效；开始会重新计时。";
    [stack addArrangedSubview:note];
    self.taskField=[self field:@"任务（最多80字符）" keyboard:UIKeyboardTypeDefault stack:stack];
    self.workField=[self field:@"专注分钟（1–600）" keyboard:UIKeyboardTypeNumberPad stack:stack];
    self.restField=[self field:@"休息分钟（1–600）" keyboard:UIKeyboardTypeNumberPad stack:stack];
    NSArray *titles=@[@"开始 / 重新开始",@"停止",@"保存设置"];
    SEL actions[]={@selector(start),@selector(stop),@selector(save)};
    for (NSUInteger i=0;i<titles.count;i++) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:titles[i] forState:UIControlStateNormal];
        [button addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside]; [stack addArrangedSubview:button];
    }
    self.message=[UILabel new]; self.message.numberOfLines=0; self.message.font=[UIFont systemFontOfSize:13];
    [stack addArrangedSubview:self.message];
    [self loadConfiguration]; [self tick];
}
- (void)loadConfiguration {
    NSDictionary *prefs=mowang_dafeiyupet_readPreferences();
    id config=prefs[@"pomoConfig"] ?: prefs[@"pomoState"];
    NSDictionary *c=[config isKindOfClass:NSDictionary.class]?config:@{};
    self.taskField.text=[c[@"task"] isKindOfClass:NSString.class]?c[@"task"]:@"背单词";
    self.workField.text=[c[@"workMin"] isKindOfClass:NSNumber.class]?[c[@"workMin"] stringValue]:@"25";
    self.restField.text=[c[@"restMin"] isKindOfClass:NSNumber.class]?[c[@"restMin"] stringValue]:@"5";
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; [self tick];
    [self.timer invalidate];
    __weak typeof(self) weakSelf=self;
    self.timer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *t){ [weakSelf tick]; }];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tick) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated]; [self.timer invalidate]; self.timer=nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)dealloc { [_timer invalidate]; [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (NSDictionary *)validatedConfiguration {
    NSString *task=[self.taskField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!task.length) task=@"专注";
    __block NSUInteger count=0;
    [task enumerateSubstringsInRange:NSMakeRange(0,task.length) options:NSStringEnumerationByComposedCharacterSequences
        usingBlock:^(NSString *s,NSRange r,NSRange e,BOOL *stop){count++;}];
    if(count>80) {self.message.text=@"任务名最多80个字符，请缩短后重试。";return nil;}
    NSMutableArray *minutes=[NSMutableArray new];
    for(UITextField *field in @[self.workField,self.restField]) {
        NSString *text=[field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!text.length || text.length>3 || [text rangeOfCharacterFromSet:
              [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location!=NSNotFound ||
              !mowang_dafeiyupet_pomo_validMinutes(text.intValue)) {
            self.message.text=@"专注和休息分钟必须是1–600之间的整数。";return nil;
        }
        [minutes addObject:@(text.intValue)];
    }
    return @{@"task":task,@"workMin":minutes[0],@"restMin":minutes[1]};
}
- (BOOL)write:(NSString *)key value:(id)value {
    NSError *error=nil;
    if(!mowang_dafeiyupet_writePreference(key,value,&error)) {
        self.message.text=[@"保存失败：" stringByAppendingString:error.localizedDescription ?: @"未知错误"]; return NO;
    }
    [self.view endEditing:YES]; return YES;
}
- (void)start {
    NSDictionary *config=[self validatedConfiguration]; if(!config)return;
    NSMutableDictionary *state=[config mutableCopy]; state[@"startedAt"]=@([NSDate date].timeIntervalSince1970);
    if([self write:@"pomoState" value:state]) {self.message.text=@"已开始专注，专注与休息将自动循环。";[self tick];}
}
- (void)stop {
    if([self write:@"pomoState" value:nil]) {self.message.text=@"番茄钟已停止。";[self tick];}
}
- (void)save {
    NSDictionary *config=[self validatedConfiguration]; if(!config)return;
    if([self write:@"pomoConfig" value:config]) self.message.text=@"设置已保存，下次开始生效；当前计时不变。";
}
- (void)tick {
    id raw=mowang_dafeiyupet_readPreferences()[@"pomoState"];
    if(![raw isKindOfClass:NSDictionary.class]) {self.countdown.text=@"番茄钟 · 未开始";return;}
    NSDictionary *state=raw;
    for(NSString *key in @[@"startedAt",@"workMin",@"restMin"]) {
        if(![state[key] isKindOfClass:NSNumber.class]) {self.countdown.text=@"计时数据无效，请重新开始";return;}
    }
    double w=[state[@"workMin"] doubleValue],r=[state[@"restMin"] doubleValue];
    if(!isfinite(w)||!isfinite(r)||w<1||w>600||r<1||r>600||floor(w)!=w||floor(r)!=r) {
        self.countdown.text=@"计时数据无效，请重新开始";return;
    }
    MowangDaFeiYuPetPomoSnapshot s=mowang_dafeiyupet_pomo_snapshot([state[@"startedAt"] doubleValue],(int)w,(int)r,[NSDate date].timeIntervalSince1970);
    if(s.phase==MowangDaFeiYuPetPomoIdle) {self.countdown.text=@"计时数据无效，请重新开始";return;}
    NSString *task=[state[@"task"] isKindOfClass:NSString.class]?state[@"task"]:@"专注";
    self.countdown.text=[NSString stringWithFormat:@"%@ · %u:%02u\n%@",s.phase==MowangDaFeiYuPetPomoWork?@"专注中":@"休息中",s.remainingSeconds/60,s.remainingSeconds%60,task];
}
@end
