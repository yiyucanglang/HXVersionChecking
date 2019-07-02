//
//  HXVersionChecking.m
//  ShengXue
//
//  Created by James on 2019/6/27.
//  Copyright © 2019 Sea. All rights reserved.
//

#import "HXVersionChecking.h"
#import <AFNetworking/AFNetworking.h>

#if 0

#define DHXLog(...) NSLog(@"%@",[NSString stringWithFormat:__VA_ARGS__])
#else
#define DHXLog(...)

#endif

static NSString *const HXAppLookupURLFormat = @"https://itunes.apple.com/%@/lookup?id=%@";

static NSString *const HXiOSAppStoreURLFormat = @"itms-apps://itunes.apple.com/app/id%@";

static NSString *const HXIgnoreActionInfoCacheKey = @"HXIgnoreActionInfoCacheKey";

#define kHXVersion     @"version"
#define kHXDate        @"date"
#define kHXDuration    @"duration"

@interface HXVersionChecking()

@property (nonatomic, assign) BOOL   openVersionCheckFlag;

@property (nonatomic, assign) BOOL   infoRequesting;

@property (nonatomic, strong) AFHTTPSessionManager  *sessionManager;
@property (nonatomic, strong) AFNetworkReachabilityManager  *netStatusManager;


@property (nonatomic, copy) NSString  *appstoreVersion;
@property (nonatomic, copy) NSString  *appstoreReleaseNote;

@property (nonatomic, assign) BOOL     appStoreInfoRequestFinished;
@property (nonatomic, assign) BOOL  forceUpgrade;

@property (nonatomic, assign) BOOL  appstoreVersionNewestFlag;
@property (nonatomic, assign) BOOL  alertShowingFlag;

@property (nonatomic, strong) UIAlertController  *alertController;

@property (nonatomic, copy) NSURLRequest  *specificRequest;
@property (nonatomic, assign) BOOL   specificRequestLoading;
@property (nonatomic, copy) HXCompletionHandler   specificHandler;
@property (nonatomic, strong) UIWindow  *containerWindow;
@property (nonatomic, strong) NSTimer   *customTimer;

@end

@implementation HXVersionChecking
#pragma mark - Life Cycle
+ (instancetype)versionManager {
    
    static HXVersionChecking *manage;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manage = [[HXVersionChecking alloc] init];
        manage.standbyTipNote      = @"快去更新新版本吧";
        manage.ignoreMaxDuration   = 120;
        manage.alertShowAuto       = YES;
        [manage.netStatusManager startMonitoring];
        [manage.netStatusManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            if (status == AFNetworkReachabilityStatusReachableViaWWAN || status == AFNetworkReachabilityStatusReachableViaWiFi) {
                if (manage.openVersionCheckFlag) {
                    [manage  _requestFromAppstore];
                }
                [manage _requestSpecificServer:manage.specificRequest completionHandler:manage.specificHandler];
            }
        }];
        [[NSNotificationCenter defaultCenter] addObserver:manage selector:@selector(_applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    });
    
    return manage;
}

#pragma mark - System Method

#pragma mark - Public Method
- (void)startVersionChecking {
    NSAssert(self.appID.length, @"please set appID");
    if (!self.appID) {
        return;
    }
    self.openVersionCheckFlag = YES;
    [self checkNeedForceUpgrade];
    
    if(self.customNewestVersion) {
        self.appStoreInfoRequestFinished = YES;
        [self checkNeedShowAlert];
    }
    else {
        [self _requestFromAppstore];
    }
}

- (void)openAppPageInAppStore {
    NSURL *appURL = [NSURL URLWithString:[NSString stringWithFormat:HXiOSAppStoreURLFormat, self.appID]];
    [[UIApplication sharedApplication] openURL:appURL];
}

- (void)ignoreAction {
    [self _saveIgnoreActionInfo];
}

- (void)requestSpecificServerVersionInfo:(NSString *)urlStr HTTPMethod:(NSString *)HTTPMethod parameters:(id)parameters HTTPHeaderFieldValueDic:(NSDictionary *)headerFieldValueDic completionHandler:(void (^)(id _Nullable))completionHandler {
    
    AFJSONRequestSerializer *serializer =  [AFJSONRequestSerializer serializer];
    for (NSString *key in headerFieldValueDic.allKeys) {
        [serializer setValue:headerFieldValueDic[key] forHTTPHeaderField:key];
    }
    NSMutableURLRequest *request = [serializer requestWithMethod:HTTPMethod URLString:urlStr parameters:parameters error:nil];
    
    serializer.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    self.specificRequest = request;
    [self _requestSpecificServer:request completionHandler:completionHandler];
    
}

- (void)showAlertByManual {
    if (self.appStoreInfoRequestFinished) {
        [self checkNeedShowAlert];
    }
}

#pragma mark - Override

#pragma mark - Private Method
- (void)_requestFromAppstore {
    
    if (self.appStoreInfoRequestFinished || self.infoRequesting) {
        return;
    }
    self.infoRequesting = YES;
    [self.sessionManager GET:[NSString stringWithFormat:HXAppLookupURLFormat, self.countryCode, self.appID] parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        self.infoRequesting = NO;
        
        self.appStoreInfoRequestFinished = YES;
        self.appstoreReleaseNote = [[[responseObject objectForKey:@"results"] lastObject] objectForKey:@"releaseNotes"];
        self.appstoreVersion = [[[responseObject objectForKey:@"results"] lastObject] objectForKey:@"version"];
        [self checkAppstoreVersionNewest];
        [self checkNeedShowAlert];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        self.infoRequesting = NO;
        
        if (error.code != -1009) {//非无网路
            [self _requestFromAppstore];
        }
        
    }];
}

- (void)_requestSpecificServer:(NSURLRequest *)request
             completionHandler:(HXCompletionHandler)completionHandler {
    
    if (!request || self.specificRequestLoading) {
        return;
    }
    self.specificRequestLoading = YES;
    
    NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        
        self.specificRequestLoading = NO;
        
        if(error) {
            if (error.code != -1009) {//非无网路
                [self _requestSpecificServer:request completionHandler:completionHandler];
            }
        }
        else {
            self.specificRequest = nil;
            self.specificHandler = nil;
            completionHandler(responseObject);
        }
    }];
    
    [dataTask resume];
}

- (void)_applicationWillEnterForeground {
    [self _requestFromAppstore];
    if (self.forceUpgrade) {
        [self showAlert];
    }
}

- (void)checkNeedForceUpgrade {
    NSComparisonResult result = [self.minimumSupportVersion compare:self.currentVersion options:NSNumericSearch];
    if (result == NSOrderedDescending) {
        self.forceUpgrade = YES;
    }
}

- (void)checkAppstoreVersionNewest {
    NSComparisonResult result = [self.minimumSupportVersion compare:self.appstoreVersion options:NSNumericSearch];
    if (result == NSOrderedDescending) {
        self.appstoreVersionNewestFlag = NO;
    }
    else {
        self.appstoreVersionNewestFlag = YES;
    }
}

- (void)checkNeedShowAlert {
    
    if (self.forceUpgrade) {
        [self showAlert];
        return;
    }
    
    NSMutableDictionary *cacheDic = [[NSUserDefaults standardUserDefaults] objectForKey:HXIgnoreActionInfoCacheKey];
    BOOL needShow = YES;
    if (cacheDic) {
        NSString *savedVersion = [cacheDic objectForKey:kHXVersion];
        if ([savedVersion isEqualToString:[self currentVersion]]) {
            
            NSTimeInterval duration = [[cacheDic objectForKey:kHXDuration] integerValue] * 60 * 60;
            
            NSDate *savedDate   = [cacheDic objectForKey:kHXDate];
            NSDate *currentDate = [NSDate date];
            
            NSTimeInterval actionDuration = [currentDate timeIntervalSinceDate:savedDate];
            
            if (actionDuration < duration) {
                needShow = NO;
            }
        }
        else {
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:HXIgnoreActionInfoCacheKey];
        }
    }
    if (needShow) {
        [self showAlert];
    }
    
}

- (void)showAlert {
    
    if (!self.alertShowAuto) {
        return;
    }
    
    
    if (self.containerWindow) {
        return;
    }
    
    self.containerWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.containerWindow.rootViewController = [[UIViewController alloc] init];
    self.containerWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
    self.containerWindow.rootViewController.view.userInteractionEnabled = NO;
    self.containerWindow.windowLevel = UIWindowLevelStatusBar + 100;
    self.containerWindow.hidden = NO;
    self.containerWindow.alpha = 1;
    
    if (self.customAlertView) {
        [self _startTimer];
        [self.customAlertView showInView:self.containerWindow];
        return;
    }
    
    
    NSString *title   = self.customUpgradeTipTitle?: (self.customNewestVersion?:self.appstoreVersion);
    NSString *message = self.customUpgradeTipNote ?: (self.appstoreVersionNewestFlag ? self.appstoreReleaseNote : self.standbyTipNote);
    
    self.alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [self.alertController addAction:[UIAlertAction actionWithTitle:self.upgradeBtnTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        
        [self openAppPageInAppStore];
        self.containerWindow.hidden = YES;
        self.containerWindow = nil;
    }]];
    
    if (!self.forceUpgrade) {
        [self.alertController addAction:[UIAlertAction actionWithTitle:self.ignoreBtnTitle style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
            [self _saveIgnoreActionInfo];
            
            self.containerWindow.hidden = YES;
            self.containerWindow = nil;
        }]];
        
        [self.alertController addAction:[UIAlertAction actionWithTitle:self.waitOnBtnTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            
            self.containerWindow.hidden = YES;
            self.containerWindow = nil;
        }]];
    }
    
    
    [self.containerWindow.rootViewController presentViewController:self.alertController animated:NO completion:NULL];
}

- (void)_saveIgnoreActionInfo {
    
    if (!self.appStoreInfoRequestFinished) {
        return;
    }
    
    NSMutableDictionary *saveDic = [NSMutableDictionary dictionary];
    NSString *saveVersion    = self.currentVersion;
    [saveDic setObject:saveVersion forKey:kHXVersion];
    
    NSNumber *ignoreDuration = @(self.ignoreMaxDuration);
    [saveDic setObject:ignoreDuration forKey:kHXDuration];
    
    NSDate *saveDate         = [NSDate date];
    [saveDic setObject:saveDate forKey:kHXDate];
    
    
    [[NSUserDefaults standardUserDefaults] setObject:saveDic forKey:HXIgnoreActionInfoCacheKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_startTimer {
    [self _stopTimer];
    self.customTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(_checkCustomAlertDismiss) userInfo:nil repeats:YES];
}

- (void)_stopTimer {
    [self.customTimer invalidate];
    self.customTimer = nil;
}

- (void)_checkCustomAlertDismiss {
    if (![self.containerWindow.subviews containsObject:self.customAlertView]) {//dismiss
        self.containerWindow.hidden = YES;
        self.containerWindow = nil;
        [self _stopTimer];
    }
}

#pragma mark - Delegate

#pragma mark - Setter And Getter
- (AFHTTPSessionManager *)sessionManager {
    if (!_sessionManager) {
        _sessionManager = [[AFHTTPSessionManager alloc] init];
        _sessionManager.session.configuration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    }
    return _sessionManager;
}

- (AFNetworkReachabilityManager *)netStatusManager {
    if (!_netStatusManager) {
        _netStatusManager = [AFNetworkReachabilityManager manager];
    }
    return _netStatusManager;
}

- (NSString *)upgradeBtnTitle {
    if (!_upgradeBtnTitle) {
        _upgradeBtnTitle = @"更新";
    }
    return _upgradeBtnTitle;
}

- (NSString *)waitOnBtnTitle {
    if (!_waitOnBtnTitle) {
        _waitOnBtnTitle = @"稍后再说";
    }
    return _waitOnBtnTitle;
}

- (NSString *)ignoreBtnTitle {
    if (!_ignoreBtnTitle) {
        _ignoreBtnTitle = @"忽略";
    }
    return _ignoreBtnTitle;
}


- (NSString *)currentVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)countryCode {
    if (!_countryCode) {
        _countryCode = @"CN";
    }
    return _countryCode;
}

- (BOOL)InfoRequiredSuccessed {
    if (self.appStoreInfoRequestFinished || self.customNewestVersion) {
        return YES;
    }
    return NO;
}


#pragma mark - Dealloc
@end
