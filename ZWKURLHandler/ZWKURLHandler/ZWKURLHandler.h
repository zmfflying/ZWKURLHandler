//
//  ZWKURLHandler.h
//  ZWKURLHandler


#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZWKURLHandler : NSObject <WKURLSchemeHandler>
//controller或webview销毁时调用, 不调用的话ZWKURLHandler不会销毁
- (void)removeAllActivitiesSchemeTasks;
@end

NS_ASSUME_NONNULL_END
