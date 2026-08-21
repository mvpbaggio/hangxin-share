// ============================================================
// XTButton (悬浮球) — 由 XingXinEnhancer_v20c.dylib 反编译还原
// + 新增: 打卡按钮 (跳转到行信打卡页面)
// ============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

// ---------- PBCapture (剪贴板历史) ----------
@interface PBCapture : NSObject
@property (nonatomic, strong) NSMutableArray *entries;
- (NSString *)latestText;
@end

@implementation PBCapture
- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = [NSMutableArray array];
        [[NSNotificationCenter defaultCenter]
            addObserver:self selector:@selector(pbChanged:)
            name:UIPasteboardChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter]
            addObserver:self selector:@selector(willEnterBg:)
            name:UIApplicationDidEnterBackgroundNotification object:nil];
        NSLog(@"[COYG] loaded: %@", self);
    }
    return self;
}

- (void)pbChanged:(NSNotification *)note {
    NSString *text = [UIPasteboard generalPasteboard].string;
    if (text.length) {
        [_entries addObject:text];
        NSLog(@"[COYG] pb: %@", text);
    }
}

- (void)willEnterBg:(NSNotification *)note {
    NSLog(@"[COYG] restored pb on bg");
}

- (NSString *)latestText {
    return [_entries lastObject];
}
@end

// ---------- XTButton (可拖动悬浮球 + 打卡) ----------
@interface XTButton : UIButton
@end

@implementation XTButton {
    UIButton *_btn;       // 悬浮球本体
    UIButton *_checkinBtn; // 打卡按钮
    WKWebView *_webView;   // 打卡内嵌网页
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // ---- 悬浮球按钮 (56x56 圆形) ----
        _btn = [UIButton buttonWithType:UIButtonTypeCustom];
        _btn.frame = CGRectMake(0, 0, 56, 56);
        _btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:0.8];
        _btn.layer.cornerRadius = 28;
        _btn.layer.shadowOpacity = 0.4;
        _btn.layer.shadowRadius = 6;
        _btn.layer.shadowOffset = CGSizeMake(0, 2);
        [_btn setTitle:@"⏻" forState:UIControlStateNormal];
        _btn.titleLabel.font = [UIFont boldSystemFontOfSize:24];

        // 拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(drag:)];
        [_btn addGestureRecognizer:pan];

        // 点击 → 导出文件（原功能）
        [_btn addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];

        // 放到窗口
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        _btn.center = CGPointMake(screenW - 40, 200);
        [window addSubview:_btn];

        // ---- 打卡按钮 (40x40 圆形, 悬浮球旁边) ----
        _checkinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _checkinBtn.frame = CGRectMake(0, 0, 40, 40);
        _checkinBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:0.95];
        _checkinBtn.layer.cornerRadius = 20;
        _checkinBtn.layer.borderWidth = 2.0;
        _checkinBtn.layer.borderColor = [UIColor whiteColor].CGColor;
        _checkinBtn.layer.shadowOpacity = 0.3;
        _checkinBtn.layer.shadowRadius = 4;
        _checkinBtn.layer.shadowOffset = CGSizeMake(0, 1);
        // ⚠️ 不用 emoji 图标(行信渲染空白), 用纯文字
        [_checkinBtn setTitle:@"卡" forState:UIControlStateNormal];
        _checkinBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [_checkinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_checkinBtn addTarget:self action:@selector(checkinTapped) forControlEvents:UIControlEventTouchUpInside];

        // 放在悬浮球左边
        _checkinBtn.center = CGPointMake(_btn.center.x - 50, _btn.center.y);
        [window addSubview:_checkinBtn];
    }
    return self;
}

// 拖动悬浮球（打卡按钮跟随）
- (void)drag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint center = self.center;
    center.x += translation.x;
    center.y += translation.y;
    self.center = center;
    _checkinBtn.center = CGPointMake(center.x - 46, center.y);
    [gesture setTranslation:CGPointMake(0, 0) inView:self.superview];
}

// 点击悬浮球 → 导出文件（原功能不变）
- (void)tapped {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *profilesDir = [docDir stringByAppendingPathComponent:@"Profiles"];
        NSArray *files = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:profilesDir error:nil];
        NSString *newest = nil;
        NSDate *newestDate = nil;
        for (NSString *f in files) {
            NSString *path = [profilesDir stringByAppendingPathComponent:f];
            NSDictionary *attrs = [[NSFileManager defaultManager]
                attributesOfItemAtPath:path error:nil];
            NSDate *date = attrs[NSFileModificationDate];
            if (!newestDate || [date compare:newestDate] == NSOrderedDescending) {
                newestDate = date;
                newest = path;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (newest) {
                [self exportFile:newest];
            } else {
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"提示"
                    message:@"未找到文件" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [[UIApplication sharedApplication].keyWindow.rootViewController
                    presentViewController:alert animated:YES completion:nil];
            }
        });
    });
}

// 导出文件
- (void)exportFile:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *vc = [[UIActivityViewController alloc]
        initWithActivityItems:@[url] applicationActivities:nil];
    [[UIApplication sharedApplication].keyWindow.rootViewController
        presentViewController:vc animated:YES completion:nil];
}

// ---- 打卡按钮点击 ----
// 打卡位置(超哥指定): 粤.统一门户 → 考勤与请休假
// ⚠️ 不能 openURL(会跳系统Safari,无认证态→失效),必须行信进程内 WKWebView 打开
// WKWebView 在行信进程内, 共享 cookie 会话 → 等同工作台图标点击
- (void)checkinTapped {
    NSString *urlStr = @"https://gd.brcloud.bankofchina.com/gdhx/uweb/ext/html/MB_UWeb/index.html";
    
    UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    
    // 行信进程内 WKWebView (带 cookie 会话)
    WKWebView *webView = [[WKWebView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    webView.backgroundColor = [UIColor whiteColor];
    
    // 顶部工具条: 关闭 + 刷新
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 64)];
    bar.backgroundColor = [UIColor whiteColor];
    bar.layer.shadowOpacity = 0.2;
    bar.layer.shadowRadius = 2;
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(10, 24, 60, 32);
    [closeBtn setTitle:@"✕ 关闭" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissWebView) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:closeBtn];
    
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 70, 24, 60, 32);
    [refreshBtn setTitle:@"↻ 刷新" forState:UIControlStateNormal];
    [refreshBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [refreshBtn addTarget:self action:@selector(refreshWebView) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:refreshBtn];
    
    // webView 放在工具条下方
    CGRect frame = [UIScreen mainScreen].bounds;
    frame.origin.y = 64;
    frame.size.height -= 64;
    webView.frame = frame;
    
    UIViewController *webVC = [[UIViewController alloc] init];
    webVC.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [webVC.view addSubview:bar];
    [webVC.view addSubview:webView];
    self->_webView = webView;
    
    [top presentViewController:webVC animated:YES completion:nil];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]]];
    NSLog(@"[COYG] checkin -> WKWebView: %@", urlStr);
}

// 关闭内嵌 WKWebView
- (void)dismissWebView {
    UIViewController *top = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    [top dismissViewControllerAnimated:YES completion:nil];
}

// 刷新内嵌 WKWebView
- (void)refreshWebView {
    [self->_webView reload];
}
@end

// ---------- 注入启动入口 ----------
// 还原 v20c 原版启动逻辑：环境判断 → 创建 PBCapture（剪贴板历史）→ 创建 XTButton（悬浮球）
static PBCapture *g_pbCapture = nil;
static XTButton *g_xtButton = nil;

__attribute__((constructor))
static void XTButtonInit(void) {
    // 环境判断（同 v20c 原版）：仅行信/企微 BOC 版生效
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (bid.length &&
        ![bid containsString:@"BOCWECHAT"] &&
        ![bid containsString:@"wework"] &&
        ![bid containsString:@"AFC"]) {
        NSLog(@"[COYG] skip, bid=%@", bid);
        return;
    }

    // 创建剪贴板历史（PBCapture），全局保活 —— v20c 原功能
    g_pbCapture = [[PBCapture alloc] init];

    // 等 window 就绪后创建悬浮球（带一次重试）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_xtButton) return;
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (g_xtButton) return;
                UIWindow *w2 = [UIApplication sharedApplication].keyWindow;
                if (!w2) return;
                g_xtButton = [[XTButton alloc] init];
                NSLog(@"[COYG] XTButton injected (retry)");
            });
            return;
        }
        g_xtButton = [[XTButton alloc] init];
        NSLog(@"[COYG] XTButton injected");
    });
}