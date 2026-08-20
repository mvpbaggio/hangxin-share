// ============================================================
// XTButton (悬浮球) — 由 XingXinEnhancer_v20c.dylib 反编译还原
// 反编译时间: 2026-08-19
// 说明: 这是 dylib 里 XTButton 类的完整逻辑还原, 作为加"打卡"按钮的基础
// 打卡功能: 待加 (需要上报URL)
// ============================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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
@end
