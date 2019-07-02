//
//  HXVersionChecking.h
//  ShengXue
//
//  Created by James on 2019/6/27.
//  Copyright © 2019 Sea. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol HXVersionCheckingCustomAlertViewDelegate <NSObject>

- (void)showInView:(UIView *)targetView;

@end


typedef void(^HXCompletionHandler)(id  _Nullable responseObject);


@interface HXVersionChecking : NSObject

//these properties must be set before startVersionChecking invoked

//id of appstore
@property (nonatomic, copy) NSString  *appID;

//default:CN
@property (nonatomic, copy) NSString  *countryCode;

//format: 2.0.4 defult:0.0.0
@property (nonatomic, copy) NSString  *minimumSupportVersion;


//default nil
@property (nonatomic, copy) NSString  *customUpgradeTipTitle;
//default nil
@property (nonatomic, copy) NSString  *customUpgradeTipNote;
//default nil
@property (nonatomic, copy) NSString  *customNewestVersion;

@property (nonatomic, strong) UIView<HXVersionCheckingCustomAlertViewDelegate>  *customAlertView;



//default:快去更新新版本吧 used when appstoreReleaseNote not correct
@property (nonatomic, copy) NSString  *standbyTipNote;
//default 更新
@property (nonatomic, copy) NSString  *upgradeBtnTitle;

//default 稍后再说
@property (nonatomic, copy) NSString  *waitOnBtnTitle;

//default 忽略
@property (nonatomic, copy) NSString  *ignoreBtnTitle;

//default 120 单位:小时
@property (nonatomic, assign) NSInteger   ignoreMaxDuration;

//showAlertByManual work only if this property yes
@property (nonatomic, assign, readonly) BOOL   InfoRequiredSuccessed;

//default yes
@property (nonatomic, assign) BOOL alertShowAuto;


//info from appstore
@property (nonatomic, copy, readonly) NSString  *appstoreVersion;
@property (nonatomic, copy, readonly) NSString  *appstoreReleaseNote;

+ (instancetype)versionManager;

- (void)startVersionChecking;

//custom alertView can use the two methods
//更新action will invoke this method
- (void)openAppPageInAppStore;

//忽略action will invoke this method
- (void)ignoreAction;


- (void)requestSpecificServerVersionInfo:(NSString *)urlStr
                              HTTPMethod:(NSString *)HTTPMethod
                              parameters:(id  _Nullable)parameters
                 HTTPHeaderFieldValueDic:(NSDictionary  * _Nullable)headerFieldValueDic
                       completionHandler:(HXCompletionHandler)completionHandler;

- (void)showAlertByManual;
@end

NS_ASSUME_NONNULL_END
