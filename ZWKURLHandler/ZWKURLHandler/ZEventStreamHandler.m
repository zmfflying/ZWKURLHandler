//
//  ZEventStreamHandler.m
//  ZWKURLHandler
//
//  Created by QZD on 2024/4/20.
//

#import "ZEventStreamHandler.h"

@interface ZEventStreamHandler () <NSURLSessionDataDelegate>
@property (nonatomic,strong) NSURLSession *session;
@end

@implementation ZEventStreamHandler

- (void)dealloc {
    NSLog(@"dealloc --------- %@",NSStringFromClass(self.class));
}

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    }
    return _session;
}

- (instancetype)initWithRequest:(NSURLRequest *)request {
    self = [super init];
    if (self) {
        NSURLSessionDataTask *eventSourceTask = [self.session dataTaskWithRequest:request];
        [eventSourceTask resume];
    }
    return self;
}

- (void)removeAllActivitiesSchemeTasks {
    [self.session invalidateAndCancel];
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 200) {
        // Opened
        if (self.responseHandler) {
            self.responseHandler(response);
        }
    }

    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (self.dataHandler) {
        self.dataHandler(data);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    //请求完成就销毁
    [self removeAllActivitiesSchemeTasks];
    if (self.completeHandler) {
        self.completeHandler(error);
    }
}
@end
