//
//  XJHNetworkAccessibility.h
//  Pods-XJHNetworkAccessibility_Example
//
//  Created by xujunhao on 2018/7/25.
//

#import <Foundation/Foundation.h>

extern NSString * const XJHNetworkAccessibilityChangeNotification;

typedef NS_ENUM(NSUInteger, XJHNetworkAccessibilityState) {
	XJHNetworkAccessibilityStateUnknown = 0,
	XJHNetworkAccessibilityStateNormal,
	XJHNetworkAccessibilityStateRestricted
};

typedef void(^XJHNetworkAccessibilityStateNotify)(XJHNetworkAccessibilityState state);


@interface XJHNetworkAccessibility : NSObject

/**
 是否弹框提示用户开启网络数据权限

 @param enable 是否开启
 */
+ (void)setAlertEnable:(BOOL)enable;

/**
 监测网络数据授权变化

 @param block 授权变化回调
 */
+ (void)monitorAccessibilityState:(void(^)(XJHNetworkAccessibilityState))block;

/**
 检查网络数据授权状态

 @param block 授权状态回调
 */
+ (void)checkAccessibilityState:(void(^)(XJHNetworkAccessibilityState))block;


/**
 当前网络数据授权状态

 @return 返回的额是最近一次的网络数据授权状态的检查结果，若距离上一次检测结果短时间内网络数据授权状态发生变化，改之可能不会准确，
 若想获取更为精确的结果，请调用checkAccessibilityState:方法
 */
+ (XJHNetworkAccessibilityState)currentState;


@end
