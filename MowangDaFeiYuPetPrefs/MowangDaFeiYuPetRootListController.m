#import "MowangDaFeiYuPetRootListController.h"
#import "MowangDaFeiYuPetPreferences.h"
#import "MowangDaFeiYuPetEnvironment.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
@interface PSSpecifier (MowangDaFeiYuPetButton)
@property (nonatomic, assign) SEL buttonAction;
@end
#import <UIKit/UIKit.h>
#import "MowangDaFeiYuPetChatController.h"
#import "MowangDaFeiYuPetPomodoroController.h"
#import "MowangDaFeiYuPetAIProtocol.h"
#import <Security/Security.h>


@interface MowangDaFeiYuPetRootListController () <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@property(nonatomic,strong) MowangPetWeatherRequest *weatherSearch;
@property(nonatomic) NSTimeInterval weatherSearchAfter;
@property(nonatomic,strong) NSURLSession *modelsSession;
@property(nonatomic,strong) NSURLSessionDataTask *modelsTask;
@property(nonatomic,strong) NSMutableData *modelsData;
@property(nonatomic) BOOL modelsOllama;
@property(nonatomic,copy) NSString *modelsFailure;
@property(nonatomic,weak) UITextField *keyField;
@end

@implementation MowangDaFeiYuPetRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [[self loadSpecifiersFromPlistName:@"MowangDaFeiYuPetRoot"
                                                           target:self] mutableCopy];
        [self mowang_dafeiyupet_addButton:@"搜索 / 选择天气城市" action:@selector(environmentSelectCity:) to:items];
        [self mowang_dafeiyupet_addButton:@"立即预览天气碎碎念" action:@selector(environmentWeatherPreview:) to:items];
        [self mowang_dafeiyupet_addButton:@"立即预览电量提醒（模拟短句）" action:@selector(environmentBatteryPreview:) to:items];
        [self mowang_dafeiyupet_addButton:@"预览一句离线碎碎念" action:@selector(mowang_dafeiyupet_whisperPreview:) to:items];
        [self mowang_dafeiyupet_addButton:@"回初始位置" action:@selector(mowang_dafeiyupet_reset:) to:items];
        [self mowang_dafeiyupet_addButton:@"番茄钟 · 专注 / 休息" action:@selector(mowang_dafeiyupet_pomodoro:) to:items];

        NSUInteger aiIndex=[items indexOfObjectPassingTest:^BOOL(PSSpecifier *item, NSUInteger index, BOOL *stop) {
            return [[item propertyForKey:@"key"] isEqual:@"aiModel"];
        }];
        NSMutableArray *aiButtons=[NSMutableArray new];
        [self mowang_dafeiyupet_addButton:@"设置 / 删除 API Key" action:@selector(mowang_dafeiyupet_editKey:) to:aiButtons];
        [self mowang_dafeiyupet_addButton:@"获取模型（手动填写仍可用）" action:@selector(mowang_dafeiyupet_fetchModels:) to:aiButtons];
        [items insertObjects:aiButtons atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(aiIndex==NSNotFound?items.count:aiIndex+1,aiButtons.count)]];
        _specifiers = items;
    }
    return _specifiers;
}

- (void)environmentMessage:(NSString *)text {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"天气与电量" message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)environmentPreview:(NSString *)key {
    NSError *error=nil;
    BOOL saved=mowang_dafeiyupet_writePreference(key,@(NSDate.date.timeIntervalSince1970),&error);
    [self environmentMessage:saved?@"已请求。请在两分钟内回到桌宠可见的位置，提醒会等当前气泡和操作结束后显示；不调用 AI。天气须先选城市并开启，失败不会虚构天气；电量预览为模拟短句。":@"请求未保存，请重试。"];
}
- (void)environmentWeatherPreview:(id)sender { [self environmentPreview:@"weatherPreviewToken"]; }
- (void)environmentBatteryPreview:(id)sender { [self environmentPreview:@"batteryPreviewToken"]; }
- (void)environmentSelectCity:(id)sender {
    id city=mowang_dafeiyupet_readPreferences()[@"weatherCity"];
    NSString *current=mowang_pet_city(city)?city[@"name"]:@"未选择";
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"手动选择城市" message:[NSString stringWithFormat:@"当前：%@。点击搜索会将城市关键词发送给 Open-Meteo；选中后保存城市坐标，开启天气后将坐标发送给其天气服务。不读取定位或天气 App，不需要 Key。",current] preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder=@"输入至少两个字的城市名"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清除城市" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error=nil; if(!mowang_dafeiyupet_writePreference(@"weatherCity",nil,&error)) [self environmentMessage:@"城市未清除，请重试。"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"搜索（发送城市名）" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *query=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(query.length<2 || query.length>80 || !mowang_pet_label(query)) { [self environmentMessage:@"请输入 2–80 字的城市名称。 "]; return; }
        if(self.weatherSearch || NSDate.date.timeIntervalSince1970<self.weatherSearchAfter) { [self environmentMessage:@"搜索太频繁，请稍后再试。 "]; return; }
        self.weatherSearchAfter=NSDate.date.timeIntervalSince1970+10;
        NSURLComponents *url=[NSURLComponents componentsWithString:@"https://geocoding-api.open-meteo.com/v1/search"];
        url.queryItems=@[[NSURLQueryItem queryItemWithName:@"name" value:query],[NSURLQueryItem queryItemWithName:@"count" value:@"5"],[NSURLQueryItem queryItemWithName:@"language" value:@"zh"],[NSURLQueryItem queryItemWithName:@"format" value:@"json"]];
        self.weatherSearch=[MowangPetWeatherRequest new];
        __weak typeof(self) weakSelf=self;
        [self.weatherSearch start:url.URL completion:^(id json, NSString *failure) {
            typeof(self) owner=weakSelf; if(!owner) return; owner.weatherSearch=nil;
            NSArray *cities=mowang_pet_cities(json);
            if(failure || !cities.count) { [owner environmentMessage:failure ?: @"没有找到城市，请尝试其他名称。 "]; return; }
            UIAlertController *picker=[UIAlertController alertControllerWithTitle:@"请选择匹配城市" message:@"只保存所选城市，不会自动开启天气。数据：Open-Meteo / GeoNames。" preferredStyle:UIAlertControllerStyleActionSheet];
            for(NSDictionary *row in cities) [picker addAction:[UIAlertAction actionWithTitle:row[@"label"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *choice) {
                NSError *error=nil;
                [owner environmentMessage:mowang_dafeiyupet_writePreference(@"weatherCity",row,&error)?@"城市已保存；开启天气碎碎念后才会请求天气。":@"城市未保存，请重试。"];
            }]];
            [picker addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            picker.popoverPresentationController.sourceView=owner.view; picker.popoverPresentationController.sourceRect=owner.view.bounds;
            [owner presentViewController:picker animated:YES completion:nil];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)mowang_dafeiyupet_pasteKey:(id)sender {
    UITextField *field=self.keyField;
    if(!field) return;
    NSString *text=UIPasteboard.generalPasteboard.string;
    if(!text.length || text.length>4096 || [text rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound) {
        field.placeholder=@"剪贴板为空、过长或含换行";
        return;
    }
    field.text=text;
}
- (void)mowang_dafeiyupet_editKey:(id)sender {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"API Key"
        message:@"密钥仅存本机 Keychain，不显示已保存内容。留空点保存将删除密钥。"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.secureTextEntry=YES;
        field.autocorrectionType=UITextAutocorrectionTypeNo;
        field.autocapitalizationType=UITextAutocapitalizationTypeNone;
        field.placeholder=@"输入 API Key";
        UIButton *paste=[UIButton buttonWithType:UIButtonTypeSystem];
        [paste setTitle:@"粘贴" forState:UIControlStateNormal];
        paste.frame=CGRectMake(0,0,48,36);
        paste.accessibilityLabel=@"粘贴 API Key";
        [paste addTarget:self action:@selector(mowang_dafeiyupet_pasteKey:) forControlEvents:UIControlEventTouchUpInside];
        field.rightView=paste; field.rightViewMode=UITextFieldViewModeAlways;
        self.keyField=field;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key=alert.textFields.firstObject.text ?: @"";
        if(key.length>4096 || [key rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound) {
            [self mowang_dafeiyupet_modelsMessage:@"Key 过长或含换行，未保存。"];
            return;
        }
        NSMutableDictionary *query=[@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService:@"com.mowang.dafeiyupet.ai",(__bridge id)kSecAttrAccount:@"provider"} mutableCopy];
        OSStatus status;
        if(!key.length) status=SecItemDelete((__bridge CFDictionaryRef)query);
        else {
            NSDictionary *attributes=@{(__bridge id)kSecValueData:[key dataUsingEncoding:NSUTF8StringEncoding],
                (__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
            status=SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)attributes);
            if(status==errSecItemNotFound) { [query addEntriesFromDictionary:attributes]; status=SecItemAdd((__bridge CFDictionaryRef)query,NULL); }
        }
        alert.textFields.firstObject.text=@"";
        NSString *message=(status==errSecSuccess || (!key.length && status==errSecItemNotFound))
            ? (key.length ? @"Key 已更新。" : @"Key 已删除。")
            : @"Keychain 操作失败；未写入明文设置。";
        UIAlertController *result=[UIAlertController alertControllerWithTitle:@"API Key" message:message preferredStyle:UIAlertControllerStyleAlert];
        [result addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:result animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:^{ [alert.textFields.firstObject becomeFirstResponder]; }];
}

- (void)mowang_dafeiyupet_modelsMessage:(NSString *)message {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"获取模型" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)mowang_dafeiyupet_stopModels {
    [self.modelsTask cancel]; self.modelsTask=nil;
    [self.modelsSession invalidateAndCancel]; self.modelsSession=nil;
    self.modelsData=nil;
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; [self mowang_dafeiyupet_stopModels];
    [self.weatherSearch cancel]; self.weatherSearch=nil;
}
- (void)mowang_dafeiyupet_fetchModels:(id)sender {
    if(self.modelsTask) return;
    NSDictionary *cfg=mowang_dafeiyupet_readPreferences();
    BOOL ollama=[cfg[@"aiProvider"] isEqual:@"ollama"];
    NSString *base=[cfg[@"aiURL"] isKindOfClass:NSString.class]?cfg[@"aiURL"]:@"https://api.openai.com/v1";
    NSURL *url=mowang_dafeiyupet_modelsEndpoint(base,ollama,[cfg[@"aiAllowHTTP"] boolValue]);
    if(!url) { [self mowang_dafeiyupet_modelsMessage:@"请先填写合法 Base URL；HTTP 须明确开启。"] ; return; }
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url]; request.timeoutInterval=20;
    if(!ollama && [url.scheme.lowercaseString isEqual:@"https"]) {
        NSDictionary *query=@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService:@"com.mowang.dafeiyupet.ai",(__bridge id)kSecAttrAccount:@"provider",(__bridge id)kSecReturnData:@YES};
        CFTypeRef result=NULL; OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)query,&result);
        NSData *secret=CFBridgingRelease(result);
        if(status!=errSecSuccess && status!=errSecItemNotFound) { [self mowang_dafeiyupet_modelsMessage:@"无法读取 Keychain，请解锁设备后重试。"] ; return; }
        NSString *key=status==errSecSuccess?[[NSString alloc] initWithData:secret encoding:NSUTF8StringEncoding]:nil;
        if(key.length && [key rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound) { [self mowang_dafeiyupet_modelsMessage:@"Key 含换行，请重新保存。"] ; return; }
        if(key.length) [request setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    }
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForResource=25; config.URLCache=nil; config.HTTPCookieStorage=nil;
    self.modelsOllama=ollama; self.modelsFailure=nil; self.modelsData=[NSMutableData new];
    self.modelsSession=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.modelsTask=[self.modelsSession dataTaskWithRequest:request];
    [self.modelsTask resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSInteger code=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
    if(task!=self.modelsTask || code!=200 || response.expectedContentLength>65536) {
        self.modelsFailure=code==401||code==403?@"鉴权失败或无模型列表权限；可手动填写模型。":@"模型列表不可用或响应过大；可手动填写模型。";
        completionHandler(NSURLSessionResponseCancel); return;
    }
    completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(task!=self.modelsTask) return;
    if(self.modelsData.length+data.length>65536) { self.modelsFailure=@"模型列表超过 64KB；可手动填写模型。"; [task cancel]; return; }
    [self.modelsData appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(task!=self.modelsTask) return;
    NSArray<NSString *> *names=nil;
    if(!error && !self.modelsFailure) {
        id json=[NSJSONSerialization JSONObjectWithData:self.modelsData options:0 error:nil];
        names=mowang_dafeiyupet_modelNames(json,self.modelsOllama);
    }
    NSString *failure=self.modelsFailure;
    [self mowang_dafeiyupet_stopModels];
    if(!names.count) { [self mowang_dafeiyupet_modelsMessage:failure ?: @"未获得可用模型；可手动填写模型。"] ; return; }
    UIAlertController *picker=[UIAlertController alertControllerWithTitle:@"选择模型" message:@"仅选择后保存；也可返回手动填写。" preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSString *name in names) [picker addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSError *saveError=nil;
        if(!mowang_dafeiyupet_writePreference(@"aiModel",name,&saveError)) [self mowang_dafeiyupet_modelsMessage:@"模型未保存，请手动填写。"];
        else [self reloadSpecifiers];
    }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    picker.popoverPresentationController.sourceView=self.view;
    picker.popoverPresentationController.sourceRect=self.view.bounds;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)mowang_dafeiyupet_whisperPreview:(id)sender {
    NSError *error=nil;
    BOOL saved=mowang_dafeiyupet_writePreference(@"whisperPreviewToken",@([NSDate date].timeIntervalSince1970),&error);
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:saved?@"离线预览已请求":@"请求未保存"
        message:saved?@"请回到桌宠可见的位置；待当前动作、拖拽或气泡结束后显示一句本地短句，不调用 AI。":error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)mowang_dafeiyupet_reset:(id)sender {
    PSSpecifier *item=[PSSpecifier preferenceSpecifierNamed:@"reset" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [item setProperty:@"resetToken" forKey:@"key"];
    [self setPreferenceValue:@([NSDate date].timeIntervalSince1970) specifier:item];
}
- (void)mowang_dafeiyupet_pomodoro:(id)sender {
    [self.navigationController pushViewController:[MowangDaFeiYuPetPomodoroController new] animated:YES];
}

- (void)mowang_dafeiyupet_addButton:(NSString *)title action:(SEL)action to:(NSMutableArray *)items {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:title target:self
                          set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    item.buttonAction = action;
    [items addObject:item];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return nil;
    return mowang_dafeiyupet_readPreferences()[key] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return;
    NSError *error = nil;
    if (!mowang_dafeiyupet_writePreference(key, value, &error)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置未保存"
            message:error.localizedDescription ?: @"请检查配置文件路径和写入权限。"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSpecifiers];
    }
}

- (void)mowang_dafeiyupet_openURL:(NSURL *)url fallback:(NSURL *)fallback {
    if (!url) return;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success) return;
        if (fallback) {
            [self mowang_dafeiyupet_openURL:fallback fallback:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开链接"
                message:@"请确认已安装对应应用。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (void)mowang_dafeiyupet_openRepository:(id)sender {
    NSString *source = @"https://axs66.github.io/pro";
    // Encode the entire URL as a path component, including its own delimiters.
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                              @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    NSString *encoded = [source stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSURL *primary = [NSURL URLWithString:[@"sileo://source/" stringByAppendingString:encoded]];
    [self mowang_dafeiyupet_openURL:primary fallback:[NSURL URLWithString:source]];
}

- (void)mowang_dafeiyupet_openTelegram:(id)sender {
    [self mowang_dafeiyupet_openURL:[NSURL URLWithString:@"tg://resolve?domain=wxfx8"]
                   fallback:[NSURL URLWithString:@"https://t.me/wxfx8"]];
}

- (void)mowang_dafeiyupet_openQQ:(id)sender {
    [self mowang_dafeiyupet_openURL:[NSURL URLWithString:@"mqqapi://card/show_pslcard?src_type=internal&version=1&uin=678055716&card_type=group&source=qrcode"] fallback:nil];
}


@end
