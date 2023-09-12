//
//  ViewController.m


#import "ViewController.h"
#import "ZWebViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    UIButton *normalUrlBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 200, UIScreen.mainScreen.bounds.size.width, 40)];
    [normalUrlBtn setTitle:@"打开普通网页" forState:UIControlStateNormal];
    [normalUrlBtn setTitleColor:UIColor.systemBlueColor forState:UIControlStateNormal];
    [normalUrlBtn addTarget:self action:@selector(openNormalWebView) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:normalUrlBtn];
}

- (void)openNormalWebView {
    ZWebViewController *webVc = ZWebViewController.new;
    webVc.urlStr = @"http://www.baidu.com";
    [self.navigationController pushViewController:webVc animated:YES];
}
@end
