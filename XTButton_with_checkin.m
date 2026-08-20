// ============================================================
// XTButton (悬浮球) — 由 XingXinEnhancer_v20c.dylib 反编译还原
// + 新增: 打卡按钮 (跳转到行信打卡页面)
// ============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

        // ---- 打卡按钮 (36x36 圆形, 悬浮球旁边) ----
        _checkinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _checkinBtn.frame = CGRectMake(0, 0, 36, 36);
        _checkinBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:0.8];
        _checkinBtn.layer.cornerRadius = 18;
        _checkinBtn.layer.shadowOpacity = 0.3;
        _checkinBtn.layer.shadowRadius = 4;
        _checkinBtn.layer.shadowOffset = CGSizeMake(0, 1);
        [_checkinBtn setTitle:@"⏰" forState:UIControlStateNormal];
        _checkinBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [_checkinBtn addTarget:self action:@selector(checkinTapped) forControlEvents:UIControlEventTouchUpInside];

        // 放在悬浮球左边
        _checkinBtn.center = CGPointMake(_btn.center.x - 46, _btn.center.y);
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
// 行信(企业微信BOC版)打卡入口, 按可靠性优先级尝试:
// 1. wxwork 深链(跳工作台, 打卡入口在工作台) / gotooldapp
// 2. 原生打卡VC (WWKAttendanceCheckViewController, 行信自研)
// 3. 官方打卡 web 页兜底
- (void)checkinTapped {
    UIApplication *app = [UIApplication sharedApplication];

    // 方式1: wxwork 深链到工作台(打卡一般在工作台/底部tab里)
    NSArray *deepLinks = @[
        @"wxworklocalnew://gotooldapp",  // 跳工作台/旧应用
        @"wxwork://",                    // 通用深链
    ];
    for (NSString *urlStr in deepLinks) {
        NSURL *u = [NSURL URLWithString:urlStr];
        if ([app canOpenURL:u]) {
            [app openURL:u options:@{} completionHandler:nil];
            NSLog(@"[COYG] checkin deepLink: %@", urlStr);
            return;
        }
    }

    // 找当前 top VC
    UIViewController *topVC = app.keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        topVC = [(UINavigationController *)topVC topViewController];
    }

    // 方式2: 原生打卡 VC (行信自研 WWKAttendanceCheckViewController)
    // 正确入口: initWithCheckType:andFromType: (逆向自脱壳二进制, 参数 0,0=默认打卡)
    // ⚠️ 之前用 [[alloc] init] 会闪退: 该类方法表里没有 init, 返回未初始化的 VC
    Class checkinClass = NSClassFromString(@"WWKAttendanceCheckViewController");
    if (checkinClass && topVC) {
        id vc = nil;
        SEL initSel = NSSelectorFromString(@"initWithCheckType:andFromType:");
        if (initSel && [checkinClass instancesRespondToSelector:initSel]) {
            IMP initImp = [checkinClass instanceMethodForSelector:initSel];
            @try {
                id raw = [checkinClass alloc];
                vc = ((id (*)(id, SEL, int, long long))initImp)(raw, initSel, 0, 0);
            } @catch (NSException *e) { vc = nil; }
        }
        if (vc) {
            // 包一层导航再 present
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
            @try {
                [topVC presentViewController:nav animated:YES completion:nil];
                NSLog(@"[COYG] checkin presented WWKAttendanceCheckViewController");
                return;
            } @catch (NSException *e) {
                NSLog(@"[COYG] checkin present fail: %@", e);
            }
        }
    }

    // 方式3: 官方打卡 web 页兜底(会在行信内置浏览器里打开)
    NSURL *attURL = [NSURL URLWithString:@"https://open.work.weixin.qq.com/wwopen/attendance/"];
    [app openURL:attURL options:@{} completionHandler:nil];
    NSLog(@"[COYG] checkin web fallback");
}
@end

// ---------- 注入启动入口 ----------
// dylib 注入后由构造函数自动拉起悬浮球 (v20c 原版同款启动方式)
__attribute__((constructor))
static void XTButtonInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        XTButton *btn = [[XTButton alloc] init];
        // init 内部已把 _btn/_checkinBtn addSubview 到 window, 这里强引用保活
        objc_setAssociatedObject(window, @"XTButtonInstance", btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[COYG] XTButton injected");
    });
}