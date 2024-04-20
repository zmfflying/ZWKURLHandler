//
//  ZEventStreamHandler.h
//  ZWKURLHandler
//
//  Created by QZD on 2024/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^EventStreamResponseHandler)(NSURLResponse *response);
typedef void (^EventStreamDataHandler)(NSData *data);
typedef void (^EventStreamCompleteHandler)(NSError *error);

@interface ZEventStreamHandler : NSObject
@property (nonatomic, copy) EventStreamResponseHandler responseHandler;
@property (nonatomic, copy) EventStreamDataHandler dataHandler;
@property (nonatomic, copy) EventStreamCompleteHandler completeHandler;

- (instancetype)initWithRequest:(NSURLRequest *)request;
- (void)removeAllActivitiesSchemeTasks;
@end

NS_ASSUME_NONNULL_END
