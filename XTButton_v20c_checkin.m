// ============================================================
// XTButton (悬浮球) — 由 XingXinEnhancer_v20c.dylib 反编译还原
// 反编译时间: 2026-08-19
// 说明: 这是 dylib 里 XTButton 类的完整逻辑还原, 作为加"打卡"按钮的基础
// 打卡功能: 待加 (需要上报URL)
// ============================================================
// ============================================================
// 2026-08-21 超哥拍板: 以本文件(原版)为基底加打卡, 原版逻辑一字不动
// 新增: ① 启动段(+load, 兼容全iOS) ② 打卡按钮(悬浮球左边绿色"卡"钮)
// ============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

// ---------- PBCapture (剪贴板历史) ----------
@interface PBCapture : NSObject
@property (nonatomic, strong) NSMutableArray *entries; // 剪贴板历史条目
- (NSString *)latestText;
@end

@implementation PBCapture
- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = [NSMutableArray array];
        // 注册剪贴板变化通知
        [[NSNotificationCenter defaultCenter]
            addObserver:self selector:@selector(pbChanged:)
            name:UIPasteboardChangedNotification object:nil];
        // 注册进后台通知
        [[NSNotificationCenter defaultCenter]
            addObserver:self selector:@selector(willEnterBg:)
            name:UIApplicationDidEnterBackgroundNotification object:nil];
        NSLog(@"[COYG] loaded: %@", self);
    }
    return self;
}

// 剪贴板变化时记录
- (void)pbChanged:(NSNotification *)note {
    NSString *text = [UIPasteboard generalPasteboard].string;
    if (text.length) {
        [_entries addObject:text];
        NSLog(@"[COYG] pb: %@", text);
    }
}

// 进后台时保存历史到文件
- (void)willEnterBg:(NSNotification *)note {
    // 序列化 entries 到 Documents
    NSLog(@"[COYG] restored pb on bg");
}

- (NSString *)latestText {
    return [_entries lastObject];
}
@end

// ---------- XTButton (可拖动悬浮球) ----------
@interface XTButton : UIButton
@end

@implementation XTButton {
    UIButton *_btn; // 悬浮球本体
    UIButton *_checkinBtn; // 打卡按钮 (新增)
}

// 悬浮球初始化: 创建圆角半透明按钮, 加拖动手势 + 点击
- (instancetype)init {
    self = [super init];
    if (self) {
        // 创建悬浮球按钮 (56x56 圆形, 半透明)
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

        // 点击
        [_btn addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];

        // 放到窗口
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        _btn.center = CGPointMake(screenW - 40, 200);
        [window addSubview:_btn];

        // ========== 新增: 打卡按钮 (纯文字"卡", 悬浮球左边 50pt) ==========
        _checkinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _checkinBtn.frame = CGRectMake(0, 0, 40, 40);
        _checkinBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:0.95];
        _checkinBtn.layer.cornerRadius = 20;
        _checkinBtn.layer.borderWidth = 2;
        _checkinBtn.layer.borderColor = [UIColor whiteColor].CGColor;
        _checkinBtn.layer.shadowOpacity = 0.4;
        _checkinBtn.layer.shadowRadius = 4;
        _checkinBtn.layer.shadowOffset = CGSizeMake(0, 2);
        [_checkinBtn setTitle:@"卡" forState:UIControlStateNormal];
        [_checkinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _checkinBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        _checkinBtn.center = CGPointMake(_btn.center.x - 50, _btn.center.y);
        [_checkinBtn addTarget:self action:@selector(checkinTapped) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:_checkinBtn];
        // ========== 新增结束 ==========
    }
    return self;
}

// 拖动悬浮球
- (void)drag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint center = self.center;
    center.x += translation.x;
    center.y += translation.y;
    self.center = center;
    [gesture setTranslation:CGPointZero inView:self.superview];
}

// 点击悬浮球 → 后台线程找 Documents/Profiles 最新文件 → 弹分享
- (void)tapped {
    // 后台线程处理, 避免卡UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 找 Documents/Profiles 里访问时间最新的文件
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
        // 回主线程弹分享
        dispatch_async(dispatch_get_main_queue(), ^{
            if (newest) {
                [self exportFile:newest];
            } else {
                // 找不到文件提示
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

// 导出文件 → 系统分享
- (void)exportFile:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *vc = [[UIActivityViewController alloc]
        initWithActivityItems:@[url] applicationActivities:nil];
    [[UIApplication sharedApplication].keyWindow.rootViewController
        presentViewController:vc animated:YES completion:nil];
}

// ========== 新增: 打卡入口 (行信进程内 WKWebView 打开考勤页, 带 cookie 会话) ==========
static const void *kCheckinWebKey = &kCheckinWebKey;

- (void)checkinTapped {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;

    WKWebView *web = [[WKWebView alloc] initWithFrame:topVC.view.bounds];
    web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view = [[UIView alloc] initWithFrame:topVC.view.bounds];
    [vc.view addSubview:web];

    // 顶部工具栏: 关闭 + 刷新
    UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, vc.view.bounds.size.width, 44)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithTitle:@"✕ 关闭" style:UIBarButtonItemStylePlain
        target:self action:@selector(checkinClose)];
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithTitle:@"↻ 刷新" style:UIBarButtonItemStylePlain
        target:self action:@selector(checkinRefresh:)];
    refresh.tag = 8281;
    bar.items = @[close, spacer, refresh];
    [vc.view addSubview:bar];
    web.frame = CGRectMake(0, 44, vc.view.bounds.size.width, vc.view.bounds.size.height - 44);

    NSURL *url = [NSURL URLWithString:@"https://gd.brcloud.bankofchina.com/gdhx/uweb/ext/html/MB_UWeb/index.html"];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    [web loadRequest:req];

    [topVC presentViewController:vc animated:YES completion:nil];
    objc_setAssociatedObject(vc, kCheckinWebKey, web, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)checkinClose {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    if (topVC.presentingViewController) {
        [topVC dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)checkinRefresh:(UIBarButtonItem *)sender {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    WKWebView *web = objc_getAssociatedObject(topVC, kCheckinWebKey);
    if (web) [web reload];
}
// ========== 新增结束 ==========

@end

// ========== 新增: 启动段 (dylib 加载必执行, 兼容所有 iOS) ==========
static PBCapture *g_pbCapture = nil;
static XTButton *g_xtButton = nil;

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

    // 还原原版: 监听 App 激活时建球 + 延迟兜底重试
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (g_xtButton) return;
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        g_xtButton = [[XTButton alloc] init];
        NSLog(@"[COYG] XTButton injected (active)");
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_xtButton) return;
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        g_xtButton = [[XTButton alloc] init];
        NSLog(@"[COYG] XTButton injected (delay1)");
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_xtButton) return;
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        g_xtButton = [[XTButton alloc] init];
        NSLog(@"[COYG] XTButton injected (delay3)");
    });
}

// 用 +load 启动（dylib 加载时 ObjC runtime 必然调用, 全 iOS 兼容）
@interface XTLoader : NSObject @end
@implementation XTLoader
+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        XTButtonInit();
    });
}
@end
// ========== 新增结束 ==========
