/*
 * HelloWorldAppliance.mm
 *
 * Apple TV 2/3 (iOS 4.2+) 向け .frappliance エントリポイント
 *
 * iOS 5.x 以降、Apple は BackRow.framework を廃止し、全クラスを
 * AppleTV.app バイナリ内に移動した。このため通常の @implementation に
 * よるサブクラス化は不可能。
 * KodiAppliance.mm (xbmc/xbmc 14.2-Helix) と同じ手法で、
 * Objective-C ランタイム関数を用いて動的にサブクラスを生成・登録する。
 *
 * 参考リポジトリ:
 *   https://github.com/lechium/nitoTV
 *   https://github.com/xbmc/xbmc/tree/14.2-Helix/xbmc/osx/atv2/
 *   https://github.com/NSSpiral/Blackb0x
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>
#include "substrate.h"   // MobileSubstrate — theos が提供

// ──────────────────────────────────────────────────────────────────────────────
// Associated Object キー (ivar の代替)
// iOS 5+ では objc_allocateClassPair で生成したクラスに ivar を追加できないため
// ──────────────────────────────────────────────────────────────────────────────
static char kApplianceCategoriesKey;

// BRApplianceCategory クラスの参照 (起動時にキャッシュ)
static Class BRApplianceCategoryCls;

// ──────────────────────────────────────────────────────────────────────────────
// メソッド実装 (C 関数として定義、後で class_addMethod / MSHookMessageEx で登録)
// ──────────────────────────────────────────────────────────────────────────────

/*
 * applianceCategories
 * ホーム画面のカテゴリ一覧を返す。
 * Kodi と同じく Associated Object に格納したキャッシュを返す。
 */
static id HelloAppliance$applianceCategories(id self, SEL _cmd) {
    return objc_getAssociatedObject(self, &kApplianceCategoriesKey);
}

/*
 * setApplianceCategories:
 * setter。動的クラスに ivar がないため Associated Object で代用。
 */
static void HelloAppliance$setApplianceCategories(id self, SEL _cmd, id cats) {
    objc_setAssociatedObject(self, &kApplianceCategoriesKey, cats,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/*
 * init
 * カテゴリを1つ (identifier: "helloworld") 登録してから
 * スーパークラスの init を呼ぶ。
 */
static id HelloAppliance$init(id self, SEL _cmd) {
    // スーパークラス (BRBaseAppliance) の init を呼ぶ
    Class base = class_getSuperclass(object_getClass(self));
    IMP superInit = class_getMethodImplementation(base, _cmd);
    self = ((id (*)(id, SEL))superInit)(self, _cmd);
    if (!self) return nil;

    // カテゴリを生成して関連付ける
    // BRApplianceCategory は iOS 4.x 以降で使用可能
    if (BRApplianceCategoryCls) {
        id cat = [BRApplianceCategoryCls categoryWithName:@"Hello World"
                                               identifier:@"helloworld"
                                           preferredOrder:0];
        NSArray *cats = cat ? @[cat] : @[];
        objc_setAssociatedObject(self, &kApplianceCategoriesKey, cats,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

/*
 * identifierForContentAlias:
 * コンテンツのエイリアスから内部 identifier を返す。
 */
static id HelloAppliance$identifierForContentAlias(id self, SEL _cmd, id alias) {
    return @"helloworld";
}

/*
 * controllerForIdentifier:args:
 * ホーム画面で選択されたとき、表示するコントローラを返す。
 * objc_getClass でランタイムから HelloWorldController を取得する
 * (KodiAppliance.mm と同パターン)。
 */
static id HelloAppliance$controllerForIdentifier(id self, SEL _cmd,
                                                  id identifier, id args) {
    if ([identifier isEqualToString:@"helloworld"]) {
        Class ctrlCls = objc_getClass("HelloWorldController");
        if (ctrlCls) {
            id ctrl = [[ctrlCls alloc] init];
            return [ctrl autorelease];
        }
    }
    return nil;
}

// ──────────────────────────────────────────────────────────────────────────────
// __attribute__((constructor))
// dylib ロード時に自動実行されるランタイム登録関数。
// @implementation ではなく objc_allocateClassPair + objc_registerClassPair で
// サブクラスを動的に生成する (KodiAppliance.mm の initApplianceRuntimeClasses と同じ構造)。
// ──────────────────────────────────────────────────────────────────────────────
static __attribute__((constructor)) void initApplianceRuntimeClasses(void) {

    // BRBaseAppliance のサブクラス "HelloWorldAppliance" を動的生成
    Class cls = objc_allocateClassPair(objc_getClass("BRBaseAppliance"),
                                       "HelloWorldAppliance", 0);
    if (!cls) {
        NSLog(@"[HelloWorldATV] ERROR: failed to allocate HelloWorldAppliance");
        return;
    }

    // setter は class_addMethod で追加 (ベースクラスに存在しないため)
    class_addMethod(cls,
                    @selector(setApplianceCategories:),
                    (IMP)HelloAppliance$setApplianceCategories,
                    "v@:@");

    // ベースクラスのメソッドを MSHookMessageEx でオーバーライド
    MSHookMessageEx(cls, @selector(init),
                    (IMP)HelloAppliance$init, nil);
    MSHookMessageEx(cls, @selector(applianceCategories),
                    (IMP)HelloAppliance$applianceCategories, nil);
    MSHookMessageEx(cls, @selector(identifierForContentAlias:),
                    (IMP)HelloAppliance$identifierForContentAlias, nil);
    MSHookMessageEx(cls, @selector(controllerForIdentifier:args:),
                    (IMP)HelloAppliance$controllerForIdentifier, nil);

    // クラスを Objective-C ランタイムに登録
    objc_registerClassPair(cls);

    // BRApplianceCategory をキャッシュ
    BRApplianceCategoryCls = objc_getClass("BRApplianceCategory");

    NSLog(@"[HelloWorldATV] HelloWorldAppliance registered");
}
