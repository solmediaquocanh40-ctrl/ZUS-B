// ZUSRootListController 1.1.3 — trang Cài đặt của ZaloUnseen.
// 1.1.3: BẮC CẦU VÀO CONTAINER CỦA ZALO. Bài học 1.1.1–1.1.2: CFPreferences
// từ trong Zalo rơi vào kho container của Zalo, còn trang Cài đặt mặc định
// ghi kho toàn cục /var/mobile — hai kho không bao giờ gặp nhau, và từ
// trong Zalo thì file toàn cục bị sandbox chặn cả đọc lẫn ghi. Trang Cài
// đặt chạy ở tiến trình Preferences (quyền file rộng) nên nó TỰ TÌM file
// domain nằm trong container của Zalo và đọc/ghi thẳng vào đó qua hai
// điểm ghi đè chuẩn của PSListController. Mọi công tắc từ nay tác động
// đúng kho mà tweak đọc.
#import "ZUSRootListController.h"
#import "ZUSShared.h"
// Bản viết lại dùng trực tiếp PSSpecifier trong chữ ký hai hàm ghi đè:
// phải import header của nó, nếu không SDK mới báo "definition of
// PSSpecifier must be imported from module Preferences.PSSpecifier".
#import <Preferences/PSSpecifier.h>

// Tìm file plist của domain ZUS bên trong container dữ liệu của Zalo.
// File này chỉ tồn tại trong container của Zalo (do chính tweak tạo qua
// CFPreferences) nên tìm thấy là trúng. Không thấy (Zalo chưa từng chạy
// cùng tweak) thì ngã về đường toàn cục như cũ.
static NSString *ZUSPrefsFilePath(void) {
    static NSString *cached = nil;
    if (cached) return cached;
    NSString *rel = @"Library/Preferences/com.anhdang.zalounseen.plist";
    NSString *base = @"/var/mobile/Containers/Data/Application";
    NSArray *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:base error:nil];
    for (NSString *d in dirs) {
        NSString *p = [[base stringByAppendingPathComponent:d] stringByAppendingPathComponent:rel];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            cached = [p copy];
            return cached;
        }
    }
    cached = @"/var/mobile/Library/Preferences/com.anhdang.zalounseen.plist";
    return cached;
}

static NSMutableDictionary *ZUSPrefsDict(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:ZUSPrefsFilePath()];
    return d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}

@implementation ZUSRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        // 1.2.1 (bản dùng thật): chưa kích hoạt thì trang này cũng khoá —
        // tweak ghi đệm licenseState vào file chung mỗi lần đánh giá,
        // trang chỉ đọc lại verdict đó (không tự kiểm key ở đây).
        id st = ZUSPrefsDict()[@"licenseState"];
        BOOL licensed = [st isKindOfClass:[NSNumber class]] && [st intValue] == 1;
        _specifiers = [self loadSpecifiersFromPlistName:(licensed ? @"Root" : @"RootLocked") target:self];
    }
    return _specifiers;
}

// Đọc: file container trước, rồi kho toàn cục (gương), rồi mặc định của
// specifier (qua super).
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return [super readPreferenceValue:specifier];
    id v = ZUSPrefsDict()[key];
    if (v) return v;
    CFPropertyListRef g = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    if (g) return (__bridge_transfer id)g;
    return [super readPreferenceValue:specifier];
}

// Ghi: thẳng vào file container + soi gương sang kho toàn cục + bắn thông
// báo Darwin để tweak nạp lại cài đặt ngay.
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) { [super setPreferenceValue:value specifier:specifier]; return; }
    NSMutableDictionary *d = ZUSPrefsDict();
    if (value) d[key] = value; else [d removeObjectForKey:key];
    [d writeToFile:ZUSPrefsFilePath() atomically:YES];
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.anhdang.zalounseen/prefsChanged"),
                                         NULL, NULL, true);
}

static id ZUSDiagValue(NSString *key) {
    id v = ZUSPrefsDict()[key];
    if (v) return v;
    CFPropertyListRef g = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    return (__bridge_transfer id)g;
}

- (void)showDiag {
    NSNumber *cand = ZUSDiagValue(ZUS_DIAG_CANDIDATES);
    NSNumber *hooked = ZUSDiagValue(ZUS_DIAG_HOOKED);
    NSNumber *skipped = ZUSDiagValue(ZUS_DIAG_SKIPPED);
    NSNumber *blockedRead = ZUSDiagValue(ZUS_DIAG_BLOCKED_READ);
    NSNumber *blockedType = ZUSDiagValue(ZUS_DIAG_BLOCKED_TYPE);
    NSNumber *blockedDeliv = ZUSDiagValue(ZUS_DIAG_BLOCKED_DELIV);
    NSNumber *blockedRecall = ZUSDiagValue(ZUS_DIAG_BLOCKED_RECALL);
    NSString *last = ZUSDiagValue(ZUS_DIAG_LAST);
    NSString *scan = ZUSDiagValue(ZUS_DIAG_SCAN);
    NSString *ctor = ZUSDiagValue(ZUS_DIAG_CTOR);
    NSNumber *friends = ZUSDiagValue(ZUS_DIAG_FRIENDS);
    NSString *friendsrc = ZUSDiagValue(ZUS_DIAG_FRIENDSRC);
    NSString *zaloupd = ZUSDiagValue(ZUS_DIAG_ZALOUPD);
    NSString *msg;
    if (!cand && !hooked) {
        if (ctor.length) {
            msg = [NSString stringWithFormat:
                @"Tweak ĐÃ nạp vào Zalo lúc %@ nhưng chưa quét được dữ liệu.\n\nMở app Zalo, vào một đoạn chat bất kỳ, đợi vài giây rồi quay lại đây kiểm tra.", ctor];
        } else {
            msg = @"Tweak CHƯA từng nạp vào Zalo (không có mốc nạp).\n\nMở app Zalo một lúc rồi quay lại đây kiểm tra. Nếu vẫn trống thì gửi mình file log trong Documents của Zalo (Filza → Apps → Zalo → Documents → ZUS.log).";
        }
    } else {
        msg = [NSString stringWithFormat:
            @"Đã nạp vào Zalo: %@\nLần quét gần nhất: %@\nỨng viên tìm thấy: %@\nĐã móc thành công: %@\nBỏ qua (kiểu dữ liệu không an toàn): %@\nĐã chặn 'đã xem': %@ lần\nĐã chặn 'đang nhập': %@ lần\nĐã chặn 'đã nhận': %@ lần\nĐã chặn 'thu hồi': %@ lần\nSự kiện gần nhất: %@\nBạn bè đã sao lưu: %@ (nguồn: %@)\nZalo đã đổi bản: %@",
            ctor.length ? ctor : @"—", scan ?: @"—", cand ?: @0, hooked ?: @0, skipped ?: @0,
            blockedRead ?: @0, blockedType ?: @0, blockedDeliv ?: @0, blockedRecall ?: @0, last.length ? last : @"—", friends ?: @0, friendsrc.length ? friendsrc : @"—", zaloupd.length ? zaloupd : @"—"];
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Trạng thái dò" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
