//
//  ZWebViewController.m
//  ZWKURLHandler


#import "ZWebViewController.h"
#import "ZWKURLHandler.h"

@interface ZWebViewController ()<WKNavigationDelegate, WKUIDelegate>
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) WKWebView *webView;
///记录下urlHandler, dealloc的时候要主动调用
@property (nonatomic, weak) ZWKURLHandler *urlHandler;
///记录下重定向之前的url
@property (nonatomic, copy) NSString *redirectUrl;
@end

@implementation ZWebViewController

- (void)dealloc {
    //控制器销毁的时候,离线包的网络请求也销毁
    [self.urlHandler removeAllActivitiesSchemeTasks];
    NSLog(@"dealloc --------- %@",NSStringFromClass(self.class));
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    UIButton *leftBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [leftBtn setTitle:@"返回" forState:UIControlStateNormal];
    [leftBtn setTitleColor:UIColor.systemBlueColor forState:UIControlStateNormal];
    [leftBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    leftBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    UIBarButtonItem * leftBarItem = [[UIBarButtonItem alloc] initWithCustomView:leftBtn];
    self.navigationItem.leftBarButtonItem = leftBarItem;
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.preferences = [[WKPreferences alloc] init];
    config.preferences.minimumFontSize = 10;
    config.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    config.userContentController = [[WKUserContentController alloc] init];
    config.processPool = [[WKProcessPool alloc] init];
    config.allowsInlineMediaPlayback = YES;
    
    //iOS 13.0 13.1 13.2 13.3 这四个版本不要使用离线包, 会导致崩溃
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    if ([systemVersion compare:@"13.0"] == NSOrderedAscending || [systemVersion compare:@"13.3"] == NSOrderedDescending) {
        ZWKURLHandler *handler = [[ZWKURLHandler alloc] init];
        //直接拦截所有 http 和 https 的请求
        [config setURLSchemeHandler:handler forURLScheme:@"https"];
        [config setURLSchemeHandler:handler forURLScheme:@"http"];
        _urlHandler = handler;
    }
    
    _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    _webView.backgroundColor = UIColor.whiteColor;
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:self.urlStr] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    [_webView loadRequest:request];
    _webView.UIDelegate = self;
    _webView.navigationDelegate = self;
    [self.view addSubview:_webView];
}

- (void)backAction {
    if (self.webView.canGoBack) {
        [self.webView goBack];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - 重定向
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)navigationResponse.response;
        NSInteger statusCode = httpResp.statusCode;
        NSString *newRequestUrl = httpResp.allHeaderFields[@"Location"];
        NSString *redirectUrl = httpResp.allHeaderFields[@"redirectUrl"];
        // 302 重定向
        if (statusCode >= 300 && statusCode < 400 && redirectUrl && newRequestUrl) {
            //记录下重定向之前的url, 不要显示错误界面
            self.redirectUrl = redirectUrl;
            //这里cancel掉, 然后直接load新的url
            decisionHandler(WKNavigationResponsePolicyCancel);
            _request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:newRequestUrl] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
            [self.webView loadRequest:_request];
            return;
        }
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

//不要显示错误界面
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    //如果是重定向的url,这里 return 掉, 不要显示错误界面
    if (self.redirectUrl.length > 0 && error.userInfo && [error.userInfo objectForKey:@"NSErrorFailingURLStringKey"]) {
        NSString *failingURLString = [NSString stringWithFormat:@"%@", error.userInfo[@"NSErrorFailingURLStringKey"]];
        if ([self.redirectUrl isEqualToString:failingURLString]) {
            self.redirectUrl = nil;
            return;
        }
    }
}

//页面加载完成
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.redirectUrl = nil;
}

@end
