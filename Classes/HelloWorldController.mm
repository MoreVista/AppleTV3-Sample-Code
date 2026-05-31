/*
 * HelloWorldController.mm
 *
 * Apple TV 2/3 向け画面コントローラ
 *
 * BRController (AppleTV.app 内蔵の非公開クラス) を動的にサブクラス化し、
 * controlWasActivated で UILabel を配置する。
 * KodiController.mm (xbmc/xbmc 14.2-Helix) と同じランタイムフック手法を使用。
 *
 * Apple TV 2/3 の解像度: 1280 × 720 (720p)
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>
#include "substrate.h"

// ──────────────────────────────────────────────────────────────────────────────
// BRWindow クラスの参照キャッシュ
// ──────────────────────────────────────────────────────────────────────────────
static Class BRWindowCls;

// ──────────────────────────────────────────────────────────────────────────────
// オリジナルメソッドポインタ (MSHookMessageEx の第4引数で取得)
// ──────────────────────────────────────────────────────────────────────────────
static IMP HelloController$controlWasActivated$Orig;
static BOOL (*HelloController$brEventAction$Orig)(id, SEL, id);

// ──────────────────────────────────────────────────────────────────────────────
// メソッド実装
// ──────────────────────────────────────────────────────────────────────────────

/*
 * init
 */
static id HelloController$init(id self, SEL _cmd) {
    Class base = class_getSuperclass(object_getClass(self));
    IMP superInit = class_getMethodImplementation(base, _cmd);
    self = ((id (*)(id, SEL))superInit)(self, _cmd);
    return self;
}

/*
 * controlWasActivated
 * 画面が表示されたタイミングで呼ばれる。
 * BRWindow の rootView に UILabel を追加する。
 */
static void HelloController$controlWasActivated(id self, SEL _cmd) {
    // スーパークラスを先に呼ぶ (KodiController.mm と同パターン)
    if (HelloController$controlWasActivated$Orig) {
        ((void (*)(id, SEL))HelloController$controlWasActivated$Orig)(self, _cmd);
    }

    // BRWindow から UIView を取得
    UIView *rootView = nil;
    if (BRWindowCls) {
        id brWindow = [BRWindowCls performSelector:@selector(sharedWindow)];
        if ([brWindow respondsToSelector:@selector(rootView)]) {
            rootView = [brWindow performSelector:@selector(rootView)];
        }
    }

    // rootView が取れない場合は keyWindow にフォールバック
    if (!rootView) {
        rootView = [[UIApplication sharedApplication] keyWindow];
    }
    if (!rootView) return;

    // 背景
    rootView.backgroundColor = [UIColor blackColor];

    // "Hello, World!" メインラベル (縦中央より少し上)
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 220, 1280, 140)];
    label.text            = @"Hello, World!";
    label.textColor       = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.font            = [UIFont boldSystemFontOfSize:96.0f];
    label.textAlignment   = UITextAlignmentCenter; // iOS 4.x: UITextAlignmentCenter (NSTextAlignmentCenter は iOS 6+)
    label.numberOfLines   = 1;
    label.tag             = 9001; // 重複追加防止用タグ
    [rootView addSubview:label];
    [label release];

    // サブタイトル
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(0, 380, 1280, 60)];
    sub.text            = @"Apple TV 2 / 3  —  frappliance";
    sub.textColor       = [UIColor colorWithWhite:0.6f alpha:1.0f];
    sub.backgroundColor = [UIColor clearColor];
    sub.font            = [UIFont systemFontOfSize:30.0f];
    sub.textAlignment   = UITextAlignmentCenter;
    sub.tag             = 9002;
    [rootView addSubview:sub];
    [sub release];
}

/*
 * controlWasDeactivated
 * 画面を離れるときにラベルを削除する。
 */
static void HelloController$controlWasDeactivated(id self, SEL _cmd) {
    UIView *rootView = nil;
    if (BRWindowCls) {
        id brWindow = [BRWindowCls performSelector:@selector(sharedWindow)];
        if ([brWindow respondsToSelector:@selector(rootView)]) {
            rootView = [brWindow performSelector:@selector(rootView)];
        }
    }
    if (!rootView) {
        rootView = [[UIApplication sharedApplication] keyWindow];
    }
    [[rootView viewWithTag:9001] removeFromSuperview];
    [[rootView viewWithTag:9002] removeFromSuperview];
}

/*
 * brEventAction:
 * リモコンイベントを処理する。
 * Menu ボタン (action == 1) でホームに戻る。
 * それ以外はオリジナル実装に委譲。
 */
static BOOL HelloController$brEventAction(id self, SEL _cmd, id event) {
    // remoteAction の値は BREvent の非公開プロパティ
    // kBREventRemoteActionMenu = 1
    int action = [[event valueForKey:@"remoteAction"] intValue];
    if (action == 1) {
        id app = [objc_getClass("BRApplication") sharedApplication];
        [app performSelector:@selector(popController)];
        return YES;
    }
    if (HelloController$brEventAction$Orig) {
        return HelloController$brEventAction$Orig(self, _cmd, event);
    }
    return NO;
}

/*
 * recreateOnReselect
 * ホーム画面で再選択されたとき再生成するかどうか。
 */
static BOOL HelloController$recreateOnReselect(id self, SEL _cmd) {
    return YES;
}

/*
 * shouldAutorotateToInterfaceOrientation:
 * Apple TV はランドスケープ固定。
 */
static BOOL HelloController$shouldAutorotate(id self, SEL _cmd,
                                              UIInterfaceOrientation o) {
    return (o == UIInterfaceOrientationLandscapeLeft ||
            o == UIInterfaceOrientationLandscapeRight);
}

// ──────────────────────────────────────────────────────────────────────────────
// ランタイム登録 (dylib ロード時に自動実行)
// ──────────────────────────────────────────────────────────────────────────────
static __attribute__((constructor)) void initControllerRuntimeClasses(void) {

    // BRController のサブクラス "HelloWorldController" を動的生成
    Class cls = objc_allocateClassPair(objc_getClass("BRController"),
                                       "HelloWorldController", 0);
    if (!cls) {
        NSLog(@"[HelloWorldATV] ERROR: failed to allocate HelloWorldController");
        return;
    }

    MSHookMessageEx(cls, @selector(init),
                    (IMP)HelloController$init, nil);
    MSHookMessageEx(cls, @selector(controlWasActivated),
                    (IMP)HelloController$controlWasActivated,
                    &HelloController$controlWasActivated$Orig);
    MSHookMessageEx(cls, @selector(controlWasDeactivated),
                    (IMP)HelloController$controlWasDeactivated, nil);
    MSHookMessageEx(cls, @selector(brEventAction:),
                    (IMP)HelloController$brEventAction,
                    (IMP *)&HelloController$brEventAction$Orig);
    MSHookMessageEx(cls, @selector(recreateOnReselect),
                    (IMP)HelloController$recreateOnReselect, nil);
    MSHookMessageEx(cls,
                    @selector(shouldAutorotateToInterfaceOrientation:),
                    (IMP)HelloController$shouldAutorotate, nil);

    objc_registerClassPair(cls);

    // BRWindow をキャッシュ
    BRWindowCls = objc_getClass("BRWindow");

    NSLog(@"[HelloWorldATV] HelloWorldController registered");
}
