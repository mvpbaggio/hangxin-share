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
// 打卡位置(超哥指定): 工作台 → 粤.统一门户 → 考勤与请休假
// 「粤.统一门户」是工作台内的应用(appid 由服务端下发, 客户端无直达深链),
// 故点击后跳转行信工作台 tab, 由用户点入打卡。
// ⚠️ 不跳原生 WWKAttendanceCheckViewController / 企微官方考勤页: 都不是打卡位置
- (void)checkinTapped {
    UIApplication *app = [UIApplication sharedApplication];

    // 跳工作台 tab (行信唯一工作台深链入口)
    NSURL *u = [NSURL URLWithString:@"wxworklocalnew://gotooldapp"];
    if ([app canOpenURL:u]) {
        [app openURL:u options:@{} completionHandler:nil];
        NSLog(@"[COYG] checkin -> 工作台");
    } else {
        // 深链不可用时提示手动路径
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"提示"
            message:@"请在工作台 → 粤.统一门户 → 考勤与请休假 打卡"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController
            presentViewController:alert animated:YES completion:nil];
        NSLog(@"[COYG] checkin deepLink unavailable, alert");
    }
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