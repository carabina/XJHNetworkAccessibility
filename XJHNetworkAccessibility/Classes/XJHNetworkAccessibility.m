//
//  XJHNetworkAccessibility.m
//  Pods-XJHNetworkAccessibility_Example
//
//  Created by xujunhao on 2018/7/25.
//

#import "XJHNetworkAccessibility.h"
#import <UIKit/UIKit.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCellularData.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <ReactiveObjC/ReactiveObjC.h>

#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>

NSString * const XJHNetworkAccessibilityChangeNotification = @"XJHNetworkAccessibilityChangeNotification";

typedef NS_ENUM(NSInteger, XJHNetworkType) {
	XJHNetworkTypeUnkown = 0,
	XJHNetworkTypeOffline,
	XJHNetworkTypeWiFi,
	XJHNetworkTypeCellularData
};

static XJHNetworkAccessibility *instance = nil;

@interface XJHNetworkAccessibility (){
	SCNetworkReachabilityRef reachabilityRef;
}

@property (nonatomic, strong) CTCellularData *cellularData;
@property (nonatomic, strong) NSMutableArray *checkingCallbackArray;
@property (nonatomic, assign) XJHNetworkAccessibilityState previousState;
@property (nonatomic, strong) UIAlertController *alertController;
@property (nonatomic, assign) BOOL automaticalAlert;
@property (nonatomic, copy) XJHNetworkAccessibilityStateNotify notifier;


@end

@implementation XJHNetworkAccessibility

#pragma mark - Public Methods

+ (void)setAlertEnable:(BOOL)enable {
	[[self sharedInstance] setAutomaticalAlert:enable];
}

+ (void)monitorAccessibilityState:(void(^)(XJHNetworkAccessibilityState))block {
	[[self sharedInstance] monitorNetworkAccessibilityStateWithCompletionBlock:block];
}

+ (void)checkAccessibilityState:(void(^)(XJHNetworkAccessibilityState))block {
	[[self sharedInstance] checkNetworkAccessibilityStateWithCompletionBlock:block];
}

+ (XJHNetworkAccessibilityState)currentState {
	return [[self sharedInstance] previousState];
}

#pragma mark - SharedInstance Methods

+ (instancetype)sharedInstance {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
	});
	return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [super allocWithZone:zone];
	});
	return instance;
}

#pragma mark - Start Notifier Method

- (BOOL)startNotifier {
	BOOL returnValue = NO;
	SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
	if (SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context))
	{
		if (SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
		{
			returnValue = YES;
		}
	}
	return returnValue;
}

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
	
	XJHNetworkAccessibility *networkAccessibity = (__bridge XJHNetworkAccessibility *)info;
	if (![networkAccessibity isKindOfClass: [XJHNetworkAccessibility class]]) {
		return;
	}
	[networkAccessibity startCheck];
}

#pragma mark - Life Cycle Method

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
	if (self = [super init]) {
		// 监听网络变化状态
		reachabilityRef = ({
			struct sockaddr_in zeroAddress;
			bzero(&zeroAddress, sizeof(zeroAddress));
			zeroAddress.sin_len = sizeof(zeroAddress);
			zeroAddress.sin_family = AF_INET;
			SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *) &zeroAddress);
		});
		// 利用 cellularDataRestrictionDidUpdateNotifier 的回调时机来进行首次检查，因为如果启动时就去检查 会得到 kCTCellularDataRestrictedStateUnknown 的结果
		@weakify(self)
		self.cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
			@strongify(self)
			dispatch_async(dispatch_get_main_queue(), ^{
				[self dispatchCellularDataState:state];
			});
		};
		[self startCheck];
		[self startNotifier];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
	}
	return self;
}

- (void)startCheck {
	if ([UIDevice currentDevice].systemVersion.floatValue < 10.0 || [self currentReachable]) {
		
		/* iOS 10 以下 不够用检测默认通过 **/
		/* 先用 currentReachable 判断，若返回的为 YES 则说明：
		 1. 用户选择了 「WALN 与蜂窝移动网」并处于其中一种网络环境下。
		 2. 用户选择了 「WALN」并处于 WALN 网络环境下。
		 
		 此时是有网络访问权限的，直接返回 XJHNetworkAccessibilityStateNormal
		 **/
		
		[self notifyWithAccessibilityState:XJHNetworkAccessibilityStateNormal];
		return;
	}
	
	[self dispatchCellularDataState:self.cellularData.restrictedState];
}

- (void)dispatchCellularDataState:(CTCellularDataRestrictedState)state {
	switch (state) {
		case  kCTCellularDataRestricted: {// 系统 API 返回 无蜂窝数据访问权限
			[self getCurrentNetworkType:^(XJHNetworkType type) {
				switch (type) {
					case XJHNetworkTypeCellularData:
					case XJHNetworkTypeWiFi: {
						[self notifyWithAccessibilityState:XJHNetworkAccessibilityStateRestricted];
					}
						break;
					default: {// 可能开了飞行模式，无法判断
						[self notifyWithAccessibilityState:XJHNetworkAccessibilityStateUnknown];
					}
						break;
				}
			}];
		}
			break;
		case kCTCellularDataNotRestricted: {// 系统 API 访问有有蜂窝数据访问权限，那就必定有 Wi-Fi 数据访问权限
			[self notifyWithAccessibilityState:XJHNetworkAccessibilityStateNormal];
		}
			break;
		case kCTCellularDataRestrictedStateUnknown: {
			[self notifyWithAccessibilityState:XJHNetworkAccessibilityStateUnknown];
		}
			break;
		default:
			break;
	}
}

#pragma mark - NSNotification

- (void)applicationDidBecomeActive {
	[self startCheck];
}

#pragma Network Related Methods

- (void)getCurrentNetworkType:(void(^)(XJHNetworkType type))block {
	if ([self isWiFiEnable]) {
		return block(XJHNetworkTypeWiFi);
	}
	
}

- (XJHNetworkType)getNetworkTypeFromStatusBar {
	NSInteger type = 0;
	UIApplication *app = [UIApplication sharedApplication];
	UIView *statusBar = [app valueForKeyPath:@"statusBar"];
	if (!statusBar) {
		return XJHNetworkTypeUnkown;
	}
	
	BOOL isModernStatusBar = [statusBar isKindOfClass:NSClassFromString(@"UIStatusBar_Modern")];
	
	if (isModernStatusBar) {// 在 iPhone X 上 statusBar 属于 UIStatusBar_Modern ，需要特殊处理
		id currentData = [statusBar valueForKeyPath:@"statusBar.currentData"];
		
		BOOL wifiEnable = [[currentData valueForKeyPath:@"_wifiEntry.isEnabled"] boolValue];
		
		// 这里不能用 _cellularEntry.isEnabled 来判断，该值即使关闭仍然有是 YES
		
		BOOL cellularEnable = [[currentData valueForKeyPath:@"_cellularEntry.type"] boolValue];
		
		return  wifiEnable ? XJHNetworkTypeWiFi : cellularEnable ? XJHNetworkTypeCellularData : XJHNetworkTypeOffline;
	} else {// 传统的 statusBar
		NSArray *children = [[statusBar valueForKeyPath:@"foregroundView"] subviews];
		for (id child in children) {
			if ([child isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
				type = [[child valueForKeyPath:@"dataNetworkType"] intValue];
				
				// type == 1  => 2G
				// type == 2  => 3G
				// type == 3  => 4G
				// type == 4  => LTE
				// type == 5  => Wi-Fi
				
			}
		}
		return type == 0 ? XJHNetworkTypeOffline :
		type == 5 ? XJHNetworkTypeWiFi : XJHNetworkTypeCellularData;
	}
	return XJHNetworkTypeUnkown;
}

/**
 判断用户是否连接到wifi
 
 @return 是否链接到wifi
 */
- (BOOL)isWiFiEnable {
	NSArray *interfaces = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
	if (!interfaces) {
		return NO;
	}
	NSDictionary *info = nil;
	for (NSString *ifnam in interfaces) {
		info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
		if (info && [info count]) { break; }
	}
	return (info != nil);
}

- (BOOL)currentReachable {
	SCNetworkReachabilityFlags flags;
	if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) {
		if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
			return NO;
		} else {
			return YES;
		}
	}
	return NO;
}

#pragma mark - Callback Method

- (void)checkNetworkAccessibilityStateWithCompletionBlock:(void(^)(XJHNetworkAccessibilityState))block {
	[self.checkingCallbackArray addObject:[block copy]];
	[self startCheck];
}

- (void)monitorNetworkAccessibilityStateWithCompletionBlock:(void(^)(XJHNetworkAccessibilityState))block {
	self.notifier = [block copy];
}

- (void)notifyWithAccessibilityState:(XJHNetworkAccessibilityState)state {
	if (_automaticalAlert) {
		if (state == XJHNetworkAccessibilityStateRestricted) {
			[self presentRestrictionAlert];
		} else {
			[self dismissRestrictionAlert];
		}
	}
	if (state != _previousState) {
		self.previousState = state;
	}
	if (_notifier) {
		_notifier(state);
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:XJHNetworkAccessibilityChangeNotification object:nil];
	for (XJHNetworkAccessibilityStateNotify notifier in self.checkingCallbackArray) {
		notifier(state);
	}
	[self.checkingCallbackArray removeAllObjects];
}

- (void)presentRestrictionAlert {
	if (self.alertController.presentingViewController == nil && ![self.alertController isBeingPresented]) {
		[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:self.alertController animated:YES completion:nil];
	}
}

- (void)dismissRestrictionAlert {
	[self.alertController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Lazy Load Method

- (NSMutableArray *)checkingCallbackArray {
	if (!_checkingCallbackArray) {
		_checkingCallbackArray = [[NSMutableArray alloc] init];
	}
	return _checkingCallbackArray;
}

- (CTCellularData *)cellularData {
	if (!_cellularData) {
		_cellularData = [[CTCellularData alloc] init];
	}
	return _cellularData;
}

- (UIAlertController *)alertController {
	if (!_alertController) {
		_alertController = [UIAlertController alertControllerWithTitle:@"网络连接失败" message:@"检测到网络权限可能未开启，您可以在“设置”中检查蜂窝移动网络" preferredStyle:UIAlertControllerStyleAlert];
		@weakify(self)
		[_alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
			@strongify(self)
			[self dismissRestrictionAlert];
		}]];
		[_alertController addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
			NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
			if([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
				[[UIApplication sharedApplication] openURL:settingsURL];
			}
		}]];
	}
	return _alertController;
}

@end
