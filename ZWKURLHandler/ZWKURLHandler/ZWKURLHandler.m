//
//  ZWKURLHandler.m
//  ZWKURLHandler


#import "ZWKURLHandler.h"
#import "ZEventStreamHandler.h"

@interface WKWebView (HandlesURLScheme)
@end

@implementation WKWebView (HandlesURLScheme)
#pragma mark 这里不返回 NO 的话, WKWebViewConfiguration 里 setURLSchemeHandler 就会崩溃
+ (BOOL)handlesURLScheme:(NSString *)urlScheme {
    return NO;
}
@end

@interface NSURLRequest(requestId)
- (NSString *)requestId;
@end

@implementation NSURLRequest(requestId)
- (NSString *)requestId {
    return [@([self hash]) stringValue];
}
@end

@interface ZWKURLHandler ()<NSURLSessionDelegate>
@property (nonatomic,strong) NSURLSession *session;
@property (nonatomic,strong) NSOperationQueue *operationQueue;
///记录urlSchemeTask是否被stop
@property (nonatomic,strong) NSMutableDictionary *holdUrlSchemeTasks;
///记录controller是否销毁,避免发起多余的请求
@property (nonatomic, assign) BOOL isControllerDealloced;
///记录当前的流handler
@property (nonatomic, weak) ZEventStreamHandler *eventStreamHandler;
@end

@implementation ZWKURLHandler

#pragma mark controller或webview销毁时调用, 不调用的话ZWKURLHandler不会销毁
- (void)removeAllActivitiesSchemeTasks {
    _isControllerDealloced = YES;
    [self.holdUrlSchemeTasks removeAllObjects];
    [self.session invalidateAndCancel];
    [self.eventStreamHandler removeAllActivitiesSchemeTasks];
}

#pragma mark - WKURLSchemeTask 处理
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask {
    if (_isControllerDealloced) {
        //过滤掉多余的请求
        return;
    }
    NSURLRequest *request = [urlSchemeTask request];
    NSURL *url = request.URL;
    NSString *httpMethod = [request.HTTPMethod uppercaseString];
    
    //流请求处理
    NSString *accept = request.allHTTPHeaderFields[@"Accept"];
    if (accept && accept.length > 0 && [accept containsString:@"text/event-stream"]) {
        [self handleStreamURLSchemeTaskWithTask:urlSchemeTask forRequest:request];
        return;
    }
    
    //所有的非get请求不用匹配本地
    if (![httpMethod containsString:@"GET"]) {
        [self handleOnlineRequst:request urlSchemeTask:urlSchemeTask];
    }else {
        BOOL checkOffline = [self handleOfflineURLSchemeTaskWithTask:urlSchemeTask forURL:url];
        if (!checkOffline) {
            //文件过大时手动切片
            NSMutableURLRequest *sliceDataRequest = [self sliceDataRequest:request];
            if (sliceDataRequest) {
                request = sliceDataRequest;
            }
            [self handleOnlineRequst:request urlSchemeTask:urlSchemeTask];
        }
    }
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask {
    NSString *key = urlSchemeTask.request.requestId;
    if ([self.holdUrlSchemeTasks objectForKey:key]) {
        [self.holdUrlSchemeTasks removeObjectForKey:key];
    }
}

#pragma mark - 流请求处理
- (void)handleStreamURLSchemeTaskWithTask:(__weak id <WKURLSchemeTask>)urlSchemeTask forRequest:(NSURLRequest *)request {
    NSString *requestId = urlSchemeTask.request.requestId;
    self.holdUrlSchemeTasks[requestId] = @1;;

    ZEventStreamHandler *handler = [[ZEventStreamHandler alloc] initWithRequest:request];
    self.eventStreamHandler = handler;
    
    __weak typeof(self) weakSelf = self;
    handler.responseHandler = ^(NSURLResponse *response) {
        [urlSchemeTask didReceiveResponse:response];
    };
    handler.dataHandler = ^(NSData *data) {
        if (!weakSelf || weakSelf.isControllerDealloced || !urlSchemeTask || ![weakSelf.holdUrlSchemeTasks objectForKey:urlSchemeTask.request.requestId]) {
            return;
        }
        @try {
            [urlSchemeTask didReceiveData:data];
        } @catch (NSException *exception) {
        }
    };
    handler.completeHandler = ^(NSError *error) {
        if (!weakSelf || weakSelf.isControllerDealloced || !urlSchemeTask || ![weakSelf.holdUrlSchemeTasks objectForKey:urlSchemeTask.request.requestId]) {
            return;
        }
        @try {
            if (error) {
                [urlSchemeTask didFailWithError:error];
            }else{
                [urlSchemeTask didFinish];
            }
        } @catch (NSException *exception) {
        }
    };
}

#pragma mark - 走本地逻辑
- (BOOL)handleOfflineURLSchemeTaskWithTask:(id <WKURLSchemeTask>)task forURL:(NSURL *)url {
    //判断本地资源
    NSData *data = [self findLocalFileDataWithUrl:url];
    //如果有本地资源
    if (data && data.length > 0) {
        NSString *fileSize = [NSString stringWithFormat:@"%lu",(unsigned long)data.length];
        NSMutableDictionary *headerFields = [NSMutableDictionary dictionaryWithDictionary:@{@"Access-Control-Allow-Origin": @"*"}];
        headerFields[@"content-type"] = [self getMimeTypeWithUrl:url];
        headerFields[@"content-length"] = fileSize;
        
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
        [task didReceiveResponse:response];
        [task didReceiveData:data];
        [task didFinish];
        return YES;
    }
    return NO;
}

- (NSData *)findLocalFileDataWithUrl:(NSURL *)url {
    NSString *filePath;
#pragma mark 测试效果: 替换掉所有图片
    if ([url.pathExtension isEqualToString:@"png"] || [url.pathExtension isEqualToString:@"jpg"]) {
        filePath = [NSBundle.mainBundle pathForResource:@"yohohho.jpg" ofType:nil];
    }

    NSData *data;
    if (filePath && filePath.length > 0) {
        data = [[NSData alloc] initWithContentsOfFile:filePath];
        if (!data || data.length == 0) {
            filePath = [filePath stringByRemovingPercentEncoding];
            data = [[NSData alloc] initWithContentsOfFile:filePath];
        }
    }
    return data;
}

- (NSString *)getMimeTypeWithUrl:(NSURL *)url {
    NSString *suffix = url.pathExtension;
    NSString *mimeType = @"text/html";

    if ([suffix isEqualToString:@"mp4"]) {
        mimeType = @"video/mp4";
    }
    if ([suffix isEqualToString:@"gif"]) {
        mimeType = @"image/gif";
    }
    
    if ([suffix isEqualToString:@"mp3"]) {
        mimeType = @"audio/x-mpeg";
    }
    
    if ([suffix isEqualToString:@"wav"]) {
        mimeType = @"audio/wav";
    }

    if ([suffix isEqualToString:@"png"]) {
        mimeType = @"image/png";
    }

    if ([suffix isEqualToString:@"jpg"]) {
        mimeType = @"image/jpeg";
    }

    if ([suffix isEqualToString:@"jpeg"]) {
        mimeType = @"image/jpeg";
    }
    
    if ([suffix isEqualToString:@"JPG"]) {
        mimeType = @"image/jpeg";
    }
    
    if ([suffix isEqualToString:@"js"]) {
        mimeType = @"application/javascript";
    }
    
    if ([suffix isEqualToString:@"css"]) {
        mimeType = @"text/css; charset=utf-8";
    }
    
    if ([suffix isEqualToString:@"html"]) {
        mimeType = @"text/html";
    }
    
    if ([suffix isEqualToString:@"svg"]) {
        mimeType = @"image/svg+xml";
    }
    
    return mimeType;
}

#pragma mark 大文件切片
- (NSMutableURLRequest * _Nullable)sliceDataRequest:(NSURLRequest *)request {
    NSString *range = [request.allHTTPHeaderFields objectForKey:@"Range"];
    if (range) {
        NSMutableURLRequest *mutaRequest = [request mutableCopy];
        NSString *rangeStr = [range stringByReplacingOccurrencesOfString:@"bytes=" withString:@""];
        NSArray *ranges = [rangeStr componentsSeparatedByString:@"-"];
        long long startPos = [ranges.firstObject longLongValue];
        long long endPos = [ranges.lastObject longLongValue];
        //这里切成 5M 一片
        if (endPos - startPos > 5 * 1024 *1024) {
            [mutaRequest setValue:[NSString stringWithFormat:@"bytes=%lld-%lld", startPos, MIN(endPos, startPos + 5 * 1024 *1024)] forHTTPHeaderField:@"Range"];
            return mutaRequest;
        }
    }
    return nil;
}

#pragma mark - 走线上逻辑
- (void)handleOnlineRequst:(NSURLRequest *)request urlSchemeTask:(__weak id <WKURLSchemeTask>)urlSchemeTask {
    //转网络请求
    NSMutableURLRequest *mutaRequest = [request mutableCopy];
    __weak typeof(self) weakSelf = self;
    NSString *requestUrlStr = request.URL.absoluteString.copy;
    
    NSURLSessionTask *task = [self.session dataTaskWithRequest:mutaRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (weakSelf.isControllerDealloced || !urlSchemeTask || ![weakSelf.holdUrlSchemeTasks objectForKey:urlSchemeTask.request.requestId]) {
            //过滤掉已经stop的网络请求
            return;
        }
        //避免 The task has already been stopped 这个断言导致的崩溃
        @try {
            if (error) {
                [urlSchemeTask didReceiveResponse:response];
                [urlSchemeTask didFailWithError:error];
            }else{
                //处理下重定向
                NSHTTPURLResponse *httpResp = [weakSelf handleRedirectUrlWithResponse:response requestUrlStr:requestUrlStr];
                [urlSchemeTask didReceiveResponse:httpResp];
                if (data) {
                    [urlSchemeTask didReceiveData:data];
                }
                [urlSchemeTask didFinish];
            }
        } @catch (NSException *exception) {
            NSLog(@"urlSchemeTask 停了停了");
        }
    }];
    
    [task resume];
    NSString *requestId = urlSchemeTask.request.requestId;
    self.holdUrlSchemeTasks[requestId] = @1;
}

#pragma mark 重定向处理
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    NSURL *url = response.URL;
    if (url.pathExtension.length == 0 || [url.pathExtension isEqualToString:@"html"]) {
        //接收到 HTML 文档的重定向时,这里返回 nil, 那么在 dataTaskWithRequest 的回调里就能收到 code = 302 的response, 然后在 webview 里对 302 做特殊处理就行
        completionHandler(nil);
    } else {
        completionHandler(request);
    }
}

- (NSHTTPURLResponse *)handleRedirectUrlWithResponse:(NSURLResponse *)response requestUrlStr:(NSString *)requestUrlStr {
    NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResp.statusCode;
    NSString *newRequestUrl = httpResp.allHeaderFields[@"Location"];
    // 302 重定向
    if (statusCode >= 300 && statusCode < 400 && newRequestUrl && requestUrlStr.length > 0) {
        NSMutableDictionary *allHeaderFields = httpResp.allHeaderFields.mutableCopy;
        //重定向的时候,将原来的 url 通过 response 传给webview
        allHeaderFields[@"redirectUrl"] = requestUrlStr;
        
        httpResp = [[NSHTTPURLResponse alloc] initWithURL:httpResp.URL statusCode:httpResp.statusCode HTTPVersion:@"HTTP/1.1" headerFields:allHeaderFields];
    }
    return httpResp;
}

#pragma mark - NSURLSession 代理
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {

    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *cred = nil;
    // 判断服务器返回的证书是否是服务器信任的
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        cred = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        if (cred) {
            disposition = NSURLSessionAuthChallengeUseCredential;
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
    }else {
        disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }
    
    if (completionHandler) {
        completionHandler(disposition, cred);
    }
}

#pragma mark - lazy
- (NSMutableDictionary *)holdUrlSchemeTasks {
    if (!_holdUrlSchemeTasks) {
        _holdUrlSchemeTasks = [NSMutableDictionary dictionary];
    }
    return _holdUrlSchemeTasks;
}

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:self.operationQueue];
    }
    return _session;
}

- (NSOperationQueue *)operationQueue {
    if (!_operationQueue) {
        _operationQueue = [[NSOperationQueue alloc]init];
        _operationQueue.maxConcurrentOperationCount = 4;
    }
    return _operationQueue;
}

- (void)dealloc {
    NSLog(@"dealloc --------- %@",NSStringFromClass(self.class));
}

@end
