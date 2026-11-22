#import "MowangDaFeiYuPetChatController.h"
#import "MowangDaFeiYuPetPreferences.h"
#import <Security/Security.h>
#import <AVFoundation/AVFoundation.h>
#import <os/log.h>
#import "MowangDaFeiYuPetAIProtocol.h"
#import "MowangDaFeiYuPetState.h"

static NSDictionary *mowang_dafeiyupet_keyQuery(void) {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:@"com.mowang.dafeiyupet.ai",(__bridge id)kSecAttrAccount:@"provider"};
}
@interface MowangDaFeiYuPetChatController () <AVSpeechSynthesizerDelegate>
@property(nonatomic,strong) UITextView *mowang_dafeiyupet_input,*mowang_dafeiyupet_reply;
@property(nonatomic,strong) UIView *mowang_dafeiyupet_morePanel;
@property(nonatomic,strong) NSLayoutConstraint *mowang_dafeiyupet_compactReplyHeight;
@property(nonatomic,strong) UILabel *mowang_dafeiyupet_status;
@property(nonatomic,strong) NSURLSession *mowang_dafeiyupet_session;
@property(nonatomic,strong) NSURLSessionDataTask *mowang_dafeiyupet_task;
@property(nonatomic,strong) NSMutableData *mowang_dafeiyupet_data;
@property(nonatomic) BOOL mowang_dafeiyupet_httpOK;
@property(nonatomic,copy) NSString *mowang_dafeiyupet_failure, *mowang_dafeiyupet_pending, *mowang_dafeiyupet_identity;
@property(nonatomic,strong) NSMutableArray *mowang_dafeiyupet_history;
@property(nonatomic) BOOL mowang_dafeiyupet_ollama;
@property(nonatomic,strong) AVSpeechSynthesizer *mowang_dafeiyupet_speech;
@property(nonatomic,strong) UISwitch *mowang_dafeiyupet_voiceEnabled;
@property(nonatomic,strong) UISlider *mowang_dafeiyupet_voiceVolume;
@property(nonatomic,strong) UILabel *mowang_dafeiyupet_voiceStatus;
@property(nonatomic,strong) UISwitch *mowang_dafeiyupet_memoryEnabled;
@property(nonatomic,copy) NSString *mowang_dafeiyupet_petID;
@property(nonatomic,strong) AVSpeechUtterance *mowang_dafeiyupet_utterance;
@property(nonatomic,copy) NSString *mowang_dafeiyupet_voiceIdentifier;
@end
@implementation MowangDaFeiYuPetChatController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"和大肥鱼聊天"; self.view.backgroundColor=UIColor.systemBackgroundColor;
    if(self.mowang_dafeiyupet_closeHandler) self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(mowang_dafeiyupet_close)];
    UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO;
    scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive; [self.view addSubview:scroll];
    UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=12;
    stack.translatesAutoresizingMaskIntoConstraints=NO; [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-8],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]]];
    UILabel *note=[UILabel new]; note.numberOfLines=0; note.font=[UIFont systemFontOfSize:13];
    note.text=@"主动发送文字到所选 AI 服务。Key 仅存本机 Keychain。默认离页清除；开启本机记忆后，最近6轮会以明文保存在插件偏好中，并在后续请求中发给同一服务与模型。关闭会删除保存记录。HTTP 需明确开启且不发送密钥。"; [stack addArrangedSubview:note];
    self.mowang_dafeiyupet_history=[NSMutableArray new];
    NSDictionary *state=mowang_dafeiyupet_petState(mowang_dafeiyupet_readPreferences());
    self.mowang_dafeiyupet_petID=state[@"activeID"];
    NSDictionary *pet=mowang_dafeiyupet_activePet(state);
    UILabel *petLabel=[UILabel new]; petLabel.text=[@"宠物实例：" stringByAppendingString:self.mowang_dafeiyupet_petID ?: @"未知版本（只读）"]; petLabel.font=[UIFont systemFontOfSize:13]; [stack addArrangedSubview:petLabel];
    UIStackView *memoryRow=[UIStackView new]; memoryRow.spacing=12;
    UILabel *memoryLabel=[UILabel new]; memoryLabel.text=@"保存本机聊天记忆（最近6轮）"; memoryLabel.numberOfLines=0; [memoryRow addArrangedSubview:memoryLabel];
    self.mowang_dafeiyupet_memoryEnabled=[UISwitch new]; self.mowang_dafeiyupet_memoryEnabled.accessibilityLabel=@"保存本机聊天记忆";
    self.mowang_dafeiyupet_memoryEnabled.on=[pet[@"memoryEnabled"] isKindOfClass:NSNumber.class] && [pet[@"memoryEnabled"] boolValue];
    self.mowang_dafeiyupet_memoryEnabled.enabled=self.mowang_dafeiyupet_petID.length>0;
    [self.mowang_dafeiyupet_memoryEnabled addTarget:self action:@selector(mowang_dafeiyupet_memoryChanged) forControlEvents:UIControlEventValueChanged];
    [memoryRow addArrangedSubview:self.mowang_dafeiyupet_memoryEnabled]; [stack addArrangedSubview:memoryRow];
    if(self.mowang_dafeiyupet_memoryEnabled.on) {
        [self.mowang_dafeiyupet_history addObjectsFromArray:mowang_dafeiyupet_boundedHistory(pet[@"history"])];
        self.mowang_dafeiyupet_identity=[pet[@"providerIdentity"] isKindOfClass:NSString.class]?pet[@"providerIdentity"]:nil;
    }
    self.mowang_dafeiyupet_speech=[AVSpeechSynthesizer new]; self.mowang_dafeiyupet_speech.delegate=self;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(mowang_dafeiyupet_stopVoice) name:UIApplicationWillResignActiveNotification object:nil];
    UILabel *voiceNote=[UILabel new]; voiceNote.numberOfLines=0;
    voiceNote.font=[UIFont systemFontOfSize:13];
    voiceNote.text=@"回复语音（本次聊天生效）：可从设备已有中文声线中选择，不是视频原声。默认关闭；系统媒体音量也会影响播放。";
    [stack addArrangedSubview:voiceNote];
    UIStackView *voiceRow=[UIStackView new]; voiceRow.spacing=12;
    UILabel *voiceLabel=[UILabel new]; voiceLabel.text=@"朗读回复";
    [voiceRow addArrangedSubview:voiceLabel];
    self.mowang_dafeiyupet_voiceEnabled=[UISwitch new];
    self.mowang_dafeiyupet_voiceEnabled.accessibilityLabel=@"朗读回复";
    [self.mowang_dafeiyupet_voiceEnabled addTarget:self action:@selector(mowang_dafeiyupet_voiceChanged) forControlEvents:UIControlEventValueChanged];
    [voiceRow addArrangedSubview:self.mowang_dafeiyupet_voiceEnabled]; [stack addArrangedSubview:voiceRow];
    self.mowang_dafeiyupet_voiceVolume=[UISlider new];
    self.mowang_dafeiyupet_voiceVolume.minimumValue=0; self.mowang_dafeiyupet_voiceVolume.maximumValue=1; self.mowang_dafeiyupet_voiceVolume.value=.7;
    self.mowang_dafeiyupet_voiceVolume.accessibilityLabel=@"回复语音音量（下一次播放生效）";
    [stack addArrangedSubview:self.mowang_dafeiyupet_voiceVolume];
    UIStackView *voiceButtons=[UIStackView new]; voiceButtons.distribution=UIStackViewDistributionFillEqually;
    UIButton *preview=[UIButton buttonWithType:UIButtonTypeSystem]; [preview setTitle:@"试听中文语音" forState:UIControlStateNormal];
    [preview addTarget:self action:@selector(mowang_dafeiyupet_previewVoice) forControlEvents:UIControlEventTouchUpInside]; [voiceButtons addArrangedSubview:preview];
    UIButton *stop=[UIButton buttonWithType:UIButtonTypeSystem]; [stop setTitle:@"停止播放" forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(mowang_dafeiyupet_stopVoice) forControlEvents:UIControlEventTouchUpInside]; [voiceButtons addArrangedSubview:stop];
    [stack addArrangedSubview:voiceButtons];
    UIButton *chooseVoice=[UIButton buttonWithType:UIButtonTypeSystem];
    [chooseVoice setTitle:@"选择中文声线（本次聊天）" forState:UIControlStateNormal];
    [chooseVoice addTarget:self action:@selector(mowang_dafeiyupet_chooseVoice:) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:chooseVoice];
    self.mowang_dafeiyupet_voiceStatus=[UILabel new]; self.mowang_dafeiyupet_voiceStatus.numberOfLines=0;
    self.mowang_dafeiyupet_voiceStatus.font=[UIFont systemFontOfSize:13]; self.mowang_dafeiyupet_voiceStatus.text=@"语音就绪 · 每次最多朗读600字符";
    [stack addArrangedSubview:self.mowang_dafeiyupet_voiceStatus];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"新对话" style:UIBarButtonItemStylePlain target:self action:@selector(mowang_dafeiyupet_clear)];
    self.mowang_dafeiyupet_input=[UITextView new]; self.mowang_dafeiyupet_input.delegate=self;
    self.mowang_dafeiyupet_input.accessibilityLabel=@"对大肥鱼说点什么";
    self.mowang_dafeiyupet_input.font=[UIFont systemFontOfSize:17]; self.mowang_dafeiyupet_input.backgroundColor=UIColor.secondarySystemBackgroundColor;
    [self.mowang_dafeiyupet_input.heightAnchor constraintEqualToConstant:100].active=YES; [stack addArrangedSubview:self.mowang_dafeiyupet_input];
    UIStackView *buttons=[UIStackView new]; buttons.distribution=UIStackViewDistributionFillEqually;
    UIButton *paste=[UIButton buttonWithType:UIButtonTypeSystem]; [paste setTitle:@"粘贴" forState:UIControlStateNormal];
    [paste addTarget:self action:@selector(mowang_dafeiyupet_paste) forControlEvents:UIControlEventTouchUpInside]; [buttons addArrangedSubview:paste];
    UIButton *send=[UIButton buttonWithType:UIButtonTypeSystem]; [send setTitle:@"发送（≤2048字符）" forState:UIControlStateNormal];
    [send addTarget:self action:@selector(mowang_dafeiyupet_send) forControlEvents:UIControlEventTouchUpInside]; [buttons addArrangedSubview:send];
    UIButton *cancel=[UIButton buttonWithType:UIButtonTypeSystem]; [cancel setTitle:@"取消" forState:UIControlStateNormal];
    [cancel addTarget:self action:@selector(mowang_dafeiyupet_cancel) forControlEvents:UIControlEventTouchUpInside]; [buttons addArrangedSubview:cancel]; [stack addArrangedSubview:buttons];
    self.mowang_dafeiyupet_status=[UILabel new]; self.mowang_dafeiyupet_status.font=[UIFont systemFontOfSize:13]; self.mowang_dafeiyupet_status.numberOfLines=0; [stack addArrangedSubview:self.mowang_dafeiyupet_status];
    self.mowang_dafeiyupet_reply=[UITextView new]; self.mowang_dafeiyupet_reply.editable=NO; self.mowang_dafeiyupet_reply.font=[UIFont systemFontOfSize:16];
    [self.mowang_dafeiyupet_reply.heightAnchor constraintEqualToConstant:160].active=YES; [stack addArrangedSubview:self.mowang_dafeiyupet_reply];
    [self mowang_dafeiyupet_renderHistory];
    if(self.mowang_dafeiyupet_compact) [self mowang_dafeiyupet_buildBubble];
}
- (void)mowang_dafeiyupet_buildBubble {
    for(UIView *v in self.view.subviews.copy) [v removeFromSuperview];
    self.view.backgroundColor=UIColor.clearColor;
    UIStackView *content=[UIStackView new]; content.axis=UILayoutConstraintAxisVertical; content.spacing=4;
    content.translatesAutoresizingMaskIntoConstraints=NO; content.tag=700;
    [self.view addSubview:content];
    [NSLayoutConstraint activateConstraints:@[[content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [content.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:15],
        [content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-15]]];
    UIStackView *header=[UIStackView new]; header.spacing=8;
    UILabel *title=[UILabel new]; title.text=@"和大肥鱼聊聊"; title.textColor=[UIColor colorWithRed:.22 green:.26 blue:.32 alpha:1]; title.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; [header addArrangedSubview:title];
    UIButton *more=[UIButton buttonWithType:UIButtonTypeSystem]; [more setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal]; more.accessibilityLabel=@"聊天更多操作";
    [more.widthAnchor constraintEqualToConstant:32].active=YES;
    [more addTarget:self action:@selector(mowang_dafeiyupet_more:) forControlEvents:UIControlEventTouchUpInside]; [header addArrangedSubview:more];
    UIButton *close=[UIButton buttonWithType:UIButtonTypeSystem]; [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal]; close.accessibilityLabel=@"关闭聊天";
    [close.widthAnchor constraintEqualToConstant:32].active=YES;
    [header.heightAnchor constraintEqualToConstant:32].active=YES;
    [close addTarget:self action:@selector(mowang_dafeiyupet_close) forControlEvents:UIControlEventTouchUpInside]; [header addArrangedSubview:close];
    [content addArrangedSubview:header];
    for(NSLayoutConstraint *c in self.mowang_dafeiyupet_reply.constraints.copy) if(c.firstAttribute==NSLayoutAttributeHeight) c.active=NO;
    self.mowang_dafeiyupet_reply.font=[UIFont systemFontOfSize:14];
    self.mowang_dafeiyupet_reply.backgroundColor=UIColor.clearColor;
    self.mowang_dafeiyupet_reply.accessibilityLabel=@"大肥鱼聊天记录";
    self.mowang_dafeiyupet_reply.editable=NO; self.mowang_dafeiyupet_reply.scrollEnabled=YES;
    self.mowang_dafeiyupet_reply.textContainerInset=UIEdgeInsetsMake(6,2,6,2);
    self.mowang_dafeiyupet_reply.textContainer.lineFragmentPadding=0;
    if(!self.mowang_dafeiyupet_history.count) self.mowang_dafeiyupet_reply.text=@"想和我说些什么？";
    [content addArrangedSubview:self.mowang_dafeiyupet_reply];
    self.mowang_dafeiyupet_compactReplyHeight=[self.mowang_dafeiyupet_reply.heightAnchor constraintEqualToConstant:48];
    self.mowang_dafeiyupet_compactReplyHeight.priority=UILayoutPriorityDefaultHigh;
    self.mowang_dafeiyupet_compactReplyHeight.active=YES;
    for(NSLayoutConstraint *c in self.mowang_dafeiyupet_input.constraints.copy) if(c.firstAttribute==NSLayoutAttributeHeight) c.active=NO;
    [self.mowang_dafeiyupet_input.heightAnchor constraintEqualToConstant:44].active=YES;
    self.mowang_dafeiyupet_input.font=[UIFont systemFontOfSize:15]; self.mowang_dafeiyupet_input.layer.cornerRadius=14;
    self.mowang_dafeiyupet_input.backgroundColor=[UIColor colorWithRed:.94 green:.96 blue:.98 alpha:1];
    self.mowang_dafeiyupet_input.textColor=[UIColor colorWithWhite:.16 alpha:1];
    self.mowang_dafeiyupet_input.textContainerInset=UIEdgeInsetsMake(11,9,9,9);
    self.mowang_dafeiyupet_input.editable=YES; self.mowang_dafeiyupet_input.selectable=YES; self.mowang_dafeiyupet_input.userInteractionEnabled=YES;
    UITapGestureRecognizer *focus=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mowang_dafeiyupet_focusInput)]; focus.cancelsTouchesInView=NO;
    [self.mowang_dafeiyupet_input addGestureRecognizer:focus];
    UIStackView *composer=[UIStackView new]; composer.spacing=6;
    [composer addArrangedSubview:self.mowang_dafeiyupet_input];
    UIButton *compactPaste=[UIButton buttonWithType:UIButtonTypeSystem]; [compactPaste setTitle:@"粘贴" forState:UIControlStateNormal]; compactPaste.accessibilityLabel=@"粘贴到聊天输入";
    [compactPaste.widthAnchor constraintEqualToConstant:44].active=YES;
    [compactPaste addTarget:self action:@selector(mowang_dafeiyupet_paste) forControlEvents:UIControlEventTouchUpInside]; [composer addArrangedSubview:compactPaste];
    UIButton *send=[UIButton buttonWithType:UIButtonTypeSystem]; [send setImage:[UIImage systemImageNamed:@"arrow.up"] forState:UIControlStateNormal]; send.accessibilityLabel=@"发送";
    send.backgroundColor=[UIColor colorWithRed:.21 green:.48 blue:.67 alpha:1]; send.tintColor=UIColor.whiteColor; send.layer.cornerRadius=22;
    [send.widthAnchor constraintEqualToConstant:44].active=YES;
    [send addTarget:self action:@selector(mowang_dafeiyupet_send) forControlEvents:UIControlEventTouchUpInside]; [composer addArrangedSubview:send];
    [content addArrangedSubview:composer];
    self.mowang_dafeiyupet_status.font=[UIFont systemFontOfSize:11]; self.mowang_dafeiyupet_status.numberOfLines=2; self.mowang_dafeiyupet_status.lineBreakMode=NSLineBreakByTruncatingTail;
    self.mowang_dafeiyupet_status.textColor=[UIColor colorWithRed:.22 green:.26 blue:.32 alpha:1];
    self.mowang_dafeiyupet_status.backgroundColor=[UIColor colorWithRed:.94 green:.96 blue:.98 alpha:1];
    self.mowang_dafeiyupet_status.accessibilityLabel=@"AI 请求日志";
    [self.mowang_dafeiyupet_status.heightAnchor constraintEqualToConstant:32].active=YES;
    [self.mowang_dafeiyupet_status setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    self.mowang_dafeiyupet_status.text=@"AI 请求日志 · 就绪"; [content addArrangedSubview:self.mowang_dafeiyupet_status];
    self.mowang_dafeiyupet_reply.textColor=[UIColor colorWithWhite:.22 alpha:1];
    self.view.tintColor=[UIColor colorWithRed:.21 green:.48 blue:.67 alpha:1];
    [self.mowang_dafeiyupet_reply.heightAnchor constraintGreaterThanOrEqualToConstant:48].active=YES;
}
- (void)mowang_dafeiyupet_more:(UIButton *)sender {
    NSDictionary *state=mowang_dafeiyupet_petState(mowang_dafeiyupet_readPreferences());
    NSDictionary *pet=mowang_dafeiyupet_activePet(state);
    if(self.mowang_dafeiyupet_compact && !self.mowang_dafeiyupet_memoryEnabled) {
        self.mowang_dafeiyupet_petID=state[@"activeID"];
        self.mowang_dafeiyupet_memoryEnabled=[UISwitch new];
        self.mowang_dafeiyupet_memoryEnabled.on=[pet[@"memoryEnabled"] boolValue];
        self.mowang_dafeiyupet_memoryEnabled.enabled=self.mowang_dafeiyupet_petID.length>0;
        self.mowang_dafeiyupet_voiceEnabled=[UISwitch new];
        self.mowang_dafeiyupet_voiceVolume=[UISlider new]; self.mowang_dafeiyupet_voiceVolume.value=.7;
    }
    BOOL memory=[pet[@"memoryEnabled"] boolValue];
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"聊天设置" message:[NSString stringWithFormat:@"本机记忆：%@（最近6轮）\n语音朗读：%@（仅本次聊天）",memory?@"开启":@"关闭",self.mowang_dafeiyupet_voiceEnabled.on?@"开启":@"关闭"] preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *memoryTitle=memory?@"关闭本机记忆并删除保存记录":@"开启本机记忆";
    [menu addAction:[UIAlertAction actionWithTitle:memoryTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        self.mowang_dafeiyupet_memoryEnabled.on=!memory;
        [self mowang_dafeiyupet_memoryChanged];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:self.mowang_dafeiyupet_voiceEnabled.on?@"关闭回复朗读":@"开启回复朗读" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        self.mowang_dafeiyupet_voiceEnabled.on=!self.mowang_dafeiyupet_voiceEnabled.on;
        [self mowang_dafeiyupet_voiceChanged];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"选择中文声线" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self mowang_dafeiyupet_chooseVoice:sender]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"试听当前声线" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self mowang_dafeiyupet_previewVoice]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"停止语音" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self mowang_dafeiyupet_stopVoice]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"余额查询与站点设置请使用监控余额插件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ self.mowang_dafeiyupet_status.text=@"余额和今日消耗由监控余额插件负责；这里不重复发起查询。"; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"新对话" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self mowang_dafeiyupet_clear]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"取消请求" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self mowang_dafeiyupet_cancel]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"返回" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView=sender; menu.popoverPresentationController.sourceRect=sender.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)mowang_dafeiyupet_focusInput {
    UIWindow *window=self.view.window;
    if(!window || !self.mowang_dafeiyupet_compact) return;
    [window makeKeyWindow];
    BOOL accepted=self.mowang_dafeiyupet_input.isFirstResponder || [self.mowang_dafeiyupet_input becomeFirstResponder];
    os_log(os_log_create("com.mowang.dafeiyupet","chat"),"ChatFocus key=%d requested=%d first=%d attached=%d",window.isKeyWindow,accepted,self.mowang_dafeiyupet_input.isFirstResponder,window!=nil);
}
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    return YES;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if(!self.mowang_dafeiyupet_compact) return;
    CAShapeLayer *shape=nil;
    for(CALayer *layer in self.view.layer.sublayers) if([layer.name isEqual:@"mowang.chat.bubble"]) { shape=(id)layer; break; }
    if(!shape) { shape=[NSClassFromString(@"CAShapeLayer") new]; shape.name=@"mowang.chat.bubble"; [self.view.layer insertSublayer:shape atIndex:0]; }
    CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;
    BOOL top=self.mowang_dafeiyupet_tailOnTop;
    UIBezierPath *path=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,top?7:0,w,h-7) cornerRadius:18];
    CGFloat x=MAX(20,MIN(w-20,self.mowang_dafeiyupet_tailX)),y=top?7:h-7;
    [path moveToPoint:CGPointMake(x-7,y)]; [path addLineToPoint:CGPointMake(x,top?0:h)]; [path addLineToPoint:CGPointMake(x+7,y)]; [path closePath];
    shape.path=path.CGPath; shape.fillColor=[UIColor colorWithRed:1 green:.995 blue:.98 alpha:1].CGColor;
    shape.strokeColor=[UIColor colorWithRed:.86 green:.89 blue:.91 alpha:1].CGColor; shape.lineWidth=.5;
    shape.shadowColor=UIColor.blackColor.CGColor; shape.shadowOpacity=.10; shape.shadowRadius=12; shape.shadowOffset=CGSizeMake(0,3);
}
- (void)mowang_dafeiyupet_setStatus:(NSString *)status {
    self.mowang_dafeiyupet_status.text=status;
    if(self.mowang_dafeiyupet_compact && self.mowang_dafeiyupet_compactReplyHeight && self.mowang_dafeiyupet_contentChanged) self.mowang_dafeiyupet_contentChanged();
}
- (void)mowang_dafeiyupet_close {
    [self mowang_dafeiyupet_cancel];
    if(self.mowang_dafeiyupet_closeHandler) self.mowang_dafeiyupet_closeHandler();
}
- (CGFloat)mowang_dafeiyupet_bubbleHeightForWidth:(CGFloat)width {
    if(!self.mowang_dafeiyupet_compact || width<=0 || !self.mowang_dafeiyupet_compactReplyHeight) return 222;
    CGFloat textWidth=MAX(80,width-32);
    CGFloat used=60+44+24;
    if(self.mowang_dafeiyupet_status.text.length) used+=32;
    CGFloat replyHeight=48;
    if(self.mowang_dafeiyupet_history.count) {
        CGRect text=[self.mowang_dafeiyupet_reply.text boundingRectWithSize:CGSizeMake(textWidth,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:self.mowang_dafeiyupet_reply.font ?: [UIFont systemFontOfSize:14]} context:nil];
        replyHeight=MIN(220,MAX(replyHeight,ceil(text.size.height)+14));
    }
    return MIN(360,MAX(176,used+replyHeight));
}
- (void)mowang_dafeiyupet_renderHistory {
    NSMutableString *text=[NSMutableString new];
    for(NSDictionary *entry in self.mowang_dafeiyupet_history) [text appendFormat:@"%@：%@\n\n",[entry[@"role"] isEqual:@"user"]?@"你":@"大肥鱼",entry[@"content"]];
    self.mowang_dafeiyupet_reply.text=text;
    if(self.mowang_dafeiyupet_compactReplyHeight) {
        CGFloat width=MAX(1,self.view.bounds.size.width-32);
        CGRect measured=[text boundingRectWithSize:CGSizeMake(width,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:self.mowang_dafeiyupet_reply.font ?: [UIFont systemFontOfSize:14]} context:nil];
        self.mowang_dafeiyupet_compactReplyHeight.constant=MIN(220,MAX(48,ceil(measured.size.height)+14));
        [self.view layoutIfNeeded];
    }
    if(text.length) { NSUInteger end=self.mowang_dafeiyupet_reply.text.length; [self.mowang_dafeiyupet_reply scrollRangeToVisible:NSMakeRange(end?end-1:0,end?1:0)]; }
    if(self.mowang_dafeiyupet_contentChanged) self.mowang_dafeiyupet_contentChanged();
}
- (BOOL)mowang_dafeiyupet_saveMemory {
    NSDictionary *state=mowang_dafeiyupet_petState(mowang_dafeiyupet_readPreferences());
    NSDictionary *updated=mowang_dafeiyupet_updatingPet(state,self.mowang_dafeiyupet_petID,@{@"memoryEnabled":@(self.mowang_dafeiyupet_memoryEnabled.on),@"history":self.mowang_dafeiyupet_history ?: @[],@"providerIdentity":self.mowang_dafeiyupet_identity ?: @""});
    NSError *error=nil;
    BOOL ok=updated && mowang_dafeiyupet_writePreference(@"petState",updated,&error);
    if(!ok) self.mowang_dafeiyupet_status.text=@"记忆写入失败；请勿依赖保存结果。";
    return ok;
}
- (void)mowang_dafeiyupet_memoryChanged {
    [self mowang_dafeiyupet_cancel];
    if(![self mowang_dafeiyupet_saveMemory]) self.mowang_dafeiyupet_memoryEnabled.on=!self.mowang_dafeiyupet_memoryEnabled.on;
    else self.mowang_dafeiyupet_status.text=self.mowang_dafeiyupet_memoryEnabled.on?@"本机记忆已开启 · 后续请求会发送最近6轮":@"本机保存记录已删除 · 当前页上下文暂留";
}
- (void)mowang_dafeiyupet_chooseVoice:(UIView *)sender {
    NSArray<AVSpeechSynthesisVoice *> *voices=[[AVSpeechSynthesisVoice speechVoices] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AVSpeechSynthesisVoice *voice, NSDictionary *bindings) {
        return [voice.language hasPrefix:@"zh-"];
    }]];
    voices=[voices sortedArrayUsingComparator:^NSComparisonResult(AVSpeechSynthesisVoice *a, AVSpeechSynthesisVoice *b) {
        NSComparisonResult language=[a.language compare:b.language];
        return language!=NSOrderedSame?language:[a.name localizedStandardCompare:b.name];
    }];
    UIAlertController *picker=[UIAlertController alertControllerWithTitle:@"选择中文声线" message:@"只列出设备已有的系统声线；点击声线可试听，本次聊天的后续回复将使用它。" preferredStyle:UIAlertControllerStyleActionSheet];
    for(AVSpeechSynthesisVoice *voice in voices) {
        NSString *title=[NSString stringWithFormat:@"%@ · %@%@",voice.name,voice.language,[voice.identifier isEqualToString:self.mowang_dafeiyupet_voiceIdentifier]?@" ✓":@""];
        [picker addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            self.mowang_dafeiyupet_voiceIdentifier=voice.identifier;
            [self mowang_dafeiyupet_previewVoice];
        }]];
    }
    if(!voices.count) picker.message=@"本机未找到可用中文声线。可在系统辅助功能的朗读内容中管理声线。";
    [picker addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    picker.popoverPresentationController.sourceView=sender ?: self.view;
    picker.popoverPresentationController.sourceRect=sender?sender.bounds:self.view.bounds;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)mowang_dafeiyupet_stopVoice {
    self.mowang_dafeiyupet_utterance=nil;
    [self.mowang_dafeiyupet_speech stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    self.mowang_dafeiyupet_voiceStatus.text=@"语音已停止";
}
- (void)mowang_dafeiyupet_voiceChanged {
    if(!self.mowang_dafeiyupet_voiceEnabled.on) [self mowang_dafeiyupet_stopVoice];
}
- (void)mowang_dafeiyupet_speak:(NSString *)text {
    [self mowang_dafeiyupet_stopVoice];
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || !text.length) return;
    AVSpeechSynthesisVoice *voice=self.mowang_dafeiyupet_voiceIdentifier.length?[AVSpeechSynthesisVoice voiceWithIdentifier:self.mowang_dafeiyupet_voiceIdentifier]:nil;
    if(!voice || ![voice.language hasPrefix:@"zh-"]) voice=[AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
    if(!voice) { self.mowang_dafeiyupet_status.text=@"系统中文音色不可用；文字回复仍可阅读。"; return; }
    // Bound speech separately from the displayed reply to avoid minutes of queued audio.
    NSRange range=[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,MIN(text.length,600))];
    AVSpeechUtterance *utterance=[AVSpeechUtterance speechUtteranceWithString:[text substringWithRange:range]];
    utterance.voice=voice; utterance.rate=AVSpeechUtteranceDefaultSpeechRate;
    utterance.volume=self.mowang_dafeiyupet_voiceVolume.value;
    self.mowang_dafeiyupet_utterance=utterance;
    self.mowang_dafeiyupet_voiceStatus.text=@"语音准备中";
    [self.mowang_dafeiyupet_speech speakUtterance:utterance];
}
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance {
    dispatch_async(dispatch_get_main_queue(), ^{ if(utterance==self.mowang_dafeiyupet_utterance) self.mowang_dafeiyupet_voiceStatus.text=@"语音播放中"; });
}
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    dispatch_async(dispatch_get_main_queue(), ^{ if(utterance==self.mowang_dafeiyupet_utterance) { self.mowang_dafeiyupet_utterance=nil; self.mowang_dafeiyupet_voiceStatus.text=@"语音播放结束"; } });
}
- (void)mowang_dafeiyupet_previewVoice {
    [self mowang_dafeiyupet_speak:@"你好呀，我是大肥鱼，很高兴陪着你！"];
}
- (void)mowang_dafeiyupet_clear {
    [self mowang_dafeiyupet_cancel]; [self.mowang_dafeiyupet_history removeAllObjects];
    self.mowang_dafeiyupet_input.text=@""; self.mowang_dafeiyupet_reply.text=@"";
    if(self.mowang_dafeiyupet_memoryEnabled.on) [self mowang_dafeiyupet_saveMemory];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated]; [self mowang_dafeiyupet_cancel];
    // The latest successful turn was already saved; leaving must not erase it.
    [self.mowang_dafeiyupet_history removeAllObjects]; self.mowang_dafeiyupet_reply.text=@""; self.mowang_dafeiyupet_input.text=@"";
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if(self.mowang_dafeiyupet_memoryEnabled.on) {
        NSDictionary *state=mowang_dafeiyupet_petState(mowang_dafeiyupet_readPreferences());
        NSDictionary *pet=state[@"pets"][self.mowang_dafeiyupet_petID];
        self.mowang_dafeiyupet_history=[mowang_dafeiyupet_boundedHistory(pet[@"history"]) mutableCopy];
        self.mowang_dafeiyupet_identity=[pet[@"providerIdentity"] isKindOfClass:NSString.class]?pet[@"providerIdentity"]:nil;
        [self mowang_dafeiyupet_renderHistory];
    }
}
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    return textView.text.length-range.length+text.length<=2048;
}
- (void)mowang_dafeiyupet_paste {
    // UIPasteboard is accessed only after the user's explicit button tap.
    NSString *text=UIPasteboard.generalPasteboard.string;
    if(!text.length) { self.mowang_dafeiyupet_status.text=@"剪贴板没有文本"; return; }
    UITextView *input=self.mowang_dafeiyupet_input;
    NSRange selection=input.selectedRange;
    if(selection.location==NSNotFound || NSMaxRange(selection)>input.text.length) selection=NSMakeRange(input.text.length,0);
    if(text.length>2048 || input.text.length-selection.length+text.length>2048) { self.mowang_dafeiyupet_status.text=@"粘贴后超过2048字符，未修改输入"; return; }
    input.text=[input.text stringByReplacingCharactersInRange:selection withString:text];
    input.selectedRange=NSMakeRange(selection.location+text.length,0);
    self.mowang_dafeiyupet_status.text=@"已粘贴到输入框；仅点击发送才会提交";
}
- (void)mowang_dafeiyupet_key {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"API Key" message:@"输入保存在本机 Keychain；空值保存会删除。不会显示已存密钥。" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.secureTextEntry=YES; f.autocorrectionType=UITextAutocorrectionTypeNo;}];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *key=a.textFields.firstObject.text ?: @"";
        if(key.length>4096) { self.mowang_dafeiyupet_status.text=@"Key过长，未保存"; return; }
        NSMutableDictionary *q=[mowang_dafeiyupet_keyQuery() mutableCopy]; OSStatus status;
        if(!key.length) status=SecItemDelete((__bridge CFDictionaryRef)q);
        else {
            NSDictionary *attrs=@{(__bridge id)kSecValueData:[key dataUsingEncoding:NSUTF8StringEncoding],(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
            status=SecItemUpdate((__bridge CFDictionaryRef)q,(__bridge CFDictionaryRef)attrs);
            if(status==errSecItemNotFound) { [q addEntriesFromDictionary:attrs]; status=SecItemAdd((__bridge CFDictionaryRef)q,NULL); }
        }
        a.textFields.firstObject.text=@"";
        self.mowang_dafeiyupet_status.text=(status==errSecSuccess||(!key.length&&status==errSecItemNotFound))?@"Key 已更新":@"Keychain失败；不降级明文存储";
    }]];
    // Present from the chat-owning window; focus only after the alert is attached.
    [self.view.window makeKeyWindow];
    [self presentViewController:a animated:YES completion:^{
        [a.view.window makeKeyWindow];
        [a.textFields.firstObject becomeFirstResponder];
    }];
}
- (void)mowang_dafeiyupet_cancel {
    BOOL wasRunning=self.mowang_dafeiyupet_task!=nil;
    [self mowang_dafeiyupet_stopVoice];
    [self.mowang_dafeiyupet_task cancel]; self.mowang_dafeiyupet_task=nil;
    [self.mowang_dafeiyupet_session invalidateAndCancel]; self.mowang_dafeiyupet_session=nil;
    self.mowang_dafeiyupet_data=nil; [self mowang_dafeiyupet_setStatus:wasRunning?@"AI 请求日志 · 已取消":@"AI 请求日志 · 就绪"];
}
- (void)mowang_dafeiyupet_send {
    os_log(os_log_create("com.mowang.dafeiyupet","chat"),"ChatSend entered compact=%d inputLength=%{public}lu",self.mowang_dafeiyupet_compact,(unsigned long)self.mowang_dafeiyupet_input.text.length);
    [self mowang_dafeiyupet_cancel];
    if(self.mowang_dafeiyupet_compact) [self mowang_dafeiyupet_setStatus:@"AI 请求日志 · 正在校验请求…"];
    [self.view endEditing:YES];
    NSDictionary *cfg=mowang_dafeiyupet_readPreferences();
    NSString *base=[cfg[@"aiURL"] isKindOfClass:NSString.class]?cfg[@"aiURL"]:@"https://api.openai.com/v1";
    NSString *model=[cfg[@"aiModel"] isKindOfClass:NSString.class]?cfg[@"aiModel"]:@"gpt-4o-mini";
    self.mowang_dafeiyupet_ollama=[cfg[@"aiProvider"] isEqual:@"ollama"];
    model=[model stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL *endpoint=mowang_dafeiyupet_aiEndpoint(base,self.mowang_dafeiyupet_ollama,[cfg[@"aiAllowHTTP"] boolValue]);
    if(!endpoint || !model.length || model.length>128) { [self mowang_dafeiyupet_setStatus:@"请配置合法服务地址与模型；HTTP 必须手动开启。Ollama 地址应指向运行模型的电脑，而非默认指向这台手机的 localhost。"]; return; }
    NSString *text=[self.mowang_dafeiyupet_input.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!text.length || text.length>2048) { [self mowang_dafeiyupet_setStatus:@"输入须为1–2048字符"]; return; }
    NSString *identity=[NSString stringWithFormat:@"%@|%@|%d",endpoint.absoluteString,model,self.mowang_dafeiyupet_ollama];
    if(![identity isEqual:self.mowang_dafeiyupet_identity]) {
        [self.mowang_dafeiyupet_history removeAllObjects]; [self mowang_dafeiyupet_renderHistory];
        self.mowang_dafeiyupet_identity=identity;
        if(self.mowang_dafeiyupet_memoryEnabled.on && ![self mowang_dafeiyupet_saveMemory]) return;
    }
    self.mowang_dafeiyupet_identity=identity;
    NSMutableDictionary *q=[mowang_dafeiyupet_keyQuery() mutableCopy]; q[(__bridge id)kSecReturnData]=@YES;
    CFTypeRef value=NULL; OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)q,&value);
    NSData *secret=CFBridgingRelease(value);
    NSString *key=status==errSecSuccess?[[NSString alloc] initWithData:secret encoding:NSUTF8StringEncoding]:nil;
    if(status!=errSecSuccess && status!=errSecItemNotFound) { [self mowang_dafeiyupet_setStatus:@"无法读取 Keychain，请解锁设备并重新保存密钥。"]; return; }
    if([key rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound && key.length) { [self mowang_dafeiyupet_setStatus:@"Key 不能包含换行，请重新保存。"]; return; }
    BOOL https=[endpoint.scheme.lowercaseString isEqual:@"https"];
    if(!https && key.length && !self.mowang_dafeiyupet_ollama) { [self mowang_dafeiyupet_setStatus:@"不会通过 HTTP 发送已存密钥，请改用 HTTPS，或删除密钥以使用免鉴权的本地服务。"]; return; }
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:endpoint]; r.HTTPMethod=@"POST"; r.timeoutInterval=90;
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if(key.length && !self.mowang_dafeiyupet_ollama) [r setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    NSMutableArray *messages=[NSMutableArray arrayWithObject:@{@"role":@"system",@"content":@"你是友善、活泼的大肥鱼桌宠，用简短自然的中文回答。"}];
    [messages addObjectsFromArray:self.mowang_dafeiyupet_history];
    [messages addObject:@{@"role":@"user",@"content":text}];
    self.mowang_dafeiyupet_pending=text;
    NSDictionary *body=self.mowang_dafeiyupet_ollama?@{@"model":model,@"messages":messages,@"stream":@NO,@"options":@{@"num_predict":@1024,@"temperature":@0.9}}:@{@"model":model,@"messages":messages,@"max_tokens":@1024,@"stream":@NO};
    r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSURLSessionConfiguration *conf=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    conf.timeoutIntervalForRequest=90; conf.timeoutIntervalForResource=95; conf.URLCache=nil; conf.HTTPCookieStorage=nil;
    self.mowang_dafeiyupet_session=[NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.mowang_dafeiyupet_failure=nil;
    self.mowang_dafeiyupet_data=[NSMutableData new]; self.mowang_dafeiyupet_httpOK=NO;
    self.mowang_dafeiyupet_task=[self.mowang_dafeiyupet_session dataTaskWithRequest:r];
    [self mowang_dafeiyupet_setStatus:self.mowang_dafeiyupet_compact?@"AI 请求日志 · 正在请求，等待回复…":@"正在请求，等待回复…"];
    [self.mowang_dafeiyupet_task resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil); // Never forward Authorization to a redirect target.
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if(task!=self.mowang_dafeiyupet_task) { completionHandler(NSURLSessionResponseCancel); return; }
    NSInteger code=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
    switch(code) {
        case 200: break;
        case 400: case 422: self.mowang_dafeiyupet_failure=@"模型名或请求参数不被接受，请按服务商文档检查模型。"; break;
        case 402: self.mowang_dafeiyupet_failure=@"账户额度不足，请检查服务账号余额。"; break;
        case 401: case 403: self.mowang_dafeiyupet_failure=@"API Key 无效或没有模型权限，请检查密钥与服务账号。"; break;
        case 404: self.mowang_dafeiyupet_failure=@"接口不存在，请检查 Base URL 的 /v1 路径和模型名。"; break;
        case 429: self.mowang_dafeiyupet_failure=@"请求过于频繁或额度不足，请稍后重试并检查余额。"; break;
        default: self.mowang_dafeiyupet_failure=code>=300&&code<400?@"服务要求重定向；为保护密钥已拒绝，请填写最终 HTTPS 地址。":@"服务暂时不可用，请检查接口配置或稍后重试。";
    }
    if(response.expectedContentLength>65536) self.mowang_dafeiyupet_failure=@"响应超过64KB限制，请缩短回答后重试。";
    self.mowang_dafeiyupet_httpOK=code==200 && response.expectedContentLength<=65536;
    completionHandler(self.mowang_dafeiyupet_httpOK?NSURLSessionResponseAllow:NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(task!=self.mowang_dafeiyupet_task) return;
    if(self.mowang_dafeiyupet_data.length+data.length>65536) { self.mowang_dafeiyupet_failure=@"响应超过64KB限制，请缩短回答后重试。"; self.mowang_dafeiyupet_httpOK=NO; [task cancel]; return; }
    [self.mowang_dafeiyupet_data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(task!=self.mowang_dafeiyupet_task) return;
    if(!error && self.mowang_dafeiyupet_httpOK) {
        id json=[NSJSONSerialization JSONObjectWithData:self.mowang_dafeiyupet_data options:0 error:nil];
        NSString *answer=mowang_dafeiyupet_aiAnswer(json,self.mowang_dafeiyupet_ollama);
        if(answer) {
            NSString *bounded=[answer substringWithRange:[answer rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,MIN(answer.length,8192))]];
            [self.mowang_dafeiyupet_history addObject:@{@"role":@"user",@"content":self.mowang_dafeiyupet_pending ?: @""}];
            [self.mowang_dafeiyupet_history addObject:@{@"role":@"assistant",@"content":bounded}];
            self.mowang_dafeiyupet_history=[mowang_dafeiyupet_boundedHistory(self.mowang_dafeiyupet_history) mutableCopy];
            [self mowang_dafeiyupet_renderHistory];
            self.mowang_dafeiyupet_input.text=@"";
            [self mowang_dafeiyupet_setStatus:self.mowang_dafeiyupet_compact?(self.mowang_dafeiyupet_memoryEnabled.on?@"AI 请求日志 · 已完成，记忆已保存":@"AI 请求日志 · 已完成"):(self.mowang_dafeiyupet_memoryEnabled.on?@"完成 · 已保留最近6轮本机记忆":@"完成 · 保留本页最近6轮，离开即清除")];
            if(self.mowang_dafeiyupet_memoryEnabled.on) [self mowang_dafeiyupet_saveMemory];
            if(self.mowang_dafeiyupet_voiceEnabled.on) [self mowang_dafeiyupet_speak:bounded];
        } else [self mowang_dafeiyupet_setStatus:self.mowang_dafeiyupet_compact?@"AI 请求日志 · 失败：服务未返回有效文本":@"服务未返回有效文本，请检查模型是否支持聊天协议。"];
    } else {
        NSString *reason=self.mowang_dafeiyupet_failure;
        if(!reason && [error.domain isEqual:NSURLErrorDomain]) {
            switch(error.code) {
                case NSURLErrorTimedOut: reason=@"请求超时，请检查网络或稍后重试。"; break;
                case NSURLErrorNotConnectedToInternet: reason=@"当前无网络连接，请检查 Wi-Fi 或蜂窝网络。"; break;
                case NSURLErrorCannotFindHost: case NSURLErrorCannotConnectToHost: reason=self.mowang_dafeiyupet_ollama?@"无法连接 Ollama。请在运行模型的电脑启动 ollama serve，执行 ollama pull 模型名；手机填写电脑可访问的地址，并检查防火墙。":@"无法连接服务，请检查 Base URL 和服务是否在线。"; break;
                default: break;
            }
        }
        [self mowang_dafeiyupet_setStatus:self.mowang_dafeiyupet_compact?[NSString stringWithFormat:@"AI 请求日志 · 失败：%@",reason ?: @"安全连接失败"]:(reason ?: @"安全连接失败，请检查 HTTPS 证书和网络；未记录服务详情。")];
    }
    self.mowang_dafeiyupet_task=nil; self.mowang_dafeiyupet_data=nil;
    [self.mowang_dafeiyupet_session finishTasksAndInvalidate]; self.mowang_dafeiyupet_session=nil;
}
@end
