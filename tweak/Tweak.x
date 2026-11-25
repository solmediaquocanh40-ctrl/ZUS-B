// ZUS 1.3.3 — đọc tin nhắn Zalo mà bên kia không thấy "đã xem", tắt "đang nhập...".
//
// SỬA GỐC VỤ VĂNG CỦA 1.0.4 (đã chứng minh ở mức lệnh máy từ file .ips và đúng
// file .deb đã cài): hàm thay thế chung ZUSGenericHook khai tham số kiểu `id`,
// dưới ARC trình biên dịch tự chèn objc_retain cho CẢ hai tham số ngay khi vào
// hàm. Hàm đích nào có tham số thứ hai là SỐ NGUYÊN (ví dụ phần `type:` của
// ConversationModel.updateLastSeenWithMessage:type:) thì lệnh retain đó đọc
// con số như một địa chỉ bộ nhớ → EXC_BAD_ACCESS tại đúng giá trị của con số
// (0x20), trên hàng đợi của model nhóm, chết trước khi kịp chặn hay ghi log.
// 1.0.5: mọi hàm thay thế khai tham số là __unsafe_unretained / void* — ARC
// không retain bất cứ tham số nào nữa; chữ ký gọi bản gốc cũng khai tương ứng.
//
// Cơ chế DANH SÁCH TRẮNG (từ 1.0.4): chỉ móc đúng các hàm GỬI trạng thái
// đã xem / đang nhập đã được kiểm chứng — từ log máy thật của bản 1.0.3 và từ bộ
// móc của ZaloTools (BVN) mà Quoc đã thử trên đúng bản Zalo này: lớp màn hình chat
// (BaseChatTVC), lớp xử lý (BaseChatProcessor), lớp quản lý hàng đợi + gửi
// (ChatSendSeenDataManager, ChatDataManager), lớp socket (ChatSocketCmdHelper)
// và lớp trạng thái trong máy (ConversationModel); 1.0.6 thêm lớp dữ liệu
// (ChatDataManager, ChatDataFlow, InboxDataManager, ChatProcessor). Tổng 36 hàm.
// 1.0.5 bỏ hai hàm sendGetChatSeen/sendGetGroupSeen từng có trong danh sách dự
// thảo: hai hàm đó LẤY danh sách người đã xem tin của CHÍNH mình — không thuộc
// luồng cần chặn, móc chúng có nguy cơ làm hỏng mục "ai đã xem" trong nhóm.
// Thêm ghi nhận "lần đầu được gọi" cho từng cửa: vòng thử sau chỉ cần nhìn log
// là biết cửa nào thật sự chạy khi mở đoạn chat, kể cả cửa được chuyển tiếp.
//
// 1.0.6 — HAI THAY ĐỔI TỪ LOG MÁY THẬT CỦA 1.0.5 (phiên 01:20 ngày 11-24):
// (a) 1.0.5 HẾT VĂNG THẬT nhưng chữ vẫn mất đậm, dù log chứng minh cả 25 cửa
// lắp được đều chạy và bị chặn khi mở nhóm — kể cả setLastSeenObject: trong
// máy và forceSendSeenServer ra máy chủ. Kết luận: luồng đánh dấu đã đọc còn
// chạy qua LỚP DỮ LIỆU (ghi trạng thái đã xem vào giao diện + cơ sở dữ liệu)
// nằm ngoài 25 cửa. 1.0.6 thêm 9 cửa lớp dữ liệu (tổng 36): họ
// processUpdateStatus...withUI:withDB: của ChatDataManager / ChatDataFlow /
// InboxDataManager, processResetUnread... của ChatProcessor, và
// updateMaxSeenGlobalId: / checkSendClearUnreadType: của ChatDataManager —
// tên hàm lấy từ danh sách ứng viên trong chính bản Zalo của máy (log 1.0.3).
// (b) ĐANG NHẬP: log 1.0.5 ghi rõ mã kiểu — sendTyping... trả về B,
// sendStatusTyping... trả về Q. Nguyên nhân bị từ chối ở 1.0.4 KHÔNG phải ký
// tự định tính (giả thuyết cũ đã sai): cổng chỉ nhận hàm trả về void. 1.0.6
// nới cổng cho mọi kiểu trả về vô hướng/con trỏ và mọi hàm thay thế trả lại
// long long: chuyển tiếp thì trả nguyên giá trị gốc, chặn thì trả 0.
//
// 1.1.0 — BẢN TÍNH NĂNG CHÍNH THỨC (anh duyệt ngày 2026-11-24, đổi tên ZUS).
// Nguyên tắc cứng: 36 cửa của 1.0.6 giữ nguyên; mọi thứ mới đều cộng thêm,
// tắt được từng món, hỏng thì chỉ hỏng phần mới.
// - Đổi thương hiệu ZU → ZUS (nút, bảng cài đặt, tên gói hiển thị); mã gói
//   com.anhdang.zalounseen và kho cài đặt giữ nguyên để không mất dữ liệu cũ.
// - Tách "đã nhận" thành nhóm riêng (nhóm 3, khoá hideDelivered, mặc định BẬT
//   = đúng hành vi 1.0.6): 5 cửa delivered của ChatSocketCmdHelper. Riêng lần
//   gọi nào mang cờ isSeen=YES thì vẫn chặn theo nhóm đã-xem dù đã-nhận đang
//   tắt — không để lọt đã-xem qua cửa hậu.
// - Chống thu hồi (nhóm 4, khoá antiRecall, mặc định BẬT): 7 cửa ở chuỗi xử
//   lý thu hồi (Zalo gọi là "undo"), điểm móc lấy từ chính dylib của
//   ZaloTools (BVN) vốn nhắm đúng thế hệ Zalo này: MSDataCoordinator
//   (handleRecallMessageNotification:, _handleRecallWithData:),
//   UndoChatProcessor.updateDBUndo... (hàm class), ChatUIManager
//   (processUndoWithSocketChatEntity:, handleUpdateUndo... — hàm class),
//   ChatEntity.preprocessMessageUndo, TalkTableItem.updateUndoWithParser:.
// - Ẩn "đã xem" cho Story (nhóm 1): StoryManager.updateSeenStoryStatus: +
//   StoryEntity.updateSeen: — tên hàm trong chính bản Zalo của máy (log 1.0.3).
// - Giữ màn hình sáng (khoá keepAwake, mặc định TẮT): không móc hàm nào —
//   chỉ đặt idleTimerDisabled lúc nạp và mỗi khi đổi cài đặt.
// - Cửa cài đặt ngay trong Zalo (khoá inAppUI, mặc định BẬT): nút tròn "ZUS"
//   trong màn hình chat (móc viewWillAppear: của BaseChatTVC, LUÔN chuyển
//   tiếp bản gốc trước, bọc try/catch) mở bảng công tắc ZUSSettingsController
//   viết riêng trong file này — ghi cùng kho prefs + cùng thông báo Darwin
//   nên đổi trong Zalo là ăn ngay; trang Cài đặt của máy vẫn giữ nguyên.
// - Vá vụ "tắt mà vẫn unseen" (từ log 2026-11-24): nạp lại kho cài đặt mỗi
//   khi mở đoạn chat + ghi log mỗi khi phát hiện cài đặt thay đổi.
// - Tải Story về máy (khoá storyDownload, mặc định TẮT): trả YES cho
//   isAllowDownloadCurrentStory trên lớp Story (điểm móc theo ZaloZen 3.0.0
//   vốn nhắm đúng thế hệ Zalo này) để Zalo tự hiện nút lưu của chính nó.
// - Màn chắn riêng tư (khoá privacyShield, mặc định TẮT): phủ mờ mọi cửa sổ
//   khi Zalo sắp rời tiền cảnh (ảnh chụp đa nhiệm không lộ nội dung), gỡ ra
//   ngay khi quay lại. Không móc hàm nào của Zalo.
// - Cảnh báo khi Zalo đổi phiên bản: ghi log + mốc chẩn đoán để đối chiếu
//   cửa móc sau mỗi lần Zalo cập nhật.
// - Backup/restore DANH BẠ (yêu cầu riêng của anh): xuất ZUS-Contacts.json /
//   .csv / .vcf vào Documents của Zalo; khôi phục = đối chiếu bản sao với
//   danh bạ hiện tại, liệt kê người đã mất, chạm để mở trang Zalo (có số)
//   hoặc chép mã Zalo. Nguồn bạn bè đi đường DÒ CÓ KIỂM SOÁT (xem
//   ZUSCollectFriends) vì chưa có bản đồ lớp bạn bè trong log cũ.
// - Hồ sơ ZUS: xuất/nhập toàn bộ công tắc ra file ZUS-Profile.json.
// ĐÃ LOẠI theo đúng quy tắc "chưa chắc thì khỏi" của anh: chỉnh riêng từng
// hội thoại, khoá đoạn chat bằng Face ID, ẩn trạng thái đang hoạt động (chưa
// có cửa), gửi ảnh gốc, tải media hàng loạt, gán nhãn bạn bè, ẩn avatar/tên/
// tin cuối + ẩn tab (nhóm giao diện — cần vòng dò riêng), chặn quảng cáo,
// chạm 2 lần sao chép, kho lưu tin nhắn, dịch trong chat, cảnh báo link lạ
// (cả bốn món sau cần đường đọc nội dung tin — vòng dò riêng), lên lịch gửi
// tin, ghi âm cuộc gọi, phát nền khi tắt màn hình (anh tự bỏ).
//
// Vì sao bỏ cơ chế dò theo mẫu của 1.0.0–1.0.3: log 1.0.3 cho thấy mẫu khớp theo
// chuỗi con đã nổ tung — chữ "read" nằm trong "thread", "already", "ready", "reader"
// nên 1.162 ứng viên lọt lưới, 877 hàm bị móc, phần lớn là hàm gán dữ liệu
// (setThreadId:...) khắp app. Chặn các hàm gán đó làm Zalo sập ngay khi mở.
// Từ 1.0.4: không quét, không khớp mẫu — danh sách cố định, hàm nào không thấy
// hoặc kiểu dữ liệu không khớp kỳ vọng thì ghi log và bỏ qua, tuyệt đối không
// đụng vào phần còn lại của app.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <Photos/Photos.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <sqlite3.h>
#import "ZUSShared.h"

// ---------------- Cài đặt ----------------
static BOOL gEnabled = YES;
static BOOL gUnseen = YES;
static BOOL gHideTyping = YES;
static BOOL gDebug = YES;
static BOOL gHideDelivered = YES; // 1.1.0: mặc định BẬT = đúng hành vi 1.0.6
static BOOL gAntiRecall = YES;
static BOOL gKeepAwake = NO;
static BOOL gInAppUI = YES;
static BOOL gLongPressTab = YES; // 1.1.1: ấn giữ thanh tab mở bảng ZUS
static BOOL gStoryDownload = NO;
static BOOL gPrivacyShield = NO;
static BOOL gPrefsSeen = NO;

static void ZUSLog(NSString *fmt, ...);

// ----- Kho prefs CHUNG (1.1.2) -----
// Bài học đắt của 1.1.1: CFPreferences gọi từ trong Zalo rơi vào kho
// container của Zalo, còn trang Cài đặt ghi vào file chung
// /var/mobile/Library/Preferences — hai kho lệch nhau khiến anh tắt tổng
// trong Zalo rồi gạt lại ở Cài đặt suốt một giờ mà tweak không hề biết.
// Từ 1.1.2: FILE CHUNG là nguồn chính — đọc file trước (không có khoá mới
// ngã về CFPreferences rồi mặc định), ghi thì ghi CẢ HAI nơi cho hai kho
// hội tụ dần. Kết quả đọc/ghi file đều có log để kiểm chứng trên máy thật.
static NSString *ZUSSharedPrefsPath(void) {
    // 1.1.3: tiến trình nằm trong container của Zalo thì file domain nằm
    // ngay trong container đó — đọc/ghi trực tiếp được, không qua cfprefsd
    // (1.1.2 đã chứng minh đường /var/mobile bị sandbox chặn cả hai chiều).
    // Ngoài container thì giữ đường toàn cục.
    NSString *home = NSHomeDirectory();
    if ([home containsString:@"/Containers/"]) {
        return [[[home stringByAppendingPathComponent:@"Library/Preferences"]
                 stringByAppendingPathComponent:ZUS_DOMAIN] stringByAppendingString:@".plist"];
    }
    return [@"/var/mobile/Library/Preferences/" stringByAppendingString:[ZUS_DOMAIN stringByAppendingString:@".plist"]];
}
static NSDictionary *ZUSReadFilePrefs(void) {
    return [NSDictionary dictionaryWithContentsOfFile:ZUSSharedPrefsPath()];
}
static BOOL gFileWriteLogged = NO;
// Mọi lần sửa file chung đều qua một khoá duy nhất (đọc–sửa–ghi là một khối)
// để luồng chặn tin và luồng giao diện không ghi đè lẫn nhau.
static NSObject *ZUSPrefsFileLock(void) {
    static NSObject *lock = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSObject alloc] init]; });
    return lock;
}
static void ZUSWriteSharedValue(NSString *key, id value) {
    NSMutableDictionary *fp = nil;
    BOOL wok = NO;
    @synchronized (ZUSPrefsFileLock()) {
        fp = [ZUSReadFilePrefs() mutableCopy];
        if (!fp) fp = [NSMutableDictionary dictionary];
        if (value) fp[key] = value; else [fp removeObjectForKey:key];
        wok = [fp writeToFile:ZUSSharedPrefsPath() atomically:YES];
    }
    if (!gFileWriteLogged) {
        gFileWriteLogged = YES;
        ZUSLog(@"ghi file prefs chung: %@", wok ? @"OK" : @"THẤT BẠI (có thể bị sandbox chặn ghi — đọc log nguồn cài đặt để đối chiếu)");
    }
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
}

static BOOL ZUSReadBool(NSString *key, BOOL def) {
    id fv = ZUSReadFilePrefs()[key];
    if ([fv isKindOfClass:[NSNumber class]]) return [fv boolValue];
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    if (!v) return def;
    BOOL r = def;
    if (CFGetTypeID(v) == CFBooleanGetTypeID()) r = CFBooleanGetValue((CFBooleanRef)v);
    else if (CFGetTypeID(v) == CFNumberGetTypeID()) { int n = 0; CFNumberGetValue((CFNumberRef)v, kCFNumberIntType, &n); r = (n != 0); }
    CFRelease(v);
    return r;
}

// ----- 1.1.5: lịch giờ / cài riêng theo đoạn chat / khoá / nhật ký -----
static BOOL gSchedEnabled = NO;
static int gSchedFrom = 22 * 60;
static int gSchedTo = 7 * 60;
static BOOL gLinkWarning = NO;
static BOOL gAdBlock = NO;
// 1.3.0: cờ tính năng vòng 1.3.0 (mặc định TẮT hết — anh chủ động bật).
static BOOL gHideTabDiscover = NO;
static BOOL gHideTabTimeline = NO;
static BOOL gConfirmCall = NO;
static BOOL gPhotoOriginal = NO;
static BOOL gMoreEmoji = NO;
static NSDictionary *gCallBlock = nil; // threadId -> 0 tắt / 1 im lặng / 2 máy bận
static BOOL gLicensed = NO;
static int gLicenseState = 0;
static NSString *gLicenseName = @"";
static int gLicenseDaysLeft = -1;
static void ZUSShowActivationPopup(void);
static void ZUSDismissActivationPopup(void);
static NSString *ZUSDeviceCode(void);
static NSString *ZUSReadString(NSString *key);
static void ZUSApplyTabHiding(void);
static UIViewController *ZUSTopVC(void);
static NSDictionary *gPerChat = nil;
static NSDictionary *gLockedChats = nil;
static NSMutableDictionary *gJournal = nil;
static NSString *gZUSCurrentThreadID = nil;
static NSString *gZUSCurrentThreadName = nil;
static BOOL ZUSScheduleActiveNow(void);
static NSString *ZUSCatKey(int cat);

static id ZUSReadObject(NSString *key) {
    id fv = ZUSReadFilePrefs()[key];
    if (fv) return fv;
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    return (__bridge_transfer id)v;
}

static int ZUSReadInt(NSString *key, int def) {
    id v = ZUSReadObject(key);
    return [v isKindOfClass:[NSNumber class]] ? [v intValue] : def;
}


// ---------------- Bản quyền — key kích hoạt (1.2.0 thử nghiệm dùng thử, 1.2.1 bản dùng thật) ----------------
// Key có chữ ký ECDSA P-256; tweak chỉ giữ khoá CÔNG KHAI để kiểm tra,
// khoá bí mật nằm ở công cụ sinh key riêng (không có trong gói này).
static NSData *ZUSBase32Decode(NSString *str) {
    static int table[256];
    static BOOL built = NO;
    if (!built) {
        for (int i = 0; i < 256; i++) table[i] = -1;
        const char *alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        for (int i = 0; i < 32; i++) table[(unsigned char)alpha[i]] = i;
        built = YES;
    }
    NSMutableData *out = [NSMutableData data];
    int buffer = 0, bits = 0;
    for (NSUInteger i = 0; i < str.length; i++) {
        unichar c = [str characterAtIndex:i];
        if (c > 255) continue;
        int v = table[c];
        if (v < 0) continue;
        buffer = (buffer << 5) | v;
        bits += 5;
        if (bits >= 8) {
            int byte = (buffer >> (bits - 8)) & 0xFF;
            [out appendBytes:&byte length:1];
            bits -= 8;
            buffer &= (bits > 0) ? ((1 << bits) - 1) : 0;
        }
    }
    return out;
}


// SecKeyVerifySignature voi thuat toan ...X962... doi chu ky o dinh
// dang X9.62 = DER (SEQUENCE cua 2 INTEGER), KHONG phai raw r||s.
// Key cua ZUS luu chu ky raw 64 byte nen phai chuyen truoc khi kiem.
static NSData *ZUSRawSigToDER(NSData *sig) {
    if (sig.length != 64) return nil;
    const unsigned char *b = sig.bytes;
    int rOff = 0;
    while (rOff < 31 && b[rOff] == 0) rOff++;
    int sOff = 0;
    while (sOff < 31 && b[32 + sOff] == 0) sOff++;
    int rLen = 32 - rOff, sLen = 32 - sOff;
    BOOL rPad = (b[rOff] & 0x80) != 0;
    BOOL sPad = (b[32 + sOff] & 0x80) != 0;
    int rIntLen = rLen + (rPad ? 1 : 0);
    int sIntLen = sLen + (sPad ? 1 : 0);
    int total = 2 + rIntLen + 2 + sIntLen;
    NSMutableData *der = [NSMutableData data];
    unsigned char hdr[2] = {0x30, (unsigned char)total};
    [der appendBytes:hdr length:2];
    unsigned char ih[2] = {0x02, (unsigned char)rIntLen};
    [der appendBytes:ih length:2];
    if (rPad) { unsigned char z = 0; [der appendBytes:&z length:1]; }
    [der appendBytes:b + rOff length:(NSUInteger)rLen];
    ih[1] = (unsigned char)sIntLen;
    [der appendBytes:ih length:2];
    if (sPad) { unsigned char z = 0; [der appendBytes:&z length:1]; }
    [der appendBytes:b + 32 + sOff length:(NSUInteger)sLen];
    return der;
}

static NSDictionary *ZUSVerifyLicenseKey(NSString *keyStr) {
    if (!keyStr) return nil;
    NSString *clean = [[[keyStr uppercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
    clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![clean hasPrefix:@"ZUS1"]) return nil;
    NSData *blob = ZUSBase32Decode([clean substringFromIndex:4]);
    if (blob.length < 15 + 64) return nil;
    NSData *payload = [blob subdataWithRange:NSMakeRange(0, blob.length - 64)];
    NSData *sig = [blob subdataWithRange:NSMakeRange(blob.length - 64, 64)];
    NSData *pubData = [[NSData alloc] initWithBase64EncodedString:@"BGf4pk7m5Mn5Kr90UUd4jCLJT4U7+D3V1pa5+/5FM+6azD5oExYTyoHGnN/0ufW70BTDRttd3ri11KvujCYYFj4=" options:0];
    NSDictionary *attrs = @{(__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
                            (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPublic,
                            (__bridge id)kSecAttrKeySizeInBits: @256};
    SecKeyRef pub = SecKeyCreateWithData((__bridge CFDataRef)pubData, (__bridge CFDictionaryRef)attrs, NULL);
    if (!pub) { ZUSLog(@"bản quyền: tạo khoá công khai thất bại"); return nil; }
    NSData *sigDER = ZUSRawSigToDER(sig);
    BOOL ok = sigDER && SecKeyVerifySignature(pub, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (__bridge CFDataRef)payload, (__bridge CFDataRef)sigDER, NULL);
    CFRelease(pub);
    if (!ok) { ZUSLog(@"bản quyền: chữ ký key KHÔNG khớp"); return nil; }
    const unsigned char *b = payload.bytes;
    int ver = b[0], kind = b[1];
    if (ver != 1 || kind == 2) return nil;
    unsigned field = ((unsigned)b[2] << 24) | ((unsigned)b[3] << 16) | ((unsigned)b[4] << 8) | b[5];
    int nameLen = b[14];
    NSString *name = @"";
    if ((int)payload.length >= 15 + nameLen && nameLen > 0)
        name = [[NSString alloc] initWithBytes:b + 15 length:(NSUInteger)nameLen encoding:NSUTF8StringEncoding] ?: @"";
    return @{@"kind": @(kind), @"exp": @(field), @"devHash": [payload subdataWithRange:NSMakeRange(6, 8)], @"name": name};
}

static NSString *ZUSKeychainGet(NSString *account) {
    NSDictionary *q = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                        (__bridge id)kSecAttrService: @"com.anhdang.zus.state",
                        (__bridge id)kSecAttrAccount: account,
                        (__bridge id)kSecReturnData: @YES,
                        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne};
    CFTypeRef out = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &out) == errSecSuccess && out) {
        NSData *d = (__bridge_transfer NSData *)out;
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    }
    return nil;
}

static void ZUSKeychainSet(NSString *account, NSString *value) {
    NSData *d = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *idq = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                          (__bridge id)kSecAttrService: @"com.anhdang.zus.state",
                          (__bridge id)kSecAttrAccount: account};
    OSStatus st = SecItemUpdate((__bridge CFDictionaryRef)idq, (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: d});
    if (st == errSecItemNotFound) {
        NSMutableDictionary *add = [idq mutableCopy];
        add[(__bridge id)kSecValueData] = d;
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
        SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    }
}

static NSString *ZUSDeviceCode(void) {
    NSString *uuid = ZUSKeychainGet(@"dev");
    if (!uuid.length) {
        uuid = NSUUID.UUID.UUIDString;
        ZUSKeychainSet(@"dev", uuid);
    }
    unsigned char dig[CC_SHA256_DIGEST_LENGTH];
    const char *u = [uuid UTF8String];
    CC_SHA256(u, (CC_LONG)strlen(u), dig);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < 6; i++) [hex appendFormat:@"%02X", dig[i]];
    return [NSString stringWithFormat:@"%@-%@-%@", [hex substringWithRange:NSMakeRange(0, 4)], [hex substringWithRange:NSMakeRange(4, 4)], [hex substringWithRange:NSMakeRange(8, 4)]];
}

static NSData *ZUSDeviceHash(void) {
    NSString *code = [ZUSDeviceCode() stringByReplacingOccurrencesOfString:@"-" withString:@""];
    unsigned char dig[CC_SHA256_DIGEST_LENGTH];
    const char *u = [code UTF8String];
    CC_SHA256(u, (CC_LONG)strlen(u), dig);
    return [NSData dataWithBytes:dig length:8];
}

static NSString *ZUSKeyHashHex(NSString *key) {
    const char *u = [key UTF8String];
    unsigned char dig[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(u, (CC_LONG)strlen(u), dig);
    NSMutableString *h = [NSMutableString string];
    for (int i = 0; i < 8; i++) [h appendFormat:@"%02x", dig[i]];
    return h;
}

// Đánh giá trạng thái bản quyền — BẢN DÙNG THẬT (anh chốt ở 1.2.1):
// KHÔNG có dùng thử. Chỉ key hợp lệ mới mở được chức năng. Kết quả
// được ghi đệm vào file chung để trang Cài đặt đọc và tự khoá theo.
static void ZUSLicenseEvaluate(void) {
    gLicenseState = 0;
    gLicensed = NO;
    gLicenseName = @"";
    gLicenseDaysLeft = -1;
    NSString *key = ZUSReadString(ZUS_KEY_LICENSE);
    NSDictionary *info = key.length ? ZUSVerifyLicenseKey(key) : nil;
    if (info) {
        int kind = [info[@"kind"] intValue];
        long long field = [info[@"exp"] longLongValue];
        long long nowDay = (long long)([[NSDate date] timeIntervalSince1970] / 86400.0);
        BOOL ok = NO;
        if (kind == 1) {
            ok = YES;
        } else if (kind == 0) {
            if ([info[@"devHash"] isEqualToData:ZUSDeviceHash()] && (field == 0 || nowDay <= field)) {
                ok = YES;
                if (field) gLicenseDaysLeft = (int)(field - nowDay);
            }
        } else if (kind == 3) {
            NSString *kh = ZUSKeyHashHex(key);
            long long actDay = 0;
            id rec = ZUSReadObject(@"licenseAct");
            if ([rec isKindOfClass:[NSDictionary class]] && [rec[@"hash"] isEqualToString:kh]) actDay = [rec[@"day"] longLongValue];
            NSString *ka = ZUSKeychainGet(@"ta");
            if (ka) {
                NSArray *parts = [ka componentsSeparatedByString:@":"];
                if (parts.count == 2 && [parts[0] isEqualToString:kh]) actDay = MAX(actDay, [parts[1] longLongValue]);
            }
            if (actDay <= 0) {
                actDay = nowDay;
                ZUSWriteSharedValue(@"licenseAct", @{@"hash": kh, @"day": @(actDay)});
                ZUSKeychainSet(@"ta", [NSString stringWithFormat:@"%@:%lld", kh, actDay]);
            }
            if (nowDay < actDay + field) { ok = YES; gLicenseDaysLeft = (int)(actDay + field - nowDay); }
        }
        if (ok) { gLicensed = YES; gLicenseState = 1; gLicenseName = info[@"name"] ?: @""; }
    }
    static int sLastWritten = -1;
    if (gLicenseState != sLastWritten) {
        sLastWritten = gLicenseState;
        ZUSWriteSharedValue(@"licenseState", @(gLicenseState));
        ZUSWriteSharedValue(@"licenseName", gLicenseName);
    }
    ZUSLog(@"bản quyền: %@ (key còn %d ngày)", gLicensed ? @"ĐÃ KÍCH HOẠT" : @"CHƯA KÍCH HOẠT", gLicenseDaysLeft);
}

static BOOL ZUSActivateWithKey(NSString *keyStr) {
    NSString *k = [keyStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDictionary *info = ZUSVerifyLicenseKey(k);
    if (!info) return NO;
    if ([info[@"kind"] intValue] == 0 && ![info[@"devHash"] isEqualToData:ZUSDeviceHash()]) return NO;
    ZUSWriteSharedValue(ZUS_KEY_LICENSE, k);
    ZUSLicenseEvaluate();
    return gLicensed;
}

static NSString *ZUSLicenseStatusText(void) {
    if (gLicenseState == 1) {
        if (gLicenseDaysLeft < 0) return [NSString stringWithFormat:@"Đã kích hoạt — %@ (vĩnh viễn)", gLicenseName];
        return [NSString stringWithFormat:@"Đã kích hoạt — %@ (còn %d ngày)", gLicenseName, gLicenseDaysLeft];
    }
    return @"Chưa kích hoạt — nhập key để sử dụng";
}

static void ZUSLoadPrefs(void) {
    BOOL oEnabled = gEnabled, oUnseen = gUnseen, oTyping = gHideTyping, oDeliv = gHideDelivered, oRecall = gAntiRecall;
    CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
    gEnabled = ZUSReadBool(ZUS_KEY_ENABLED, YES);
    gUnseen = ZUSReadBool(ZUS_KEY_UNSEEN, YES);
    gHideTyping = ZUSReadBool(ZUS_KEY_TYPING, YES);
    gDebug = ZUSReadBool(ZUS_KEY_DEBUG, YES);
    gHideDelivered = ZUSReadBool(ZUS_KEY_DELIVERED, YES);
    gAntiRecall = ZUSReadBool(ZUS_KEY_ANTIRECALL, YES);
    gKeepAwake = ZUSReadBool(ZUS_KEY_AWAKE, NO);
    gInAppUI = ZUSReadBool(ZUS_KEY_INAPP, YES);
    gLongPressTab = ZUSReadBool(ZUS_KEY_LONGTAB, YES);
    gStoryDownload = ZUSReadBool(ZUS_KEY_STORYDL, NO);
    gPrivacyShield = ZUSReadBool(ZUS_KEY_SHIELD, NO);
    if (gPrefsSeen && (oEnabled != gEnabled || oUnseen != gUnseen || oTyping != gHideTyping || oDeliv != gHideDelivered || oRecall != gAntiRecall))
        ZUSLog(@"cài đặt đổi: bật=%d đã-xem=%d đã-nhận=%d đang-nhập=%d thu-hồi=%d", gEnabled, gUnseen, gHideDelivered, gHideTyping, gAntiRecall);
    gSchedEnabled = ZUSReadBool(ZUS_KEY_SCHED, NO);
    gSchedFrom = ZUSReadInt(ZUS_KEY_SCHEDFROM, 22 * 60);
    gSchedTo = ZUSReadInt(ZUS_KEY_SCHEDTO, 7 * 60);
    gLinkWarning = ZUSReadBool(ZUS_KEY_LINKWARN, NO);
    gAdBlock = ZUSReadBool(ZUS_KEY_ADBLOCK, NO);
    gHideTabDiscover = ZUSReadBool(ZUS_KEY_HIDETABDISC, NO);
    gHideTabTimeline = ZUSReadBool(ZUS_KEY_HIDETABTIME, NO);
    gConfirmCall = ZUSReadBool(ZUS_KEY_CONFIRMCALL, NO);
    gPhotoOriginal = ZUSReadBool(ZUS_KEY_PHOTOORIG, NO);
    gMoreEmoji = ZUSReadBool(ZUS_KEY_MOREEMOJI, NO);
    { id cb = ZUSReadObject(ZUS_KEY_CALLBLOCK); gCallBlock = [cb isKindOfClass:[NSDictionary class]] ? cb : @{}; }
    ZUSLicenseEvaluate();
    { id pc = ZUSReadObject(ZUS_KEY_PERCHAT); gPerChat = [pc isKindOfClass:[NSDictionary class]] ? pc : @{}; }
    { id lc = ZUSReadObject(ZUS_KEY_LOCKED); gLockedChats = [lc isKindOfClass:[NSDictionary class]] ? lc : @{}; }
    { id j = ZUSReadObject(ZUS_KEY_JOURNAL); gJournal = [j isKindOfClass:[NSDictionary class]] ? [j mutableCopy] : [NSMutableDictionary dictionary]; }
    gPrefsSeen = YES;
}

// Giữ màn hình sáng: không móc hàm nào của Zalo — chỉ đặt cờ của hệ thống
// trên luồng chính, lúc nạp và mỗi khi cài đặt thay đổi.
static void ZUSApplyAwake(void) {
    BOOL want = gEnabled && gKeepAwake;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].idleTimerDisabled = want;
    });
}

static void ZUSPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    ZUSLoadPrefs();
    ZUSApplyAwake();
    ZUSApplyTabHiding();
}

// Ghi một khoá cài đặt rồi phát thông báo để chính tweak nạp lại ngay (dùng
// cho bảng công tắc trong Zalo; trang Cài đặt của máy đi đường Preferences).
static void ZUSSetPrefBool(NSString *key, BOOL val) {
    ZUSWriteSharedValue(key, @(val));
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
}

// ---------------- Log ----------------
static NSString *gLogPath = nil;
static id gLogLock = nil;
static NSDateFormatter *gLogFmt = nil;

static void ZUSLog(NSString *fmt, ...) {
    if (!gDebug) return;
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[ZUS] %@", msg);
    if (!gLogPath || !gLogLock) return;
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [gLogFmt stringFromDate:[NSDate date]], msg];
    @synchronized (gLogLock) {
        NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:gLogPath];
        if (h) { [h seekToEndOfFile]; [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [h closeFile]; }
        else [line writeToFile:gLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

// ---------------- Chẩn đoán (ghi vào kho cài đặt cho trang Cài đặt đọc) ----------------
static long gBlockedRead = 0;
static long gBlockedTyping = 0;
static long gBlockedDelivered = 0;
static long gBlockedRecall = 0;
static NSString *gLastEvent = @"";
static NSTimeInterval gLastDiagWrite = 0;

static void ZUSWriteDiag(void) {
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_READ, (__bridge CFPropertyListRef)@(gBlockedRead), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_TYPE, (__bridge CFPropertyListRef)@(gBlockedTyping), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_DELIV, (__bridge CFPropertyListRef)@(gBlockedDelivered), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_BLOCKED_RECALL, (__bridge CFPropertyListRef)@(gBlockedRecall), (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)ZUS_DIAG_LAST, (__bridge CFPropertyListRef)gLastEvent, (__bridge CFStringRef)ZUS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
    gLastDiagWrite = [NSDate timeIntervalSinceReferenceDate];
    // 1.1.2: chụp thêm xuống file chung (tối đa 15 giây một lần) để mục
    // trạng thái dò ở trang Cài đặt của máy đọc được số thật.
    static NSTimeInterval sLastFileDiag = 0;
    if (gLastDiagWrite - sLastFileDiag >= 15.0) {
        sLastFileDiag = gLastDiagWrite;
        @synchronized (ZUSPrefsFileLock()) {
            NSMutableDictionary *fp = [ZUSReadFilePrefs() mutableCopy];
            if (!fp) fp = [NSMutableDictionary dictionary];
            fp[ZUS_DIAG_BLOCKED_READ] = @(gBlockedRead);
            fp[ZUS_DIAG_BLOCKED_TYPE] = @(gBlockedTyping);
            fp[ZUS_DIAG_BLOCKED_DELIV] = @(gBlockedDelivered);
            fp[ZUS_DIAG_BLOCKED_RECALL] = @(gBlockedRecall);
            fp[ZUS_DIAG_LAST] = gLastEvent;
            if (gJournal) fp[ZUS_KEY_JOURNAL] = gJournal;
            [fp writeToFile:ZUSSharedPrefsPath() atomically:YES];
        }
    }
}

static void ZUSWriteDiagThrottled(void) {
    if ([NSDate timeIntervalSinceReferenceDate] - gLastDiagWrite < 2.0) return;
    ZUSWriteDiag();
}

// ---------------- Kiểm tra kiểu dữ liệu ----------------
// Kiểu trả về an toàn cho hàm thay thế trả long long: void, BOOL, mọi số nguyên
// và mọi con trỏ/object đều về qua thanh ghi x0 (void thì nơi gọi bỏ qua x0),
// nên giá trị gốc được giữ nguyên bit khi chuyển tiếp, chặn thì trả 0.
// Loại trừ: float/double (về qua thanh ghi s/d riêng) và struct/mảng/hợp —
// cơ chế trả khác hẳn, gặp là bỏ qua cửa đó.
// Bài học từ log 1.0.5: hai hàm đang nhập trả về B và Q đã bị cổng cũ (chỉ nhận
// void) từ chối oan — đó là nguyên nhân thật của vụ từ chối ở 1.0.4, không phải
// các ký tự định tính như đã đoán trước đây.
static BOOL ZUSReturnTypeIsSafe(const char *enc) {
    if (!enc) return NO;
    char c = enc[0];
    if (c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V') c = enc[1];
    return (c == 'v' || c == 'B' || c == 'c' || c == 'C' || c == 's' || c == 'S' ||
            c == 'i' || c == 'I' || c == 'l' || c == 'L' || c == 'q' || c == 'Q' ||
            c == '@' || c == '#' || c == ':' || c == '*' || c == '^');
}

// Hàm thường (tối đa 2 tham số thật): kiểu trả về phải qua được cổng trên và
// mọi tham số đều là con trỏ/số nguyên (đi qua thanh ghi, chuyển tiếp an toàn).
static BOOL ZUSEncodingIsSafe(Method m) {
    const char *enc = method_getTypeEncoding(m);
    if (!ZUSReturnTypeIsSafe(enc)) return NO;
    unsigned argc = method_getNumberOfArguments(m);
    if (argc < 2 || argc > 4) return NO;
    for (unsigned i = 2; i < argc; i++) {
        char t[64];
        method_getArgumentType(m, i, t, sizeof(t));
        char c = t[0];
        // Bỏ qua ký tự định tính của mã kiểu (const/in/out/byref...) nếu nó đứng
        // đầu mã kiểu của tham số: chúng chỉ là chú thích, không ảnh hưởng thanh ghi.
        if (c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V') c = t[1];
        if (c == '@' || c == '#' || c == ':' || c == 'i' || c == 'I' || c == 's' || c == 'S' ||
            c == 'l' || c == 'L' || c == 'q' || c == 'Q' || c == 'c' || c == 'C' || c == 'B' ||
            c == '*' || c == '^') continue;
        return NO;
    }
    return YES;
}

// Hàm nhiều tham số (3–6): trên ARM64 tham số nguyên/con trỏ đều nằm trọn
// trong thanh ghi 64-bit nên chuyển tiếp theo từng ô nhớ là an toàn — với điều kiện
// mã kiểu KHÔNG chứa float/double/struct/mảng/hợp/bitfield. Quét toàn bộ chuỗi mã
// kiểu: chỉ cho phép các ký tự của kiểu nguyên/con trỏ/chữ ký số, cộng '?' của
// tham số block (@?) — hai cửa lớp dữ liệu có tham số hoàn-tất dạng block.
static BOOL ZUSEncodingIsSafeN(Method m, int n) {
    const char *enc = method_getTypeEncoding(m);
    if (!ZUSReturnTypeIsSafe(enc)) return NO;
    if (method_getNumberOfArguments(m) != (unsigned)(n + 2)) return NO;
    for (const char *p = enc; *p; p++) {
        char c = *p;
        if (c == 'v' || c == '@' || c == ':' || c == '#' || c == 'i' || c == 'I' ||
            c == 's' || c == 'S' || c == 'l' || c == 'L' || c == 'q' || c == 'Q' ||
            c == 'c' || c == 'C' || c == 'B' || c == '*' || c == '^' || c == '?' ||
            c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V' ||
            (c >= '0' && c <= '9')) continue;
        return NO;
    }
    return YES;
}


// ----- 1.3.1: tiện ích lớp — image của Zalo + tìm lớp theo tên cuối -----
// Log 1.3.0: các vòng dò liệt kê MỌI lớp trong tiến trình nên bị lớp hệ
// thống của Apple ngập (HomeKit / MediaPlayer / Photos / CallKit...),
// lớp của chính Zalo không tới lượt trong giới hạn log. Từ 1.3.1 mọi
// vòng dò chỉ xét lớp thuộc image của app Zalo (binary chính + các
// framework nhúng trong Zalo.app). Lớp Swift có tên runtime dạng
// "Module.Tên" nên việc tìm lớp phải so theo thành phần cuối sau dấu
// chấm — objc_getClass("TênTrần") trả nil với lớp Swift.
static BOOL ZUSClassIsZaloImage(Class cls) {
    if (!cls) return NO;
    const char *img = class_getImageName(cls);
    if (!img) return NO;
    NSString *p = @(img);
    return [p containsString:@"/Zalo.app/"] || [p hasSuffix:@"/Zalo"];
}

static NSString *ZUSClassShortName(Class cls) {
    NSString *n = NSStringFromClass(cls) ?: @"";
    NSRange r = [n rangeOfString:@"." options:NSBackwardsSearch];
    return (r.location != NSNotFound) ? [n substringFromIndex:r.location + 1] : n;
}

static void ZUSCollectClassesNamed(NSString *shortName, NSMutableArray *out) {
    unsigned cc = 0;
    Class *classes = objc_copyClassList(&cc);
    for (unsigned i = 0; i < cc; i++) {
        if ([ZUSClassShortName(classes[i]) isEqualToString:shortName]) [out addObject:classes[i]];
    }
    free(classes);
}

// ---------------- Kho bản gốc ----------------
static NSMutableDictionary *gOrigs = nil; // "khoá" -> IMP gốc
static NSMutableDictionary *gCats = nil;  // "khoá" -> nhóm (1/2)

static NSString *ZUSKeyFor(Class cls, SEL sel, BOOL isClass) {
    return [NSString stringWithFormat:@"%@%@|%@", isClass ? @"+" : @"-", NSStringFromClass(cls), NSStringFromSelector(sel)];
}

// Đi dọc chuỗi class cha để tìm bản gốc đã móc (self có thể là class con của class đã móc).
static NSMutableSet *gCalledOnce = nil; // khoá của các cửa đã ghi "lần đầu được gọi"

static void ZUSFindOrigCat(id self, SEL _cmd, void **outOrig, int *outCat, NSString **outKey) {
    *outOrig = NULL; *outCat = 0;
    if (outKey) *outKey = nil;
    BOOL meta = class_isMetaClass(object_getClass(self));
    Class walk = meta ? (Class)self : object_getClass(self);
    while (walk) {
        NSString *k = ZUSKeyFor(walk, _cmd, meta);
        NSValue *v = nil; NSNumber *c = nil;
        @synchronized (gOrigs) { v = gOrigs[k]; c = gCats[k]; }
        if (v) { *outOrig = [v pointerValue]; *outCat = [c intValue]; if (outKey) *outKey = k; return; }
        walk = class_getSuperclass(walk);
    }
}

// Ghi đúng một dòng cho lần đầu mỗi cửa thật sự được gọi trong phiên chạy này —
// bằng chứng cửa nào nằm trên luồng mở đoạn chat, kể cả khi cửa đó được chuyển tiếp.
static void ZUSNoteCalledOnce(id self, SEL _cmd, NSString *key) {
    if (!key || !gCalledOnce) return;
    BOOL first = NO;
    @synchronized (gCalledOnce) {
        if (![gCalledOnce containsObject:key]) { [gCalledOnce addObject:key]; first = YES; }
    }
    if (first) ZUSLog(@"lần đầu được gọi: %@.%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd));
}


// ----- 1.1.7: kho tin đã thu hồi -----
// Mỗi lần một cửa chống thu hồi chặn thành công, cất nội dung tin (văn
// bản / đường link media) vào kho trong prefs để xem lại ở tab Dữ liệu,
// kể cả khi đoạn chat gốc đã trôi. Tối đa 200 tin gần nhất.
static void ZUSVaultCapture(__unsafe_unretained id item) {
    @try {
        static NSArray *textKeys = nil;
        if (!textKeys) textKeys = @[@"content", @"text", @"message", @"messageText", @"title"];
        NSString *text = nil;
        for (NSString *k in textKeys) {
            id v = nil;
            @try { v = [item valueForKey:k]; } @catch (NSException *e) {}
            if ([v isKindOfClass:[NSString class]] && [v length]) { text = v; break; }
        }
        static NSArray *urlKeys = nil;
        if (!urlKeys) urlKeys = @[@"mediaURL", @"mediaUrl", @"url", @"link", @"originURL", @"originUrl", @"hdURL", @"hdUrl", @"fileURL", @"videoURL", @"videoUrl", @"photoURL", @"imageURL", @"imageUrl"];
        NSString *url = nil;
        for (NSString *k in urlKeys) {
            id v = nil;
            @try { v = [item valueForKey:k]; } @catch (NSException *e) {}
            if ([v isKindOfClass:[NSString class]] && [v hasPrefix:@"http"]) { url = v; break; }
            if ([v isKindOfClass:[NSURL class]]) { url = [(NSURL *)v absoluteString]; break; }
        }
        if (!text.length && !url.length) {
            static BOOL logged = NO;
            if (!logged) { logged = YES; ZUSLog(@"kho thu hồi: cửa thu hồi chạy nhưng chưa trích được nội dung từ %@ — kho chỉ cất được khi trích trúng", NSStringFromClass([item class])); }
            return;
        }
        // 1.3.0 chống trùng: vòng đồng bộ của Zalo chạy lại parser cho các
        // tin đã thu hồi cũ — bản 1.1.7 cất trùng tới 1.255 mục rác, đẩy tin
        // thu hồi thật trôi khỏi kho (giới hạn 200). Mỗi tin lấy một mã định
        // danh (nếu trích được) làm khoá trùng; không có mã thì dùng cặp
        // nội dung + link.
        static NSArray *idKeys = nil;
        if (!idKeys) idKeys = @[@"messageId", @"msgId", @"globalId", @"globalMsgId", @"msgGlobalId", @"clientId", @"messageID", @"id"];
        NSString *mid = nil;
        for (NSString *k in idKeys) {
            id v = nil;
            @try { v = [item valueForKey:k]; } @catch (NSException *e) {}
            if ([v isKindOfClass:[NSString class]] && [v length]) { mid = v; break; }
            if ([v isKindOfClass:[NSNumber class]]) { mid = [v stringValue]; break; }
        }
        // 1.3.1: URL media cua Zalo la URL ky ten (query key=/time= thay
        // moi lan cap lai) — khoa trung phai dung phan duong dan truoc
        // dau "?" thi moi nhan ra cung mot tin o cac lan parse sau.
        NSString *urlKey = url ?: @"";
        NSRange qr = [urlKey rangeOfString:@"?"];
        if (qr.location != NSNotFound) urlKey = [urlKey substringToIndex:qr.location];
        NSString *dkey = mid.length ? [@"id:" stringByAppendingString:mid]
                                    : [NSString stringWithFormat:@"tx:%@|%@", text ?: @"", urlKey];
        NSMutableArray *vault = [NSMutableArray array];
        id old = ZUSReadObject(ZUS_KEY_VAULT);
        if ([old isKindOfClass:[NSArray class]]) [vault addObjectsFromArray:old];
        for (NSDictionary *e in vault) {
            if ([e[@"dkey"] isEqualToString:dkey]) {
                static int dupLog = 0;
                if (dupLog++ < 5) ZUSLog(@"kho thu hồi: bỏ qua tin trùng (khoá %@)", dkey);
                return;
            }
        }
        NSDateFormatter *tf = [[NSDateFormatter alloc] init];
        tf.dateFormat = @"dd/MM HH:mm";
        [vault insertObject:@{@"time": [tf stringFromDate:[NSDate date]],
                              @"chat": gZUSCurrentThreadName ?: @"",
                              @"text": text ?: @"",
                              @"url": url ?: @"",
                              @"dkey": dkey} atIndex:0];
        while (vault.count > 200) [vault removeLastObject];
        ZUSWriteSharedValue(ZUS_KEY_VAULT, vault);
        ZUSLog(@"kho thu hồi: đã cất 1 tin (văn bản %lu ký tự, link %@, khoá %@)", (unsigned long)text.length, url.length ? @"có" : @"không", dkey.length > 60 ? [[dkey substringToIndex:60] stringByAppendingString:@"…"] : dkey);
    } @catch (NSException *e) {
        ZUSLog(@"kho thu hồi: lỗi cất tin: %@", e.name);
    }
}

static void ZUSNoteBlocked(id self, SEL _cmd, int cat) {
    NSString *desc = [NSString stringWithFormat:@"%@.%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    NSString *event = nil;
    // Các hàm bị móc chạy trên nhiều hàng đợi khác nhau (socket, model nhóm...):
    // bộ đếm và sự kiện gần nhất phải cập nhật trong khoá, tránh hai luồng cùng ghi.
    @synchronized (gOrigs) {
        if (cat == 1) { gBlockedRead++; gLastEvent = [NSString stringWithFormat:@"chặn đã-xem: %@", desc]; }
        else if (cat == 2) { gBlockedTyping++; gLastEvent = [NSString stringWithFormat:@"chặn đang-nhập: %@", desc]; }
        else if (cat == 3) { gBlockedDelivered++; gLastEvent = [NSString stringWithFormat:@"chặn đã-nhận: %@", desc]; }
        else { gBlockedRecall++; gLastEvent = [NSString stringWithFormat:@"chặn thu-hồi: %@", desc]; }
        event = gLastEvent;
    }
    ZUSLog(@"ĐÃ CHẶN %@", event);
    if (cat == 4) {
        // 1.3.0 lọc nhiễu kho: chỉ cất khi cửa bị chặn là một *TableItem —
        // nơi nội dung tin còn nằm trên đối tượng. Các cửa ở tầng điều phối
        // (MSDataCoordinator, processor) không mang nội dung tin.
        if ([NSStringFromClass(object_getClass(self)) containsString:@"TableItem"]) ZUSVaultCapture(self);
    }
    if (gJournal && gZUSCurrentThreadID.length) {
        @synchronized (gJournal) {
            static NSDateFormatter *dayFmt = nil;
            if (!dayFmt) { dayFmt = [[NSDateFormatter alloc] init]; dayFmt.dateFormat = @"yyyy-MM-dd"; }
            NSString *today = [dayFmt stringFromDate:[NSDate date]];
            NSMutableDictionary *entry = [gJournal[gZUSCurrentThreadID] mutableCopy];
            if (!entry || ![entry[@"day"] isEqualToString:today])
                entry = [@{@"name": gZUSCurrentThreadName ?: @"", @"day": today, @"seen": @0, @"typing": @0, @"delivered": @0, @"recall": @0} mutableCopy];
            NSString *k = ZUSCatKey(cat);
            if (k.length) entry[k] = @([entry[k] intValue] + 1);
            if (gZUSCurrentThreadName.length) entry[@"name"] = gZUSCurrentThreadName;
            gJournal[gZUSCurrentThreadID] = entry;
        }
    }
    ZUSWriteDiagThrottled();
}

// Nhóm của một cửa có đang bật hay không (1.1.0: 4 nhóm).
static BOOL ZUSActiveForCat(int cat) {
    if (!gEnabled) return NO;
    if (!gLicensed) return NO;
    if (cat != 4 && !ZUSScheduleActiveNow()) return NO;
    switch (cat) {
        case 1: return gUnseen;
        case 2: return gHideTyping;
        case 3: return gHideDelivered;
        case 4: return gAntiRecall;
        default: return NO;
    }
}

// Riêng nhóm đã-nhận: tắt công tắc đã-nhận thì các lần gọi THUẦN đã-nhận được
// đi qua, nhưng lần gọi nào mang cờ isSeen=YES (tham số thứ hai của cả 5 cửa
// delivered) vẫn bị chặn theo nhóm đã-xem — chống lọt đã-xem qua cửa hậu.
static BOOL ZUSActiveDelivered(BOOL isSeen) {
    if (!gEnabled) return NO;
    if (!gLicensed) return NO;
    if (!ZUSScheduleActiveNow()) return NO;
    if (gHideDelivered) return YES;
    return gUnseen && isSeen;
}


// Lịch giờ (anh yêu cầu: mặc định TẮT, không đặt sẵn — chỉ khi anh chủ
// động bật và đặt khung giờ mới có tác dụng). Ngoài khung giờ: các nhóm
// chặn 1–3 nằm im như tắt; chống thu hồi (nhóm 4) không bị lịch chi phối.
static BOOL ZUSScheduleActiveNow(void) {
    if (!gSchedEnabled) return YES;
    NSDateComponents *c = [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:[NSDate date]];
    int cur = (int)(c.hour * 60 + c.minute);
    if (gSchedFrom == gSchedTo) return YES;
    if (gSchedFrom < gSchedTo) return cur >= gSchedFrom && cur < gSchedTo;
    return cur >= gSchedFrom || cur < gSchedTo;
}

// Cửa thuộc tầng màn hình chat hay không — cài riêng theo đoạn chat chỉ áp
// ở tầng này (đúng đoạn đang mở); tầng socket/dữ liệu luôn theo cài chung.
static BOOL ZUSIsChatLayer(NSString *cn) {
    if (!cn) return NO;
    return [cn isEqualToString:@"BaseChatTVC"] || [cn isEqualToString:@"BaseChatProcessor"] ||
           [cn isEqualToString:@"ConversationModel"] || [cn isEqualToString:@"GroupConversationModel"] ||
           [cn containsString:@"ChatViewController"] || [cn containsString:@"ChatTVC"];
}

static NSString *ZUSCatKey(int cat) {
    switch (cat) {
        case 1: return @"seen";
        case 2: return @"typing";
        case 3: return @"delivered";
        case 4: return @"recall";
        default: return @"";
    }
}

// Quyết định chặn cho một lần gọi cụ thể: có cài riêng cho đoạn chat đang
// mở (Bật=luôn chặn / Tắt=luôn cho qua ở tầng màn hình chat) thì theo cài
// riêng; không có thì theo đường chung như cũ. Công tắc tổng vẫn là cổng
// trên cùng. Nhóm đã-nhận chạy ở tầng socket nên luôn theo cài chung.
static BOOL ZUSActiveForCall(int cat, __unsafe_unretained id self) {
    if ((cat == 1 || cat == 2 || cat == 4) && gZUSCurrentThreadID.length &&
        ZUSIsChatLayer(NSStringFromClass(object_getClass(self)))) {
        NSDictionary *per = gPerChat[gZUSCurrentThreadID];
        id v = per ? per[ZUSCatKey(cat)] : nil;
        if ([v isKindOfClass:[NSNumber class]]) {
            if (!gEnabled) return NO;
            return [v intValue] == 1;
        }
    }
    return ZUSActiveForCat(cat);
}

static NSString *ZUSCatLabel(int cat) {
    switch (cat) {
        case 1: return @"đã-xem";
        case 2: return @"đang-nhập";
        case 3: return @"đã-nhận";
        case 4: return @"thu-hồi";
        default: return @"?";
    }
}

// Hàm thay thế chung cho các hàm tối đa 2 tham số: bật tính năng thì chặn
// (không chạy gốc, trả 0), tắt thì chạy gốc và trả NGUYÊN giá trị gốc.
// Từ 1.0.6 mọi hàm thay thế trả long long: hàm đích trả số nguyên/BOOL/con trỏ
// đều về qua x0 nên giữ nguyên bit; hàm trả void thì nơi gọi bỏ qua x0.
// QUAN TRỌNG (gốc vụ văng 1.0.4): tham số PHẢI khai __unsafe_unretained.
// Khai `id` thường thì ARC coi chúng là strong và tự chèn objc_retain cho từng
// tham số ngay khi vào hàm — hàm đích nào có tham số là số nguyên (không phải
// object) sẽ bị retain như một địa chỉ bộ nhớ và sập ngay tại cửa, trước khi
// kịp chặn hay ghi log (đã chứng minh ở mức lệnh máy từ file .ips của 1.0.4).
static long long ZUSGenericHook(__unsafe_unretained id self, SEL _cmd, __unsafe_unretained id a1, __unsafe_unretained id a2) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    // Cờ isSeen nằm ở byte thấp của thanh ghi tham số thứ hai. PHẢI vòng qua
    // void* trước khi ép sang số nguyên: bít-mặt-nạ trực tiếp trên con trỏ id
    // là lỗi cứng -Wdeprecated-objc-pointer-introspection trên SDK mới nhất
    // (build đầu của ZUS 1.1.0 chết đúng dòng này). Dưới ARC, phép ép id ->
    // void* bắt buộc ghi (__bridge void*) — ép trần (void*) cũng là lỗi cứng.
    void *a2Raw = (__bridge void *)a2;
    BOOL active = (cat == 3) ? ZUSActiveDelivered(((uintptr_t)a2Raw & 0xFF) != 0) : ZUSActiveForCall(cat, self);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, __unsafe_unretained id, __unsafe_unretained id))orig)(self, _cmd, a1, a2);
    return 0;
}

// Hàm thay thế cho các hàm 5 tham số nguyên/con trỏ (sendStatusTyping trả về Q;
// từ 1.0.6 thêm cửa lớp dữ liệu 5 tham số thuộc nhóm đã-xem — điều kiện kích
// hoạt phải xét cả hai nhóm như các hàm thay thế khác, nếu chỉ xét nhóm
// đang-nhập như trước đây thì cửa đã-xem 5 tham số sẽ không bao giờ bị chặn).
static long long ZUSHook5(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3, void *a4, void *a5) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = ZUSActiveForCall(cat, self);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *, void *, void *))orig)(self, _cmd, a1, a2, a3, a4, a5);
    return 0;
}

// Hàm thay thế cho các hàm 3 tham số nguyên/con trỏ (cùng nguyên tắc thanh ghi).
static long long ZUSHook3(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = (cat == 3) ? ZUSActiveDelivered(((uintptr_t)a2 & 0xFF) != 0) : ZUSActiveForCall(cat, self);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *))orig)(self, _cmd, a1, a2, a3);
    return 0;
}

// Hàm thay thế cho các hàm 4 tham số nguyên/con trỏ (gửi đang nhập ở ChatDataManager).
static long long ZUSHook4(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3, void *a4) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = ZUSActiveForCall(cat, self);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *, void *))orig)(self, _cmd, a1, a2, a3, a4);
    return 0;
}

// Hàm thay thế cho các hàm 6 tham số nguyên/con trỏ (mới ở 1.0.6, cho cửa lớp
// dữ liệu InboxDataManager.processUpdateStatusInboxEntityThreadId:msgType:
// newStatus:seenTime:updateUI:updateDB:). 6 tham số thật vẫn nằm trọn trong
// thanh ghi x2–x7; từ 7 tham số trở lên tham số tràn xuống ngăn xếp nên KHÔNG
// dùng mẫu này — đó là lý do cửa 7 tham số của InboxDataManager tạm chưa móc.
static long long ZUSHook6(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3, void *a4, void *a5, void *a6) {
    void *orig = NULL; int cat = 0; NSString *key = nil;
    ZUSFindOrigCat(self, _cmd, &orig, &cat, &key);
    ZUSNoteCalledOnce(self, _cmd, key);
    BOOL active = ZUSActiveForCall(cat, self);
    if (active) { ZUSNoteBlocked(self, _cmd, cat); return 0; }
    if (orig) return ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *, void *, void *, void *))orig)(self, _cmd, a1, a2, a3, a4, a5, a6);
    return 0;
}

// ---------------- Danh sách trắng (log máy thật 1.0.3 + điểm móc ZaloTools đã kiểm chứng) ----------------
// cat: 1 = đã-xem, 2 = đang-nhập. argc = số tham số thật kỳ vọng (không tính self/_cmd).
typedef struct {
    const char *cls;
    const char *sel;
    int cat;
    int argc;
} ZUSEntry;

static const ZUSEntry kZUSWhitelist[] = {
    // Lớp màn hình chat: điểm phát sinh "đã xem" khi mở đoạn chat
    { "BaseChatTVC", "sendSeenInfoInboxEntity:", 1, 1 },
    { "BaseChatTVC", "sendSeenForLastReadMessage", 1, 0 },
    { "BaseChatTVC", "sendSeenMessageWithChatEntity:", 1, 1 },
    { "BaseChatTVC", "sendSeenMessageWithTalkTableItem:", 1, 1 },
    // Lớp xử lý chat
    { "BaseChatProcessor", "sendSeenMessages:messageDict:incomingData:", 1, 3 },
    // Lớp quản lý hàng đợi + gửi "đã xem" lên máy chủ
    { "ChatSendSeenDataManager", "sendSeenWithChatEntity:", 1, 1 },
    { "ChatSendSeenDataManager", "addChatSeenWithLastChatEntity:", 1, 1 },
    { "ChatSendSeenDataManager", "_sendSeenMessageWithSeenData:messageType:", 1, 2 },
    { "ChatSendSeenDataManager", "sendSeenLastMessageWithThreadIds:withMessageType:", 1, 2 },
    { "ChatSendSeenDataManager", "sendSeenServer", 1, 0 },
    { "ChatSendSeenDataManager", "forceSendSeenServer", 1, 0 },
    { "ChatSendSeenDataManager", "sendSeenServerPeriodicallyIfNeeded", 1, 0 },
    { "ChatSendSeenDataManager", "sendAllFailedSeenMessage", 1, 0 },
    // Lớp socket: xác nhận đã nhận/đã xem đi thẳng ra đường truyền
    { "ChatSocketCmdHelper", "sendSeenChatACK:withSubCommandType:", 1, 2 },
    { "ChatSocketCmdHelper", "sendSeenGroupChatACKByData:withSubCommandType:", 1, 2 },
    { "ChatSocketCmdHelper", "sendSingleChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendE2eeSingleChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendGroupChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendE2eeGroupChatDeliveredMessages:isSeen:", 3, 2 },
    { "ChatSocketCmdHelper", "sendChatDeliveredMessages:isSeen:commandType:", 3, 3 },
    // Lớp cập nhật trạng thái đã xem ngay trong máy (giữ chữ đậm trong danh sách chat)
    { "ConversationModel", "updateLastSeenWithMessage:type:", 1, 2 },
    { "ConversationModel", "_updateLastSeenWithMessage:type:", 1, 2 },
    { "ConversationModel", "updateLocalLastSeenMessageWithDelay", 1, 0 },
    { "ConversationModel", "clearMentionAndUpdateLastSeenWithDelay:", 1, 1 },
    { "ConversationModel", "setLastSeenObject:", 1, 1 },
    // Story: cập nhật trạng thái đã xem Story (tên hàm trong chính bản Zalo
    // của máy, log 1.0.3) — đi theo nhóm đã-xem.
    { "StoryManager", "updateSeenStoryStatus:", 1, 1 },
    { "StoryEntity", "updateSeen:", 1, 1 },
    // Lớp dữ liệu: ghi trạng thái đã xem thẳng vào giao diện + cơ sở dữ liệu —
    // đường rò mà log 1.0.5 đã chứng minh (cả 25 cửa trên đều chặn mà chữ vẫn
    // mất đậm). Tên hàm lấy từ danh sách ứng viên trong chính bản Zalo của máy
    // (log 1.0.3). Cửa InboxDataManager 7 tham số (processUpdateStatusInbox-
    // EntityForThreadId:globalId:clientId:messageType:newStatus:updateUI:
    // updateDB:) tạm chưa móc — xem ghi chú ở ZUSHook6.
    { "ChatDataManager", "processUpdateStatusChatSeenChatGroup:withNewStatusSeen:withUI:withDB:", 1, 4 },
    { "ChatDataFlow", "processUpdateStatusSeenChatGroup:withNewStatusSeen:withUI:withDB:", 1, 4 },
    { "InboxDataManager", "processUpdateStatusInboxEntityThreadId:msgType:withNewStatus:withUI:withDB:", 1, 5 },
    { "InboxDataManager", "processUpdateStatusInboxEntityThreadId:msgType:newStatus:seenTime:updateUI:updateDB:", 1, 6 },
    { "InboxDataManager", "processDecreaseUnreadOfThread:withType:shouldUpdateDB:shouldUpdateUI:", 1, 4 },
    { "ChatProcessor", "processResetUnreadWithSeenData:msgType:withCompletion:", 1, 3 },
    { "ChatProcessor", "processResetUnreadOfThread:msgType:msgMarker:", 1, 3 },
    { "ChatDataManager", "updateMaxSeenGlobalId:withMessageType:withCompletion:", 1, 3 },
    { "ChatDataManager", "checkSendClearUnreadType:withInboxEntity:messageType:withToUserId:", 1, 4 },
    // Chống thu hồi: chuỗi xử lý "undo" của Zalo — điểm móc lấy từ dylib của
    // ZaloTools (BVN) nhắm đúng thế hệ Zalo này (ký hiệu Logos trong dylib ghi
    // đủ class + selector + số tham số; hai mục ChatUIManager và một mục
    // UndoChatProcessor là HÀM CLASS, bộ lắp móc tự nhận diện qua metaclass).
    { "MSDataCoordinator", "handleRecallMessageNotification:", 4, 1 },
    { "MSDataCoordinator", "_handleRecallWithData:", 4, 1 },
    { "UndoChatProcessor", "updateDBUndoWithChatEntity:undoGlobalId:undoClientId:fromSrc:completion:", 4, 5 },
    { "ChatUIManager", "processUndoWithSocketChatEntity:", 4, 1 },
    { "ChatUIManager", "handleUpdateUndoWithChatEntity:fromSrc:shouldDeleteMsg:shouldRemovePage:completion:", 4, 5 },
    { "ChatEntity", "preprocessMessageUndo", 4, 0 },
    { "TalkTableItem", "updateUndoWithParser:", 4, 1 },
    // Lớp gửi "đang nhập..."
    { "ChatDataManager", "sendTypingWithType:toUserId:messageType:isE2eeChat:", 2, 4 },
    { "ChatSocketCmdHelper", "sendStatusTyping:withCommand:withSubCommand:withDestType:withGlobalMessageId:", 2, 5 },
};
static const unsigned kZUSWhitelistCount = sizeof(kZUSWhitelist) / sizeof(kZUSWhitelist[0]);

static long gHookedTotal = 0;

// ===== Cửa seenTime: móc RIÊNG đúng kiểu (1.1.3 bổ sung) =====
// InboxDataManager.processUpdateStatus…seenTime:… có tham số double nên bộ
// móc chung bị cổng an toàn từ chối ở mọi bản trước: cửa này không để lại
// dòng log nào và không bị chặn — đúng triệu chứng "đang mở sẵn đoạn chat,
// tin mới tới thì bị seen" mà anh gặp. Hàm thay thế khai ĐÚNG chữ ký gốc
// (double đi qua nguyên vẹn khi chuyển tiếp). Chặn khi nhóm đã-xem đang
// bật VÀ lần gọi mang mốc seenTime > 0; 10 lần gọi đầu ghi lại giá trị
// (status/seenTime/UI/DB + quyết định) để đối chiếu trên máy thật.
typedef void (*ZUSSeenTimeIMP)(__unsafe_unretained id, SEL, __unsafe_unretained id, long long, unsigned long long, double, BOOL, BOOL);
static ZUSSeenTimeIMP gZUSOrigSeenTime = NULL;
static int gZUSSeenTimeCalls = 0;

static void ZUSSeenTimeHook(__unsafe_unretained id self, SEL _cmd, __unsafe_unretained id threadId, long long msgType, unsigned long long newStatus, double seenTime, BOOL updateUI, BOOL updateDB) {
    BOOL block = ZUSActiveForCat(1) && seenTime > 0;
    if (gZUSSeenTimeCalls < 10) {
        gZUSSeenTimeCalls++;
        ZUSLog(@"cửa seenTime gọi lần %d: status=%llu seenTime=%.0f UI=%d DB=%d -> %@", gZUSSeenTimeCalls, newStatus, seenTime, updateUI, updateDB, block ? @"CHẶN" : @"cho qua");
    }
    if (block) {
        ZUSNoteBlocked(self, _cmd, 1);
        return;
    }
    if (gZUSOrigSeenTime) gZUSOrigSeenTime(self, _cmd, threadId, msgType, newStatus, seenTime, updateUI, updateDB);
}

static void ZUSInstallSeenTimeHook(Class cls, Method m, BOOL isClass) {
    if (gZUSOrigSeenTime) return;
    SEL sel = method_getName(m);
    Class target = isClass ? object_getClass(cls) : cls;
    void *orig = NULL;
    MSHookMessageEx(target, sel, (IMP)ZUSSeenTimeHook, (IMP *)&orig);
    if (!orig) {
        ZUSLog(@"móc HỎNG: %@ %@", NSStringFromClass(cls), NSStringFromSelector(sel));
        return;
    }
    gZUSOrigSeenTime = (ZUSSeenTimeIMP)orig;
    gHookedTotal++;
    ZUSLog(@"đã móc [đã-xem] %@.%@ enc=%s (móc riêng đúng kiểu — có tham số double)", NSStringFromClass(cls), NSStringFromSelector(sel), method_getTypeEncoding(m));
}

// ---------------- Lắp móc theo danh sách ----------------

static void ZUSInstallHook(Class cls, Method m, BOOL isClass, int cat, IMP repl) {
    SEL sel = method_getName(m);
    NSString *key = ZUSKeyFor(cls, sel, isClass);
    @synchronized (gOrigs) { if (gOrigs[key]) return; }
    Class target = isClass ? object_getClass(cls) : cls;
    void *orig = NULL;
    MSHookMessageEx(target, sel, repl, (IMP *)&orig);
    if (!orig) {
        ZUSLog(@"móc HỎNG: %@ %@", NSStringFromClass(cls), NSStringFromSelector(sel));
        return;
    }
    @synchronized (gOrigs) {
        gOrigs[key] = [NSValue valueWithPointer:orig];
        gCats[key] = @(cat);
    }
    gHookedTotal++;
    ZUSLog(@"đã móc [%@] %@.%@ enc=%s", ZUSCatLabel(cat), NSStringFromClass(cls), NSStringFromSelector(sel), method_getTypeEncoding(m));
}

static void ZUSInstallWhitelist(void) {
    for (unsigned i = 0; i < kZUSWhitelistCount; i++) {
        const ZUSEntry *e = &kZUSWhitelist[i];
        Class cls = objc_getClass(e->cls);
        if (!cls) {
            ZUSLog(@"chưa thấy class %s (mục %s)", e->cls, e->sel);
            continue;
        }
        SEL sel = sel_registerName(e->sel);
        Method m = class_getInstanceMethod(cls, sel);
        BOOL isClass = NO;
        if (!m) { m = class_getClassMethod(cls, sel); isClass = YES; }
        if (!m) {
            ZUSLog(@"không thấy hàm %s.%s", e->cls, e->sel);
            continue;
        }
        if ((int)method_getNumberOfArguments(m) - 2 != e->argc) {
            ZUSLog(@"bỏ qua (số tham số khác kỳ vọng): %s.%s", e->cls, e->sel);
            continue;
        }
        if (e->argc == 6 && strcmp(e->cls, "InboxDataManager") == 0 &&
            strcmp(e->sel, "processUpdateStatusInboxEntityThreadId:msgType:newStatus:seenTime:updateUI:updateDB:") == 0) {
            ZUSInstallSeenTimeHook(cls, m, isClass);
            continue;
        }
        BOOL safe; IMP repl;
        if (e->argc <= 2)      { safe = ZUSEncodingIsSafe(m);        repl = (IMP)ZUSGenericHook; }
        else if (e->argc == 3) { safe = ZUSEncodingIsSafeN(m, 3);    repl = (IMP)ZUSHook3; }
        else if (e->argc == 4) { safe = ZUSEncodingIsSafeN(m, 4);    repl = (IMP)ZUSHook4; }
        else if (e->argc == 5) { safe = ZUSEncodingIsSafeN(m, 5);    repl = (IMP)ZUSHook5; }
        else                   { safe = ZUSEncodingIsSafeN(m, 6);    repl = (IMP)ZUSHook6; }
        if (!safe) {
            ZUSLog(@"bỏ qua (kiểu dữ liệu không an toàn): %s.%s enc=%s", e->cls, e->sel, method_getTypeEncoding(m));
            continue;
        }
        ZUSInstallHook(cls, m, isClass, e->cat, repl);
    }
    ZUSLog(@"danh sách trắng: %u mục, đã móc tổng %ld", kZUSWhitelistCount, gHookedTotal);
    ZUSWriteSharedValue(ZUS_DIAG_CANDIDATES, @(kZUSWhitelistCount));
    ZUSWriteSharedValue(ZUS_DIAG_HOOKED, @(gHookedTotal));
    ZUSWriteSharedValue(ZUS_DIAG_SKIPPED, @((long)kZUSWhitelistCount - gHookedTotal));
    ZUSWriteSharedValue(ZUS_DIAG_SCAN, [gLogFmt stringFromDate:[NSDate date]]);
    ZUSWriteDiag();
}


// ---------------- Tính năng thêm (1.1.0 chính thức) ----------------
// Toàn bộ phần này tách rời khỏi machinery chặn: mỗi món có công tắc riêng,
// mặc định TẮT (trừ khi ghi chú khác), hỏng thì chỉ hỏng phần đó.

static NSString *ZUSReadString(NSString *key) {
    id fv = ZUSReadFilePrefs()[key];
    if ([fv isKindOfClass:[NSString class]]) return fv;
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    if (!v) return nil;
    NSString *r = nil;
    if (CFGetTypeID(v) == CFStringGetTypeID()) r = [(__bridge NSString *)v copy];
    CFRelease(v);
    return r;
}

static NSString *ZUSDocsPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

// ----- Tải Story về máy: cho Zalo tự hiện nút lưu của chính nó -----
static BOOL (*gOrigStoryCanDownload)(__unsafe_unretained id, SEL) = NULL;
static BOOL gStoryInstalled = NO;

static BOOL ZUSStoryCanDownload(__unsafe_unretained id self, SEL _cmd) {
    if (gEnabled && gStoryDownload) return YES;
    if (gOrigStoryCanDownload) return gOrigStoryCanDownload(self, _cmd);
    return NO;
}

static void ZUSInstallStoryDownload(void) {
    if (gStoryInstalled) return;
    SEL sel = sel_registerName("isAllowDownloadCurrentStory");
    NSArray *cands = @[@"UXStoryMediaViewController", @"UXStoryMediaPage", @"UXStoryMediaObject"];
    for (NSString *name in cands) {
        Class cls = objc_getClass(name.UTF8String);
        if (!cls) continue;
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) continue;
        if (!ZUSEncodingIsSafe(m)) { ZUSLog(@"tải Story: bỏ qua %@ (kiểu dữ liệu không an toàn)", name); continue; }
        MSHookMessageEx(cls, sel, (IMP)ZUSStoryCanDownload, (IMP *)&gOrigStoryCanDownload);
        if (gOrigStoryCanDownload) { gStoryInstalled = YES; ZUSLog(@"đã lắp tính năng tải Story trên %@", name); return; }
    }
    ZUSLog(@"tải Story: không thấy cửa isAllowDownloadCurrentStory trên lớp Story nào");
}

// ----- Màn chắn riêng tư khi rời tiền cảnh -----
static void ZUSShieldSet(BOOL show) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSSet *scenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in scenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in [(UIWindowScene *)scene windows]) {
                UIView *old = [w viewWithTag:23126];
                if (show) {
                    if (old) { [w bringSubviewToFront:old]; continue; }
                    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
                    blur.frame = w.bounds;
                    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    blur.tag = 23126;
                    [w addSubview:blur];
                } else {
                    [old removeFromSuperview];
                }
            }
        }
    });
}

static void ZUSInstallShieldObservers(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (gEnabled && gPrivacyShield) ZUSShieldSet(YES);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        ZUSShieldSet(NO);
    }];
}

// ----- Cảnh báo khi Zalo đổi phiên bản -----
static void ZUSCheckZaloVersion(void) {
    NSString *cur = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!cur.length) return;
    NSString *last = ZUSReadString(ZUS_KEY_ZALOVER);
    if (last.length && ![last isEqualToString:cur]) {
        ZUSLog(@"Zalo vừa đổi phiên bản: %@ -> %@ — nếu có tính năng lạ, gửi log để kiểm tra lại cửa móc", last, cur);
        ZUSWriteSharedValue(ZUS_DIAG_ZALOUPD, cur);
        CFPreferencesAppSynchronize((__bridge CFStringRef)ZUS_DOMAIN);
    }
    if (![last isEqualToString:cur]) {
        ZUSWriteSharedValue(ZUS_KEY_ZALOVER, cur);
    }
}

// ----- Danh bạ: dò nguồn bạn bè trong Zalo -----
// Chưa có bản đồ lớp bạn bè của Zalo (log 1.0.3 chỉ quét luồng đã-xem), nên
// bản đầu đi đường DÒ CÓ KIỂM SOÁT: thử danh sách lớp quản lý + tên hàm lấy
// bạn bè quen thuộc, đọc trường bằng KVC với danh sách khoá ứng viên, và ghi
// log toàn bộ những gì tìm thấy. Dò không ra thì log chứa bản đồ hàm "friend"
// của các lớp ứng viên để vòng sau chốt đúng nguồn — cùng cách đã crack
// luồng đã-xem ở 1.0.5/1.0.6.
static id ZUSInstanceOf(Class cls) {
    if (!cls) return nil;
    NSArray *sels = @[@"sharedInstance", @"sharedManager", @"defaultManager", @"shared", @"defaultInstance", @"manager", @"sharedCoordinator", @"defaultCoordinator", @"coordinator", @"sharedCenter", @"defaultCenter", @"center", @"sharedDataManager", @"dataManager", @"main", @"current"];
    for (NSString *s in sels) {
        SEL sel = sel_registerName(s.UTF8String);
        if (!class_getClassMethod(cls, sel)) continue;
        @try {
            id inst = ((id (*)(id, SEL))objc_msgSend)(cls, sel);
            if (inst) return inst;
        } @catch (NSException *e) {}
    }
    return nil;
}

static NSString *ZUSStringField(id obj, NSArray *keys) {
    for (NSString *k in keys) {
        @try {
            id v = [obj valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) return v;
            if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
            if ([v isKindOfClass:[NSURL class]]) return [(NSURL *)v absoluteString];
        } @catch (NSException *e) {}
    }
    return @"";
}

// ===== Vòng 3: bắt thực thể quản lý bạn bè qua hàm khởi tạo =====
// Log 1.1.2 đã chứng minh: FriendFlowManager không có accessor tĩnh thường
// gặp, ChatDataManager không giữ nó qua KVC (quan hệ ngược). Đường tin cậy
// nhất còn lại: móc các hàm init của FriendFlowManager và MSDataCoordinator
// ngay từ lúc tweak nạp — Zalo tạo thực thể lúc nào, thực thể được giữ yếu
// ở đây lúc đó. Các thay thế chỉ gọi bản gốc rồi ghi lại, không đổi hành vi.
static __weak id gZUSCapFFM = nil;
static __weak id gZUSCapCoord = nil;
static BOOL gZUSCapFFMLogged = NO;
static BOOL gZUSCapCoordLogged = NO;

static void ZUSCaptureInstance(BOOL isFFM, __unsafe_unretained id obj) {
    if (!obj) return;
    if (isFFM) {
        if (gZUSCapFFM != obj) {
            gZUSCapFFM = obj;
            if (!gZUSCapFFMLogged) { gZUSCapFFMLogged = YES; ZUSLog(@"danh bạ: đã bắt được thực thể FriendFlowManager qua hàm khởi tạo"); }
        }
    } else {
        if (gZUSCapCoord != obj) {
            gZUSCapCoord = obj;
            if (!gZUSCapCoordLogged) { gZUSCapCoordLogged = YES; ZUSLog(@"danh bạ: đã bắt được thực thể MSDataCoordinator qua hàm khởi tạo"); }
        }
    }
}

typedef id (*ZUSInitIMP0)(__unsafe_unretained id, SEL);
typedef id (*ZUSInitIMP1)(__unsafe_unretained id, SEL, void *);
static ZUSInitIMP0 gZUSOrigFFMInit0 = NULL;
static ZUSInitIMP0 gZUSOrigCoordInit0 = NULL;
static ZUSInitIMP1 gZUSOrigFFMInit1 = NULL;
static ZUSInitIMP1 gZUSOrigCoordInit1 = NULL;

static id ZUSCapFFMInit0(__unsafe_unretained id self, SEL _cmd) { id r = gZUSOrigFFMInit0 ? gZUSOrigFFMInit0(self, _cmd) : self; ZUSCaptureInstance(YES, r); return r; }
static id ZUSCapCoordInit0(__unsafe_unretained id self, SEL _cmd) { id r = gZUSOrigCoordInit0 ? gZUSOrigCoordInit0(self, _cmd) : self; ZUSCaptureInstance(NO, r); return r; }
static id ZUSCapFFMInit1(__unsafe_unretained id self, SEL _cmd, void *a1) { id r = gZUSOrigFFMInit1 ? gZUSOrigFFMInit1(self, _cmd, a1) : self; ZUSCaptureInstance(YES, r); return r; }
static id ZUSCapCoordInit1(__unsafe_unretained id self, SEL _cmd, void *a1) { id r = gZUSOrigCoordInit1 ? gZUSOrigCoordInit1(self, _cmd, a1) : self; ZUSCaptureInstance(NO, r); return r; }

static void ZUSHookInitsForClass(Class cls, BOOL isFFM) {
    if (!cls) { ZUSLog(@"danh bạ: không thấy lớp %@ để móc init", isFFM ? @"FriendFlowManager" : @"MSDataCoordinator"); return; }
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray *names = [NSMutableArray array];
    BOOL hooked0 = NO, hooked1 = NO;
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);
        if (![name hasPrefix:@"init"]) continue;
        [names addObject:name];
        const char *enc = method_getTypeEncoding(methods[i]);
        if (!enc || (enc[0] != '@' && enc[0] != '#')) continue;
        if (strchr(enc, '{') || strchr(enc, '(') || strchr(enc, '[')) continue;
        unsigned nargs = method_getNumberOfArguments(methods[i]);
        if (nargs == 2 && !hooked0) {
            if (isFFM) MSHookMessageEx(cls, sel, (IMP)ZUSCapFFMInit0, (IMP *)&gZUSOrigFFMInit0);
            else MSHookMessageEx(cls, sel, (IMP)ZUSCapCoordInit0, (IMP *)&gZUSOrigCoordInit0);
            hooked0 = YES;
        } else if (nargs == 3 && !hooked1) {
            if (isFFM) MSHookMessageEx(cls, sel, (IMP)ZUSCapFFMInit1, (IMP *)&gZUSOrigFFMInit1);
            else MSHookMessageEx(cls, sel, (IMP)ZUSCapCoordInit1, (IMP *)&gZUSOrigCoordInit1);
            hooked1 = YES;
        }
    }
    if (methods) free(methods);
    if (!hooked0 && !names.count) {
        // Lớp không khai init riêng: móc -init thừa kế, chỉ áp cho lớp này.
        SEL sel = @selector(init);
        if (isFFM) { MSHookMessageEx(cls, sel, (IMP)ZUSCapFFMInit0, (IMP *)&gZUSOrigFFMInit0); hooked0 = YES; }
        else { MSHookMessageEx(cls, sel, (IMP)ZUSCapCoordInit0, (IMP *)&gZUSOrigCoordInit0); hooked0 = YES; }
    }
    ZUSLog(@"danh bạ: %@ — các hàm init: %@; đã móc bắt thực thể: %@",
           NSStringFromClass(cls),
           names.count ? [names componentsJoinedByString:@", "] : @"(không có init riêng)",
           (hooked0 || hooked1) ? @"có" : @"không");
}

static void ZUSInstallCaptureHooks(void) {
    ZUSHookInitsForClass(objc_getClass("FriendFlowManager"), YES);
    ZUSHookInitsForClass(objc_getClass("MSDataCoordinator"), NO);
}

// Dump tên + lớp của các thuộc tính CÓ giá trị của một thực thể (mỗi lớp một
// lần) — để tìm khoá giữ FriendFlowManager bên trong MSDataCoordinator.
static void ZUSDiagDumpProperties(__unsafe_unretained id obj, NSString *label) {
    if (!obj) return;
    static NSMutableSet *done = nil;
    if (!done) done = [NSMutableSet set];
    NSString *cn = NSStringFromClass([obj class]);
    if ([done containsObject:cn]) return;
    [done addObject:cn];
    unsigned int count = 0;
    objc_property_t *props = class_copyPropertyList([obj class], &count);
    NSMutableArray *parts = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        NSString *pn = @(property_getName(props[i]));
        id v = nil;
        @try { v = [obj valueForKey:pn]; } @catch (NSException *e) {}
        if (v) [parts addObject:[NSString stringWithFormat:@"%@=%@", pn, NSStringFromClass([v class])]];
        if (parts.count >= 40) break;
    }
    if (props) free(props);
    ZUSLog(@"danh bạ: thuộc tính có giá trị của %@: %@", label, [parts componentsJoinedByString:@", "]);
}

static NSDictionary *ZUSFriendDict(id f) {
    // 1.1.4: tên trường THẬT của BuddyEntity là chữ thường (log 1.1.3 đã
    // dump đủ): displayname, zaloid, userid, avatarurl, contactname,
    // mobile. Danh sách cũ dùng camelCase nên KVC không chạm được trường
    // nào — lấy được 266 bạn mà trích ra toàn rỗng.
    NSString *name = ZUSStringField(f, @[@"displayname", @"contactname", @"displayName", @"name", @"fullName", @"zaloName", @"newusername", @"username"]);
    NSString *fid  = ZUSStringField(f, @[@"zaloid", @"userid", @"zaloId", @"userId", @"uid", @"userID", @"friendId", @"id"]);
    NSString *phone = ZUSStringField(f, @[@"mobile", @"phoneNumber", @"phone", @"mobileNumber", @"_rawPhonenumber", @"rawPhonenumber"]);
    NSString *avatar = ZUSStringField(f, @[@"avatarurl", @"bgavatarurl", @"avatarURL", @"avatarUrl", @"avatar", @"avatarPath", @"avatarLink"]);
    return @{@"name": name, @"id": fid, @"phone": phone, @"avatar": avatar};
}

static NSArray *ZUSFriendsFromManager(id inst, NSString *srcName) {
    if (!inst) return nil;
    NSArray *listSels = @[@"cloneFriendList", @"copySortedFriendsArray", @"copySortedNonBlockedFriendsArray", @"copyNonBlockedFriendsDictionary", @"copyZaloContactNewFriendDictionary", @"nonBlockedFriendSortedArray", @"getNewFriendArray", @"friendList", @"allFriends", @"friends", @"getFriendList", @"getAllFriends", @"listFriends", @"getFriends", @"friendArray", @"allContacts", @"contacts"];
    for (NSString *sn in listSels) {
        SEL sel = sel_registerName(sn.UTF8String);
        if (![inst respondsToSelector:sel]) continue;
        @try {
            id r = ((id (*)(id, SEL))objc_msgSend)(inst, sel);
            NSArray *arr = nil;
            if ([r isKindOfClass:[NSArray class]]) arr = r;
            else if ([r isKindOfClass:[NSSet class]]) arr = [(NSSet *)r allObjects];
            else if ([r isKindOfClass:[NSDictionary class]]) {
                NSMutableArray *flat = [NSMutableArray array];
                for (id v in [(NSDictionary *)r allValues]) {
                    if ([v isKindOfClass:[NSArray class]]) [flat addObjectsFromArray:v];
                    else if ([v isKindOfClass:[NSSet class]]) [flat addObjectsFromArray:[(NSSet *)v allObjects]];
                    else [flat addObject:v];
                }
                arr = flat;
            }
            if (arr.count) {
                ZUSLog(@"danh bạ: lấy được %lu bạn từ %@.%@", (unsigned long)arr.count, srcName, sn);
                ZUSWriteSharedValue(ZUS_DIAG_FRIENDSRC, [NSString stringWithFormat:@"%@.%@", srcName, sn]);
                return arr;
            }
            if (r) ZUSLog(@"danh bạ: %@.%@ có tồn tại nhưng trả về %@ (rỗng hoặc chưa sẵn sàng)", srcName, sn, NSStringFromClass([r class]));
        } @catch (NSException *e) {}
    }
    return nil;
}

static NSArray *ZUSCollectFriends(void) {
    // Vòng 3 (1.1.3): bám thực thể BẮT ĐƯỢC qua init trước (tin cậy nhất),
    // rồi accessor tĩnh nới rộng, rồi MSDataCoordinator (dump thuộc tính +
    // KVC nhiều khoá), cuối cùng mới là các đường cũ của vòng 1–2.
    Class ffmCls = objc_getClass("FriendFlowManager");
    if (gZUSCapFFM) {
        NSArray *r = ZUSFriendsFromManager(gZUSCapFFM, @"FriendFlowManager(bắt qua init)");
        if (r) return r;
    }
    if (ffmCls) {
        id inst = ZUSInstanceOf(ffmCls);
        if (inst) {
            NSArray *r = ZUSFriendsFromManager(inst, @"FriendFlowManager");
            if (r) return r;
        } else {
            ZUSLog(@"danh bạ: không lấy được thực thể FriendFlowManager qua các hàm shared thường gặp");
        }
    }
    Class coordCls = objc_getClass("MSDataCoordinator");
    id coord = gZUSCapCoord;
    if (!coord && coordCls) coord = ZUSInstanceOf(coordCls);
    if (coord) {
        ZUSDiagDumpProperties(coord, @"MSDataCoordinator");
        for (NSString *key in @[@"friendFlowManager", @"friendManager", @"friendFlowMgr", @"friendMgr", @"flowManager", @"friendFlow", @"ffManager", @"friendsManager"]) {
            id sub = nil;
            @try { sub = [coord valueForKey:key]; } @catch (NSException *e) {}
            if (sub) {
                NSArray *r = ZUSFriendsFromManager(sub, [@"MSDataCoordinator." stringByAppendingString:key]);
                if (r) return r;
            }
        }
        NSArray *r = ZUSFriendsFromManager(coord, @"MSDataCoordinator");
        if (r) return r;
    }
    for (NSString *hostName in @[@"ChatDataManager", @"MSDataCoordinator"]) {
        Class hostCls = objc_getClass(hostName.UTF8String);
        if (!hostCls) continue;
        id host = ZUSInstanceOf(hostCls);
        if (!host) continue;
        id ffm = nil;
        @try { ffm = [host valueForKey:@"friendFlowManager"]; } @catch (NSException *e) {}
        if (!ffm) { @try { ffm = [host valueForKey:@"friendManager"]; } @catch (NSException *e) {} }
        if (ffm) {
            NSArray *r = ZUSFriendsFromManager(ffm, [hostName stringByAppendingString:@".friendFlowManager"]);
            if (r) return r;
        } else {
            ZUSLog(@"danh bạ: %@ không lộ friendFlowManager qua KVC", hostName);
        }
    }
    // Dự phòng: quét chung các lớp quản lý như vòng 1.
    NSArray *classNames = @[@"FriendDataManager", @"FriendFlowManager", @"FriendRequestManager", @"FriendManager", @"ZAFriendManager", @"MSDataCoordinator", @"ChatDataManager"];
    for (NSString *cn in classNames) {
        Class cls = objc_getClass(cn.UTF8String);
        if (!cls) continue;
        id inst = ZUSInstanceOf(cls);
        if (!inst) continue;
        NSArray *r = ZUSFriendsFromManager(inst, cn);
        if (r) return r;
    }
    ZUSLog(@"danh bạ: chưa dò được nguồn bạn bè — bản đồ hàm friend của các lớp ứng viên:");
    for (NSString *cn in classNames) {
        Class cls = objc_getClass(cn.UTF8String);
        if (!cls) continue;
        unsigned n = 0; Method *list = class_copyMethodList(cls, &n);
        NSMutableArray *names = [NSMutableArray array];
        for (unsigned i = 0; i < n; i++) {
            NSString *mn = NSStringFromSelector(method_getName(list[i]));
            if ([mn.lowercaseString containsString:@"friend"]) [names addObject:mn];
        }
        free(list);
        if (names.count) ZUSLog(@"danh bạ: %@ có các hàm friend: %@", cn, [names componentsJoinedByString:@", "]);
    }
    // Bản đồ hàm LỚP (nơi accessor tĩnh thật sự sống) của hai lớp trọng điểm.
    for (NSString *cn in @[@"FriendFlowManager", @"MSDataCoordinator"]) {
        Class cls = objc_getClass(cn.UTF8String);
        if (!cls) continue;
        unsigned n = 0; Method *list = class_copyMethodList(object_getClass(cls), &n);
        NSMutableArray *names = [NSMutableArray array];
        for (unsigned i = 0; i < n; i++) [names addObject:NSStringFromSelector(method_getName(list[i]))];
        free(list);
        if (names.count) ZUSLog(@"danh bạ: hàm lớp của %@: %@", cn, [names componentsJoinedByString:@", "]);
    }
    return nil;
}

static NSString *ZUSCSVEscape(NSString *s) {
    if (![s containsString:@","] && ![s containsString:@"\""] && ![s containsString:@"\n"]) return s;
    return [NSString stringWithFormat:@"\"%@\"", [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
}

static NSArray *gZUSLastBackupFiles = nil;

// ----- 1.3.0: theo dõi thay đổi bạn bè -----
// Mỗi lần sao lưu danh bạ, đối chiếu với mốc gần nhất: ai biến mất khỏi
// danh sách, ai mới xuất hiện, ai đổi tên / ảnh đại diện. Kết quả cộng dồn
// vào khoá friendChanges để xem lại ở tab Dữ liệu; mốc cập nhật sau mỗi
// lần đối chiếu. Link avatar được so sau khi bỏ phần tham số truy vấn —
// link CDN của Zalo hay đổi chữ ký, so nguyên link sẽ báo đổi ảnh giả.
static void ZUSFriendTrackCompare(NSArray *friends) {
    @try {
        NSMutableDictionary *byId = [NSMutableDictionary dictionary];
        for (NSDictionary *d in friends) if ([d[@"id"] length]) byId[d[@"id"]] = d;
        if (!byId.count) return;
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"dd/MM/yyyy HH:mm";
        NSString *now = [df stringFromDate:[NSDate date]];
        id snap = ZUSReadObject(ZUS_KEY_FRIENDSNAP);
        if (![snap isKindOfClass:[NSDictionary class]] || ![snap[@"friends"] isKindOfClass:[NSArray class]]) {
            ZUSWriteSharedValue(ZUS_KEY_FRIENDSNAP, @{@"date": now, @"friends": friends});
            ZUSLog(@"theo dõi bạn bè: đã lưu mốc đầu (%lu bạn) — từ lần sao lưu sau sẽ đối chiếu thay đổi", (unsigned long)friends.count);
            return;
        }
        NSMutableDictionary *oldById = [NSMutableDictionary dictionary];
        for (NSDictionary *d in snap[@"friends"]) if ([d[@"id"] length]) oldById[d[@"id"]] = d;
        NSMutableArray *changes = [NSMutableArray array];
        for (NSString *fid in oldById) {
            NSDictionary *o = oldById[fid];
            NSDictionary *nw = byId[fid];
            if (!nw) {
                [changes addObject:@{@"date": now, @"type": @"gone", @"name": o[@"name"] ?: @"", @"id": fid,
                                     @"detail": @"Không còn trong danh sách bạn bè (huỷ kết bạn / bị chặn / đổi tài khoản)"}];
            } else {
                if (![o[@"name"] isEqualToString:nw[@"name"] ?: @""])
                    [changes addObject:@{@"date": now, @"type": @"renamed", @"name": nw[@"name"] ?: @"", @"id": fid,
                                         @"detail": [NSString stringWithFormat:@"Đổi tên: %@ → %@", o[@"name"] ?: @"", nw[@"name"] ?: @""]}];
                NSString *oa = [[o[@"avatar"] componentsSeparatedByString:@"?"] firstObject] ?: @"";
                NSString *na = [[nw[@"avatar"] componentsSeparatedByString:@"?"] firstObject] ?: @"";
                if (![oa isEqualToString:na])
                    [changes addObject:@{@"date": now, @"type": @"avatar", @"name": nw[@"name"] ?: @"", @"id": fid,
                                         @"detail": @"Đổi ảnh đại diện"}];
            }
        }
        for (NSString *fid in byId)
            if (!oldById[fid])
                [changes addObject:@{@"date": now, @"type": @"new", @"name": byId[fid][@"name"] ?: @"", @"id": fid,
                                     @"detail": @"Bạn mới xuất hiện trong danh sách"}];
        if (changes.count) {
            NSMutableArray *all = [NSMutableArray array];
            id old = ZUSReadObject(ZUS_KEY_FRIENDCHG);
            if ([old isKindOfClass:[NSArray class]]) [all addObjectsFromArray:old];
            for (NSDictionary *c in changes) [all insertObject:c atIndex:0];
            while (all.count > 500) [all removeLastObject];
            ZUSWriteSharedValue(ZUS_KEY_FRIENDCHG, all);
        }
        ZUSWriteSharedValue(ZUS_KEY_FRIENDSNAP, @{@"date": now, @"friends": friends});
        ZUSLog(@"theo dõi bạn bè: đối chiếu xong — %lu thay đổi (mốc %@, %lu bạn; hiện %lu bạn)",
               (unsigned long)changes.count, snap[@"date"] ?: @"", (unsigned long)oldById.count, (unsigned long)byId.count);
    } @catch (NSException *e) { ZUSLog(@"theo dõi bạn bè: lỗi đối chiếu: %@", e.name); }
}

static NSString *ZUSBackupContacts(void) {
    NSArray *raw = ZUSCollectFriends();
    if (!raw.count) return @"Chưa dò được danh sách bạn bè trong Zalo. Bật 'Ghi log gỡ lỗi', thử lại rồi gửi file ZUS.log — trong log có bản đồ hàm bạn bè để em chốt đúng nguồn cho vòng sau.";
    NSMutableArray *friends = [NSMutableArray array];
    for (id f in raw) {
        NSDictionary *d = ZUSFriendDict(f);
        if ([d[@"id"] length] || [d[@"name"] length]) [friends addObject:d];
    }
    if (!friends.count && raw.count) {
        // Lấy được danh sách nhưng trích trường ra rỗng: ghi lại lớp và
        // thuộc tính của phần tử đầu để vòng sau chốt đúng tên trường.
        id f0 = raw[0];
        NSMutableArray *props = [NSMutableArray array];
        unsigned pc = 0; objc_property_t *pl = class_copyPropertyList([f0 class], &pc);
        for (unsigned i = 0; i < pc; i++) [props addObject:@(property_getName(pl[i]))];
        free(pl);
        ZUSLog(@"danh bạ: lấy được %lu phần tử (lớp %@) nhưng trích tên/mã đều rỗng — thuộc tính của phần tử: %@", (unsigned long)raw.count, NSStringFromClass([f0 class]), [props componentsJoinedByString:@", "]);
    }
    ZUSFriendTrackCompare(friends);
    NSString *docs = ZUSDocsPath();
    // 1.1.5 (anh yêu cầu): mỗi bản sao lưu mang hậu tố ngày-giờ riêng,
    // không ghi đè bản trước — khôi phục thì chọn từ danh sách các bản.
    NSDateFormatter *bf = [[NSDateFormatter alloc] init];
    bf.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *base = [NSString stringWithFormat:@"ZUS-Contacts-%@", [bf stringFromDate:[NSDate date]]];
    NSString *jsonPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".json"]];
    NSString *csvPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".csv"]];
    NSString *vcfPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".vcf"]];
    NSData *json = [NSJSONSerialization dataWithJSONObject:friends options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:jsonPath atomically:YES];
    NSMutableString *csv = [NSMutableString stringWithString:@"name,zalo_id,phone,avatar\n"];
    for (NSDictionary *d in friends)
        [csv appendFormat:@"%@,%@,%@,%@\n", ZUSCSVEscape(d[@"name"]), ZUSCSVEscape(d[@"id"]), ZUSCSVEscape(d[@"phone"]), ZUSCSVEscape(d[@"avatar"])];
    [csv writeToFile:csvPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSMutableString *vcf = [NSMutableString string];
    for (NSDictionary *d in friends) {
        if (![d[@"name"] length]) continue;
        [vcf appendFormat:@"BEGIN:VCARD\nVERSION:3.0\nFN:%@\n", d[@"name"]];
        if ([d[@"phone"] length]) [vcf appendFormat:@"TEL;TYPE=CELL:%@\n", d[@"phone"]];
        if ([d[@"id"] length]) [vcf appendFormat:@"NOTE:Mã Zalo: %@\n", d[@"id"]];
        [vcf appendString:@"END:VCARD\n"];
    }
    [vcf writeToFile:vcfPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    ZUSWriteSharedValue(ZUS_DIAG_FRIENDS, @(friends.count));
    gZUSLastBackupFiles = @[jsonPath, csvPath, vcfPath];
    ZUSLog(@"danh bạ: đã sao lưu %lu bạn vào %@", (unsigned long)friends.count, jsonPath);
    return [NSString stringWithFormat:@"Đã sao lưu %lu bạn bè.\n\nFile nằm trong Documents của Zalo:\n%@\n%@\n%@", (unsigned long)friends.count, jsonPath, csvPath, vcfPath];
}

// Mọi bản sao lưu đang có trong Documents (mới nhất trước), gồm cả bản
// tên cũ ZUS-Contacts.json của các bản ZUS trước 1.1.5.
static NSArray *ZUSBackupFileList(void) {
    NSString *docs = ZUSDocsPath();
    NSArray *all = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docs error:nil];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *f in all)
        if ([f hasPrefix:@"ZUS-Contacts"] && [f hasSuffix:@".json"])
            [out addObject:[docs stringByAppendingPathComponent:f]];
    [out sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSDate *da = [[[NSFileManager defaultManager] attributesOfItemAtPath:a error:nil] fileModificationDate];
        NSDate *db = [[[NSFileManager defaultManager] attributesOfItemAtPath:b error:nil] fileModificationDate];
        return [(db ?: [NSDate distantPast]) compare:(da ?: [NSDate distantPast])];
    }];
    return out;
}

static NSArray *ZUSMissingFriendsFromPath(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    NSArray *backup = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![backup isKindOfClass:[NSArray class]]) return nil;
    NSArray *raw = ZUSCollectFriends();
    NSMutableSet *current = [NSMutableSet set];
    for (id f in raw) {
        NSString *fid = ZUSFriendDict(f)[@"id"];
        if (fid.length) [current addObject:fid];
    }
    NSMutableArray *missing = [NSMutableArray array];
    for (NSDictionary *d in backup) {
        NSString *fid = d[@"id"];
        if (fid.length && ![current containsObject:fid]) [missing addObject:d];
    }
    return missing;
}

@interface ZUSMissingFriendsController : UITableViewController
@property (nonatomic, strong) NSArray *zusMissing;
@end

@implementation ZUSMissingFriendsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Bạn bè đã mất khỏi danh bạ";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.zusMissing.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zm"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"zm"];
    NSDictionary *d = self.zusMissing[(NSUInteger)indexPath.row];
    cell.textLabel.text = [d[@"name"] length] ? d[@"name"] : d[@"id"];
    NSMutableArray *parts = [NSMutableArray array];
    if ([d[@"phone"] length]) [parts addObject:d[@"phone"]];
    if ([d[@"id"] length]) [parts addObject:[NSString stringWithFormat:@"Mã Zalo: %@", d[@"id"]]];
    cell.detailTextLabel.text = [parts componentsJoinedByString:@" • "];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Chạm vào một người: có số điện thoại thì mở trang Zalo của họ để kết bạn lại; chỉ có mã thì chép mã để tìm.";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *d = self.zusMissing[(NSUInteger)indexPath.row];
    NSString *phone = d[@"phone"];
    if (phone.length) {
        NSString *clean = [[phone componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://zalo.me/%@", clean]];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [UIPasteboard generalPasteboard].string = d[@"id"];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Đã chép mã Zalo" message:@"Dán mã này vào ô tìm kiếm của Zalo để tìm và kết bạn lại." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

@end


@interface ZUSVaultController : UITableViewController
@property (nonatomic, strong) NSArray *zusEntries;
@end

@implementation ZUSVaultController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Kho tin đã thu hồi";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.zusEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zv"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"zv"];
    NSDictionary *e = self.zusEntries[(NSUInteger)indexPath.row];
    cell.textLabel.text = [e[@"text"] length] ? e[@"text"] : @"(tin media — chạm để lấy link)";
    cell.textLabel.numberOfLines = 2;
    NSMutableArray *parts = [NSMutableArray array];
    if ([e[@"time"] length]) [parts addObject:e[@"time"]];
    if ([e[@"chat"] length]) [parts addObject:e[@"chat"]];
    if ([e[@"url"] length]) [parts addObject:@"có link media"];
    cell.detailTextLabel.text = [parts componentsJoinedByString:@" • "];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Các tin bị đối phương thu hồi mà ZUS đã chặn và cất lại. Chạm vào một tin để chép nội dung hoặc link media.";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *e = self.zusEntries[(NSUInteger)indexPath.row];
    NSString *val = [e[@"url"] length] ? e[@"url"] : e[@"text"];
    if (!val.length) return;
    [UIPasteboard generalPasteboard].string = val;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Đã chép" message:val preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end


@interface ZUSFriendChangesController : UITableViewController
@property (nonatomic, strong) NSArray *zusChanges;
@end

@implementation ZUSFriendChangesController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Thay đổi bạn bè";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.zusChanges.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zfc"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"zfc"];
    NSDictionary *e = self.zusChanges[(NSUInteger)indexPath.row];
    NSString *label = @"THAY ĐỔI";
    if ([e[@"type"] isEqualToString:@"gone"]) label = @"ĐÃ MẤT";
    else if ([e[@"type"] isEqualToString:@"new"]) label = @"BẠN MỚI";
    else if ([e[@"type"] isEqualToString:@"renamed"]) label = @"ĐỔI TÊN";
    else if ([e[@"type"] isEqualToString:@"avatar"]) label = @"ĐỔI ẢNH";
    cell.textLabel.text = [NSString stringWithFormat:@"%@ — %@", label, [e[@"name"] length] ? e[@"name"] : (e[@"id"] ?: @"")];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %@", e[@"date"] ?: @"", e[@"detail"] ?: @""];
    cell.detailTextLabel.numberOfLines = 2;
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"ZUS đối chiếu danh bạ mỗi lần anh sao lưu: ai biến mất khỏi danh sách bạn, ai mới thêm, ai đổi tên hoặc ảnh đại diện. Lần sao lưu đầu tiên chỉ lưu mốc, chưa có thay đổi để báo.";
}

@end

// ----- 1.3.0: dò kho lưu tin + sao lưu tin nhắn / lịch sử cuộc gọi -----
// Khác danh bạ (có sẵn trong bộ nhớ + hàm đưa cả danh sách), tin nhắn nằm
// trong kho dữ liệu trên đĩa của Zalo. Bản này: (1) liệt kê các file cơ sở
// dữ liệu trong vùng chứa, mở BẢN SAO chỉ-đọc, ghi cấu trúc bảng/cột vào
// ZUS.log; (2) nhận diện được bảng tin nhắn / cuộc gọi theo tên cột thì
// xuất file sao lưu ngay; chưa nhận diện được thì bản đồ cấu trúc đã nằm
// trong log cho vòng sau. TUYỆT ĐỐI không ghi vào kho của Zalo — mọi lần
// mở đều mở trên bản sao trong thư mục tạm.

static NSMutableDictionary *gZUSStoreSchema = nil; // path -> { bang: [cot] }
static NSArray *gZUSLastMsgFiles = nil;
static NSArray *gZUSLastCallFiles = nil;
static NSArray *gZUSLastAllFiles = nil;
static BOOL gZUSStoreProbed = NO;
static NSString *ZUSExportProfile(void);

static NSString *ZUSQuoteIdent(NSString *s) {
    return [NSString stringWithFormat:@"\"%@\"", [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
}

static NSDictionary *ZUSSQLiteSchema(NSString *dbPath) {
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"zusprobe-%ld-%@", (long)[[NSDate date] timeIntervalSince1970], [dbPath lastPathComponent]]];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm copyItemAtPath:dbPath toPath:tmp error:nil];
    [fm copyItemAtPath:[dbPath stringByAppendingString:@"-wal"] toPath:[tmp stringByAppendingString:@"-wal"] error:nil];
    [fm copyItemAtPath:[dbPath stringByAppendingString:@"-shm"] toPath:[tmp stringByAppendingString:@"-shm"] error:nil];
    sqlite3 *db = NULL;
    NSMutableDictionary *schema = [NSMutableDictionary dictionary];
    if (sqlite3_open_v2([tmp fileSystemRepresentation], &db, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'", -1, &st, NULL) == SQLITE_OK) {
            while (sqlite3_step(st) == SQLITE_ROW) {
                const unsigned char *tn = sqlite3_column_text(st, 0);
                if (!tn) continue;
                NSString *table = [NSString stringWithUTF8String:(const char *)tn];
                sqlite3_stmt *ps = NULL;
                NSString *q = [NSString stringWithFormat:@"PRAGMA table_info(%@)", ZUSQuoteIdent(table)];
                NSMutableArray *cols = [NSMutableArray array];
                if (sqlite3_prepare_v2(db, [q UTF8String], -1, &ps, NULL) == SQLITE_OK) {
                    while (sqlite3_step(ps) == SQLITE_ROW) {
                        const unsigned char *cn = sqlite3_column_text(ps, 1);
                        if (cn) [cols addObject:[NSString stringWithUTF8String:(const char *)cn]];
                    }
                    sqlite3_finalize(ps);
                }
                schema[table] = cols;
            }
            sqlite3_finalize(st);
        }
        sqlite3_close(db);
    } else {
        ZUSLog(@"kho tin: mở không được %@ (%s)", [dbPath lastPathComponent], db ? sqlite3_errmsg(db) : "no handle");
        if (db) sqlite3_close(db);
    }
    [fm removeItemAtPath:tmp error:nil];
    [fm removeItemAtPath:[tmp stringByAppendingString:@"-wal"] error:nil];
    [fm removeItemAtPath:[tmp stringByAppendingString:@"-shm"] error:nil];
    return schema;
}

static NSArray *ZUSSQLiteTableNames(NSString *dbPath) {
    sqlite3 *db = NULL;
    NSMutableArray *names = nil;
    if (sqlite3_open_v2([dbPath fileSystemRepresentation], &db, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
        names = [NSMutableArray array];
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'", -1, &st, NULL) == SQLITE_OK) {
            while (sqlite3_step(st) == SQLITE_ROW) {
                const unsigned char *tn = sqlite3_column_text(st, 0);
                if (tn) [names addObject:[NSString stringWithUTF8String:(const char *)tn]];
            }
            sqlite3_finalize(st);
        }
        sqlite3_close(db);
    }
    return names;
}

static NSArray *ZUSEnumerateDBFiles(NSString *root) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *out = [NSMutableArray array];
    NSDirectoryEnumerator *en = [fm enumeratorAtPath:root];
    NSString *rel = nil;
    while ((rel = [en nextObject])) {
        NSString *low = [rel lowercaseString];
        if ([low hasSuffix:@"-wal"] || [low hasSuffix:@"-shm"] || [low hasSuffix:@"-journal"]) continue;
        if (!([low hasSuffix:@".db"] || [low hasSuffix:@".sqlite"] || [low hasSuffix:@".sqlite3"])) continue;
        [out addObject:[root stringByAppendingPathComponent:rel]];
    }
    [out sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        unsigned long long sa = [[fm attributesOfItemAtPath:a error:nil][NSFileSize] unsignedLongLongValue];
        unsigned long long sb = [[fm attributesOfItemAtPath:b error:nil][NSFileSize] unsignedLongLongValue];
        if (sa != sb) return sa > sb ? NSOrderedDescending : NSOrderedAscending;
        return NSOrderedSame;
    }];
    return out;
}

static void ZUSProbeStore(void) {
    if (gZUSStoreProbed) return;
    gZUSStoreProbed = YES;
    if (!gZUSStoreSchema) gZUSStoreSchema = [NSMutableDictionary dictionary];
    @try {
        NSString *home = NSHomeDirectory();
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableArray *cands = [NSMutableArray array];
        NSArray *roots = @[[home stringByAppendingPathComponent:@"Library"], [home stringByAppendingPathComponent:@"Documents"]];
        for (NSString *root in roots) {
            NSDirectoryEnumerator *en = [fm enumeratorAtPath:root];
            NSString *rel = nil;
            while ((rel = [en nextObject])) {
                if ([[rel pathComponents] count] > 6) { [en skipDescendants]; continue; }
                NSString *low = [rel lowercaseString];
                if ([low hasSuffix:@"-wal"] || [low hasSuffix:@"-shm"] || [low hasSuffix:@"-journal"]) continue;
                BOOL isDB = [low hasSuffix:@".db"] || [low hasSuffix:@".sqlite"] || [low hasSuffix:@".sqlite3"] || [low containsString:@"sqlite"];
                if (!isDB) continue;
                NSString *full = [root stringByAppendingPathComponent:rel];
                NSDictionary *attrs = [fm attributesOfItemAtPath:full error:nil];
                if (![[attrs fileType] isEqualToString:NSFileTypeRegular]) continue;
                unsigned long long sz = [attrs fileSize];
                if (sz == 0) continue;
                [cands addObject:@{@"path": full, @"size": @(sz)}];
            }
        }
        [cands sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [b[@"size"] compare:a[@"size"]]; }];
        ZUSLog(@"kho tin: thấy %lu file cơ sở dữ liệu trong vùng chứa Zalo", (unsigned long)cands.count);
        int n = 0;
        for (NSDictionary *c in cands) {
            if (n++ >= 6) break;
            NSString *p = c[@"path"];
            ZUSLog(@"kho tin: file %@ (%@ bytes)", [p stringByReplacingOccurrencesOfString:home withString:@"~"], c[@"size"]);
            NSDictionary *schema = ZUSSQLiteSchema(p);
            gZUSStoreSchema[p] = schema;
            if (!schema.count) { ZUSLog(@"kho tin: %@ — không đọc được cấu trúc (mã hoá hoặc định dạng lạ)", [p lastPathComponent]); continue; }
            int tn = 0;
            for (NSString *t in schema) {
                if (tn++ >= 40) { ZUSLog(@"kho tin: ... (còn bảng nữa, cắt bớt trong log)"); break; }
                ZUSLog(@"kho tin: bảng %@ — cột: %@", t, [schema[t] componentsJoinedByString:@", "]);
            }
        }
    } @catch (NSException *e) { ZUSLog(@"kho tin: lỗi dò kho: %@", e.name); }
}

static NSString *ZUSFirstCol(NSArray *cols, NSArray *needles) {
    for (NSString *n in needles)
        for (NSString *c in cols)
            if ([[c lowercaseString] containsString:n]) return c;
    return nil;
}

static NSString *ZUSPickTable(BOOL forCalls, NSString **outPath) {
    NSString *best = nil, *bestPath = nil;
    int bestScore = 0;
    for (NSString *path in gZUSStoreSchema) {
        NSDictionary *tables = gZUSStoreSchema[path];
        for (NSString *t in tables) {
            NSArray *cols = tables[t];
            NSString *tl = [t lowercaseString];
            int score = 0;
            if (forCalls) {
                if ([tl containsString:@"call"]) score += 5;
                if (ZUSFirstCol(cols, @[@"duration"])) score += 3;
                if (ZUSFirstCol(cols, @[@"time", @"date", @"created"])) score += 2;
                if (ZUSFirstCol(cols, @[@"type"])) score += 1;
                if ([tl containsString:@"message"] || [tl containsString:@"msg"]) score -= 4;
            } else {
                if ([tl containsString:@"message"] || [tl containsString:@"msg"]) score += 4;
                if (ZUSFirstCol(cols, @[@"content", @"text", @"message", @"msg"])) score += 3;
                if (ZUSFirstCol(cols, @[@"time", @"date", @"created", @"timestamp"])) score += 2;
                if (ZUSFirstCol(cols, @[@"thread", @"conversation", @"chat"])) score += 2;
                if ([tl containsString:@"call"]) score -= 4;
            }
            if (score > bestScore) { bestScore = score; best = t; bestPath = path; }
        }
    }
    if (bestScore < 5 || !best) return nil;
    if (outPath) *outPath = bestPath;
    ZUSLog(@"kho tin: chọn bảng %@ trong %@ (điểm %d, cho %@)", best, [bestPath lastPathComponent], bestScore, forCalls ? @"cuộc gọi" : @"tin nhắn");
    return best;
}

static NSArray *ZUSSQLiteExport(NSString *dbPath, NSString *table, NSArray *cols, NSString *orderCol, int limit) {
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"zusexp-%ld-%@", (long)[[NSDate date] timeIntervalSince1970], [dbPath lastPathComponent]]];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm copyItemAtPath:dbPath toPath:tmp error:nil];
    [fm copyItemAtPath:[dbPath stringByAppendingString:@"-wal"] toPath:[tmp stringByAppendingString:@"-wal"] error:nil];
    [fm copyItemAtPath:[dbPath stringByAppendingString:@"-shm"] toPath:[tmp stringByAppendingString:@"-shm"] error:nil];
    sqlite3 *db = NULL;
    NSMutableArray *rows = [NSMutableArray array];
    if (sqlite3_open_v2([tmp fileSystemRepresentation], &db, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
        NSMutableString *q = [NSMutableString stringWithString:@"SELECT "];
        for (NSUInteger i = 0; i < cols.count; i++)
            [q appendFormat:@"%@%@", i ? @", " : @"", ZUSQuoteIdent(cols[i])];
        [q appendFormat:@" FROM %@", ZUSQuoteIdent(table)];
        if (orderCol) [q appendFormat:@" ORDER BY %@ DESC", ZUSQuoteIdent(orderCol)];
        [q appendFormat:@" LIMIT %d", limit];
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, [q UTF8String], -1, &st, NULL) == SQLITE_OK) {
            while (sqlite3_step(st) == SQLITE_ROW) {
                NSMutableDictionary *row = [NSMutableDictionary dictionary];
                for (NSUInteger i = 0; i < cols.count; i++) {
                    int ty = sqlite3_column_type(st, (int)i);
                    id v = @"";
                    if (ty == SQLITE_TEXT) { const unsigned char *tx = sqlite3_column_text(st, (int)i); v = tx ? ([NSString stringWithUTF8String:(const char *)tx] ?: @"") : @""; }
                    else if (ty == SQLITE_INTEGER) v = @(sqlite3_column_int64(st, (int)i));
                    else if (ty == SQLITE_FLOAT) v = @(sqlite3_column_double(st, (int)i));
                    else if (ty == SQLITE_BLOB) v = [NSString stringWithFormat:@"<blob %d bytes>", sqlite3_column_bytes(st, (int)i)];
                    row[cols[i]] = v;
                }
                [rows addObject:row];
            }
            sqlite3_finalize(st);
        } else {
            ZUSLog(@"kho tin: SELECT lỗi trên bảng %@: %s", table, sqlite3_errmsg(db));
        }
        sqlite3_close(db);
    }
    [fm removeItemAtPath:tmp error:nil];
    [fm removeItemAtPath:[tmp stringByAppendingString:@"-wal"] error:nil];
    [fm removeItemAtPath:[tmp stringByAppendingString:@"-shm"] error:nil];
    return rows;
}

static NSString *ZUSFormatEpoch(id v) {
    if (![v isKindOfClass:[NSNumber class]]) return [v description] ?: @"";
    double d = [v doubleValue];
    if (d > 1e12) d /= 1000.0;
    if (d < 1e9 || d > 4e9) return [v description];
    static NSDateFormatter *f = nil;
    if (!f) { f = [[NSDateFormatter alloc] init]; f.dateFormat = @"yyyy-MM-dd HH:mm"; }
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:d]];
}

static NSString *ZUSBackupMessagesLegacy(void);
// 1.3.1: log 1.3.0 cho thay kho tin that la cac file chat_dbs/<uid>/*.db,
// moi file mot doan chat, bang ChatContent doc duoc. Ban 1.3.0 chon bang
// theo diem nen trung bang chi muc tim kiem FTS. V2 duyet thang chat_dbs,
// file nao co ChatContent thi xuat, gop tat ca vao mot bo sao luu.
static NSString *ZUSBackupMessages(void) {
    NSString *chatDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/chat_dbs"];
    NSArray *files = ZUSEnumerateDBFiles(chatDir);
    NSMutableArray *allRows = [NSMutableArray array];
    int usedFiles = 0, unreadable = 0;
    for (NSString *path in files) {
        if (allRows.count >= 60000 || usedFiles >= 40) break;
        NSArray *names = ZUSSQLiteTableNames(path);
        if (!names) { unreadable++; continue; }
        if (![names containsObject:@"ChatContent"]) continue;
        NSDictionary *schema = ZUSSQLiteSchema(path);
        NSArray *colsAll = schema[@"ChatContent"];
        NSArray *want = @[@"SenderId", @"CliMsgId", @"GlbMsgId", @"MsgStatus", @"MsgType", @"TimeStamp", @"MsgContent", @"LocalPath", @"SeqId"];
        NSMutableArray *cols = [NSMutableArray array];
        for (NSString *c in want) if ([colsAll containsObject:c]) [cols addObject:c];
        if (![cols containsObject:@"MsgContent"]) continue;
        NSArray *rows = ZUSSQLiteExport(path, @"ChatContent", cols, [cols containsObject:@"TimeStamp"] ? @"TimeStamp" : nil, 5000);
        NSString *tag = [path lastPathComponent];
        for (NSDictionary *r in rows) {
            NSMutableDictionary *m = [r mutableCopy];
            m[@"_db"] = tag;
            [allRows addObject:m];
        }
        usedFiles++;
        ZUSLog(@"sao lưu tin nhắn: %@ — %lu dòng ChatContent", tag, (unsigned long)rows.count);
    }
    if (!allRows.count) {
        ZUSLog(@"sao lưu tin nhắn: không đọc được ChatContent ở file nào (%lu file trong chat_dbs, %d file không mở được) — quay về cách chọn bảng của 1.3.0", (unsigned long)files.count, unreadable);
        return ZUSBackupMessagesLegacy();
    }
    NSString *docs = ZUSDocsPath();
    NSDateFormatter *bf = [[NSDateFormatter alloc] init];
    bf.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *base = [NSString stringWithFormat:@"ZUS-Messages-%@", [bf stringFromDate:[NSDate date]]];
    NSString *jsonPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".json"]];
    NSString *txtPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".txt"]];
    NSData *json = [NSJSONSerialization dataWithJSONObject:allRows options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:jsonPath atomically:YES];
    NSMutableString *txt = [NSMutableString string];
    for (NSDictionary *r in allRows) {
        NSString *when = ZUSFormatEpoch(r[@"TimeStamp"]);
        NSString *sender = [r[@"SenderId"] description] ?: @"";
        NSString *content = [r[@"MsgContent"] description] ?: @"";
        if (content.length > 400) content = [[content substringToIndex:400] stringByAppendingString:@"…"];
        [txt appendFormat:@"[%@] (%@) %@: %@\n", when, r[@"_db"], sender, content.length ? content : @"(tin media/loại khác)"];
    }
    [txt writeToFile:txtPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    gZUSLastMsgFiles = @[jsonPath, txtPath];
    ZUSLog(@"sao lưu tin nhắn: tổng %lu dòng từ %d đoạn chat (ChatContent) -> %@", (unsigned long)allRows.count, usedFiles, jsonPath);
    return [NSString stringWithFormat:@"Đã sao lưu %lu tin nhắn từ %d đoạn chat (bảng ChatContent).\n\nFile trong Documents của Zalo:\n%@\n%@", (unsigned long)allRows.count, usedFiles, jsonPath, txtPath];
}

static NSString *ZUSBackupMessagesLegacy(void) {
    ZUSProbeStore();
    NSString *path = nil;
    NSString *table = ZUSPickTable(NO, &path);
    if (!table) return @"Chưa nhận diện được bảng tin nhắn trong kho dữ liệu của Zalo.\n\nCấu trúc kho đã được ghi vào ZUS.log — anh gửi file log cho em, vòng sau em chốt đúng bảng và cột để đọc.";
    NSArray *cols = gZUSStoreSchema[path][table];
    NSString *timeCol = ZUSFirstCol(cols, @[@"created", @"time", @"date", @"timestamp", @"ts"]);
    NSArray *rows = ZUSSQLiteExport(path, table, cols, timeCol, 20000);
    if (!rows.count) return [NSString stringWithFormat:@"Đã thấy bảng %@ nhưng đọc ra 0 dòng. Chi tiết đã ghi vào ZUS.log.", table];
    NSString *docs = ZUSDocsPath();
    NSDateFormatter *bf = [[NSDateFormatter alloc] init];
    bf.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *base = [NSString stringWithFormat:@"ZUS-Messages-%@", [bf stringFromDate:[NSDate date]]];
    NSString *jsonPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".json"]];
    NSString *txtPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".txt"]];
    NSData *json = [NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:jsonPath atomically:YES];
    NSString *textCol = ZUSFirstCol(cols, @[@"content", @"text", @"message", @"msg", @"body"]);
    NSString *threadCol = ZUSFirstCol(cols, @[@"thread", @"conversation", @"chat"]);
    NSMutableString *txt = [NSMutableString string];
    for (NSDictionary *r in rows) {
        NSString *when = timeCol ? ZUSFormatEpoch(r[timeCol]) : @"";
        NSString *th = threadCol ? [r[threadCol] description] : @"";
        NSString *tx = textCol ? [r[textCol] description] : @"";
        [txt appendFormat:@"[%@] (%@) %@\n", when, th, tx.length ? tx : @"(tin media/loại khác)"];
    }
    [txt writeToFile:txtPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    gZUSLastMsgFiles = @[jsonPath, txtPath];
    ZUSLog(@"sao lưu tin nhắn: %lu dòng từ %@.%@ -> %@", (unsigned long)rows.count, [path lastPathComponent], table, jsonPath);
    return [NSString stringWithFormat:@"Đã sao lưu %lu tin nhắn (bảng %@).\n\nFile trong Documents của Zalo:\n%@\n%@", (unsigned long)rows.count, table, jsonPath, txtPath];
}

static NSString *ZUSBackupCalls(void) {
    // 1.3.0 that bai vi chi do 6 file lon nhat. V2 ra TEN BANG tren moi
    // file db trong container (mo file goc chi-doc, khong sao chep nen
    // nhanh), tim bang co ten chua "call"; thay thi moi sao chep de xuat.
    NSString *home = NSHomeDirectory();
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *root in @[[home stringByAppendingPathComponent:@"Library"], [home stringByAppendingPathComponent:@"Documents"]])
        [files addObjectsFromArray:ZUSEnumerateDBFiles(root)];
    NSMutableArray *cands = [NSMutableArray array];
    int scanned = 0, unreadable = 0, skippedDup = 0;
    for (NSString *path in files) {
        if ([path containsString:@"/CloudDB/"]) { skippedDup++; continue; }
        NSArray *names = ZUSSQLiteTableNames(path);
        if (!names) { unreadable++; continue; }
        scanned++;
        for (NSString *t in names) {
            if ([[t lowercaseString] containsString:@"call"]) {
                [cands addObject:@{@"path": path, @"table": t}];
                ZUSLog(@"cuộc gọi: ứng viên bảng %@ trong %@", t, [path lastPathComponent]);
            }
        }
        if (scanned % 200 == 0) ZUSLog(@"cuộc gọi: đã rà %d file...", scanned);
    }
    ZUSLog(@"cuộc gọi: rà xong %d file (%d không mở được, bỏ qua %d file bản sao đám mây), %lu bảng ứng viên", scanned, unreadable, skippedDup, (unsigned long)cands.count);
    if (!cands.count) return @"Vẫn chưa thấy bảng lịch sử cuộc gọi: đã rà toàn bộ kho dữ liệu của Zalo, không có bảng nào tên chứa 'call'.\n\nChi tiết lượt rà đã ghi vào ZUS.log — anh gửi log cho em để vòng sau dò theo hướng khác (có thể lịch sử cuộc gọi không lưu trong sqlite).";
    NSDictionary *pick = cands[0];
    NSString *path = pick[@"path"];
    NSString *table = pick[@"table"];
    NSDictionary *schema = ZUSSQLiteSchema(path);
    NSArray *cols = schema[table];
    if (!cols.count) return [NSString stringWithFormat:@"Thấy bảng %@ trong %@ nhưng không đọc được cột. Chi tiết đã ghi vào ZUS.log.", table, [path lastPathComponent]];
    NSString *timeCol = ZUSFirstCol(cols, @[@"created", @"time", @"date", @"timestamp", @"ts"]);
    NSArray *rows = ZUSSQLiteExport(path, table, cols, timeCol, 20000);
    if (!rows.count) return [NSString stringWithFormat:@"Đã thấy bảng %@ nhưng đọc ra 0 dòng. Chi tiết đã ghi vào ZUS.log.", table];
    NSString *docs = ZUSDocsPath();
    NSDateFormatter *bf = [[NSDateFormatter alloc] init];
    bf.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *base = [NSString stringWithFormat:@"ZUS-Calls-%@", [bf stringFromDate:[NSDate date]]];
    NSString *jsonPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".json"]];
    NSString *csvPath = [docs stringByAppendingPathComponent:[base stringByAppendingString:@".csv"]];
    NSData *json = [NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:jsonPath atomically:YES];
    NSMutableString *csv = [NSMutableString string];
    [csv appendString:[[cols componentsJoinedByString:@","] stringByAppendingString:@"\n"]];
    for (NSDictionary *r in rows) {
        NSMutableArray *vals = [NSMutableArray array];
        for (NSString *c in cols) [vals addObject:ZUSCSVEscape([r[c] description] ?: @"")];
        [csv appendString:[[vals componentsJoinedByString:@","] stringByAppendingString:@"\n"]];
    }
    [csv writeToFile:csvPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    gZUSLastCallFiles = @[jsonPath, csvPath];
    ZUSLog(@"sao lưu cuộc gọi: %lu dòng từ %@.%@ -> %@", (unsigned long)rows.count, [path lastPathComponent], table, jsonPath);
    return [NSString stringWithFormat:@"Đã sao lưu %lu dòng lịch sử cuộc gọi (bảng %@).\n\nFile trong Documents của Zalo:\n%@\n%@", (unsigned long)rows.count, table, jsonPath, csvPath];
}
static NSString *ZUSBackupAll(void) {
    NSString *docs = ZUSDocsPath();
    NSDateFormatter *bf = [[NSDateFormatter alloc] init];
    bf.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *folder = [docs stringByAppendingPathComponent:[NSString stringWithFormat:@"ZUS-Backup-%@", [bf stringFromDate:[NSDate date]]]];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableArray *notes = [NSMutableArray array];
    NSMutableArray *made = [NSMutableArray array];
    void (^grab)(NSArray *) = ^(NSArray *files) {
        for (NSString *f in files) {
            NSString *d = [folder stringByAppendingPathComponent:[f lastPathComponent]];
            if ([fm copyItemAtPath:f toPath:d error:nil]) [made addObject:d];
        }
    };
    gZUSLastBackupFiles = nil;
    ZUSBackupContacts();
    if (gZUSLastBackupFiles.count) { grab(gZUSLastBackupFiles); [notes addObject:@"Danh bạ: xong"]; }
    else [notes addObject:@"Danh bạ: chưa lấy được"];
    gZUSLastMsgFiles = nil;
    ZUSBackupMessages();
    if (gZUSLastMsgFiles.count) { grab(gZUSLastMsgFiles); [notes addObject:@"Tin nhắn: xong"]; }
    else [notes addObject:@"Tin nhắn: chưa đọc được kho"];
    gZUSLastCallFiles = nil;
    ZUSBackupCalls();
    if (gZUSLastCallFiles.count) { grab(gZUSLastCallFiles); [notes addObject:@"Cuộc gọi: xong"]; }
    else [notes addObject:@"Cuộc gọi: chưa đọc được kho"];
    NSString *prof = ZUSExportProfile();
    if (prof) { grab(@[prof]); [notes addObject:@"Hồ sơ ZUS: xong"]; }
    NSString *manifest = [NSString stringWithFormat:@"ZUS — Backup toàn bộ dữ liệu\nNgày: %@\n\n%@\n", [NSDate description], [notes componentsJoinedByString:@"\n"]];
    NSString *mf = [folder stringByAppendingPathComponent:@"manifest.txt"];
    [manifest writeToFile:mf atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [made addObject:mf];
    gZUSLastAllFiles = made;
    ZUSLog(@"backup toàn bộ: %@ — %@", folder, [notes componentsJoinedByString:@"; "]);
    return [NSString stringWithFormat:@"Đã backup toàn bộ vào thư mục:\n%@\n\n%@", folder, [notes componentsJoinedByString:@"\n"]];
}

// ----- Hồ sơ ZUS: xuất/nhập toàn bộ công tắc -----
static NSArray *ZUSAllPrefKeys(void) {
    return @[ZUS_KEY_ENABLED, ZUS_KEY_UNSEEN, ZUS_KEY_DELIVERED, ZUS_KEY_TYPING, ZUS_KEY_ANTIRECALL,
             ZUS_KEY_AWAKE, ZUS_KEY_INAPP, ZUS_KEY_DEBUG, ZUS_KEY_STORYDL, ZUS_KEY_SHIELD,
             ZUS_KEY_LONGTAB, ZUS_KEY_SCHED, ZUS_KEY_LINKWARN, ZUS_KEY_ADBLOCK,
             ZUS_KEY_HIDETABDISC, ZUS_KEY_HIDETABTIME, ZUS_KEY_CONFIRMCALL, ZUS_KEY_PHOTOORIG, ZUS_KEY_MOREEMOJI];
}

static NSString *ZUSExportProfile(void) {
    NSMutableDictionary *prof = [NSMutableDictionary dictionary];
    for (NSString *k in ZUSAllPrefKeys()) prof[k] = @(ZUSReadBool(k, NO));
    prof[@"_app"] = @"ZUS";
    prof[@"_version"] = @"1.3.3";
    NSData *json = [NSJSONSerialization dataWithJSONObject:prof options:NSJSONWritingPrettyPrinted error:nil];
    NSString *path = [ZUSDocsPath() stringByAppendingPathComponent:@"ZUS-Profile.json"];
    return [json writeToFile:path atomically:YES] ? path : nil;
}

static NSString *ZUSImportProfile(void) {
    NSString *path = [ZUSDocsPath() stringByAppendingPathComponent:@"ZUS-Profile.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return @"Chưa có file ZUS-Profile.json trong Documents của Zalo. Hãy 'Xuất hồ sơ ZUS' trước, hoặc chép file hồ sơ vào đó.";
    NSDictionary *prof = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![prof isKindOfClass:[NSDictionary class]]) return @"File hồ sơ không đọc được (không phải JSON hợp lệ).";
    int applied = 0;
    for (NSString *k in ZUSAllPrefKeys()) {
        id v = prof[k];
        if ([v isKindOfClass:[NSNumber class]]) { ZUSSetPrefBool(k, [v boolValue]); applied++; }
    }
    ZUSLoadPrefs();
    ZUSApplyAwake();
    return [NSString stringWithFormat:@"Đã nhập hồ sơ: áp dụng %d công tắc.", applied];
}

// ---------------- Cửa cài đặt ngay trong Zalo ----------------
// Lớp giao diện viết riêng của tweak (không dùng class nào của Zalo ngoài
// BaseChatTVC làm điểm bám): nút tròn "ZUS" ở góc màn hình chat mở bảng công
// tắc dưới đây. Bảng ghi cùng kho prefs + phát cùng thông báo Darwin như
// trang Cài đặt của máy, nên gạt trong Zalo là tweak ăn ngay. Toàn bộ phần
// này tách rời khỏi machinery chặn: lỗi ở đây thì tối đa là mất nút.

static id ZUSDiagRead(NSString *key) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)ZUS_DOMAIN);
    return (__bridge_transfer id)v;
}

// ---------------- 1.1.5: giao diện bảng ZUS — 4 tab + nhuộm màu ----------------
// Màu lấy từ cài đặt: 4 bộ sẵn (Tối / Sáng / Xanh Zalo / Tự chọn). Tự chọn
// thì từng phần (nền, thanh, chữ, điểm nhấn) một màu riêng, lưu dạng hex
// trong cùng kho prefs. Trang Cài đặt của máy là giao diện hệ thống nên
// không nhuộm được — màu chỉ áp cho bảng trong Zalo và nút mở bảng.
static UIColor *ZUSColorFromHex(NSString *hex, UIColor *fallback) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 7) return fallback;
    unsigned v = 0;
    [[NSScanner scannerWithString:[hex substringFromIndex:1]] scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0 blue:(v & 0xFF) / 255.0 alpha:1.0];
}

static NSString *ZUSHexFromColor(UIColor *c) {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [c getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

static UIColor *ZUSBlendColor(UIColor *a, UIColor *b, CGFloat frac) {
    CGFloat r1 = 0, g1 = 0, b1 = 0, a1 = 0, r2 = 0, g2 = 0, b2 = 0, a2 = 0;
    [a getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [b getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    return [UIColor colorWithRed:r1 + (r2 - r1) * frac green:g1 + (g2 - g1) * frac blue:b1 + (b2 - b1) * frac alpha:1.0];
}

// 1.1.7 viết lại theo ảnh mẫu ZaloZen của anh: nền trang và nền ô tách
// riêng, màu mạnh (xanh) CHỈ là điểm nhấn — tab đang chọn, công tắc, dấu
// tích, thanh tiêu đề — không còn nhuộm đặc cả bảng như 1.1.5/1.1.6.
static NSDictionary *ZUSTheme(void) {
    int preset = ZUSReadInt(ZUS_KEY_THEME, 0);
    if (preset == 3) {
        UIColor *bg = ZUSColorFromHex(ZUSReadString(ZUS_KEY_COLBG), [UIColor whiteColor]);
        UIColor *bar = ZUSColorFromHex(ZUSReadString(ZUS_KEY_COLBAR), [UIColor colorWithWhite:0.95 alpha:1.0]);
        UIColor *text = ZUSColorFromHex(ZUSReadString(ZUS_KEY_COLTEXT), [UIColor blackColor]);
        UIColor *accent = ZUSColorFromHex(ZUSReadString(ZUS_KEY_COLACCENT), [UIColor systemBlueColor]);
        CGFloat r = 0, g = 0, b = 0, a = 0;
        [bar getRed:&r green:&g blue:&b alpha:&a];
        UIColor *barText = (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? [UIColor blackColor] : [UIColor whiteColor];
        UIColor *surface = ZUSBlendColor(bar, bg, 0.88);
        return @{@"bg": bg, @"bar": bar, @"surface": surface, @"text": text, @"accent": accent, @"barText": barText, @"preset": @3};
    }
    if (preset == 1) return @{@"bg": [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0], @"bar": [UIColor whiteColor], @"surface": [UIColor whiteColor], @"text": [UIColor blackColor], @"accent": [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0], @"barText": [UIColor blackColor], @"preset": @1};
    if (preset == 2) return @{@"bg": [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0], @"bar": [UIColor colorWithRed:0.0 green:0.41 blue:1.0 alpha:1.0], @"surface": [UIColor whiteColor], @"text": [UIColor blackColor], @"accent": [UIColor colorWithRed:0.0 green:0.41 blue:1.0 alpha:1.0], @"barText": [UIColor whiteColor], @"preset": @2};
    return @{@"bg": [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0], @"bar": [UIColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1.0], @"surface": [UIColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1.0], @"text": [UIColor whiteColor], @"accent": [UIColor colorWithRed:0.04 green:0.52 blue:1.0 alpha:1.0], @"barText": [UIColor whiteColor], @"preset": @0};
}

static NSString *ZUSMinToStr(int m) {
    return [NSString stringWithFormat:@"%02d:%02d", m / 60, m % 60];
}

// Hình cho nút mở bảng trong màn hình chat: cắt phần con mắt từ logo ZUS
// đã duyệt, nhúng thẳng vào tweak (không có file rời để đọc lúc chạy).
static UIImage *ZUSButtonImage(void) {
    static UIImage *img = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *d = [[NSData alloc] initWithBase64EncodedString:@"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" options:0];
        if (d) img = [[UIImage imageWithData:d scale:3.0] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return img;
}

@interface ZUSTimePickerController : UIViewController
@property (nonatomic, strong) UIDatePicker *zusPicker;
@property (nonatomic, copy) void (^zusDone)(int minutes);
@property (nonatomic) int zusInitial;
@end

@implementation ZUSTimePickerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Xong" style:UIBarButtonItemStyleDone target:self action:@selector(zus_doneTap)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Huỷ" style:UIBarButtonItemStylePlain target:self action:@selector(zus_cancelTap)];
    UIDatePicker *dp = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, 200)];
    dp.datePickerMode = UIDatePickerModeTime;
    dp.preferredDatePickerStyle = UIDatePickerStyleWheels;
    dp.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.hour = self.zusInitial / 60;
    c.minute = self.zusInitial % 60;
    dp.date = [[NSCalendar currentCalendar] dateFromComponents:c];
    [self.view addSubview:dp];
    self.zusPicker = dp;
}

- (void)zus_doneTap {
    NSDateComponents *c = [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:self.zusPicker.date];
    if (self.zusDone) self.zusDone((int)(c.hour * 60 + c.minute));
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)zus_cancelTap {
    [self.navigationController popViewControllerAnimated:YES];
}

@end

static void ZUSSaveAvatarCover(UIViewController *fromVC);

@interface ZUSSettingsController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) UITableView *zusTV;
@property (nonatomic, strong) UIView *zusTabBar;
@property (nonatomic, strong) NSArray *zusTabBtns;
@property (nonatomic) NSInteger zusTab;
@property (nonatomic, strong) NSArray *zusSecs;
@property (nonatomic, strong) NSDictionary *zusTheme;
@property (nonatomic, strong) NSString *zusColorKey;
@end

@implementation ZUSSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    ZUSLog(@"bảng ZUS: đã nạp giao diện bảng (viewDidLoad) — bảng đang hiện");
    ZUSLoadPrefs();
    self.title = @"ZUS";
    self.zusTheme = ZUSTheme();
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Xong" style:UIBarButtonItemStyleDone target:self action:@selector(zu_done)];
    CGFloat w = self.view.bounds.size.width;
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 48)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    NSArray *titles = @[@"Chặn", @"Dữ liệu", @"Giao diện", @"Thông tin"];
    NSMutableArray *btns = [NSMutableArray array];
    for (int i = 0; i < 4; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(w / 4 * i, 4, w / 4, 40);
        b.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        b.tag = i;
        b.layer.cornerRadius = 10;
        b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [b setTitle:titles[i] forState:UIControlStateNormal];
        [b setImage:[UIImage systemImageNamed:@[@"shield", @"externaldrive", @"paintpalette", @"info.circle"][(NSUInteger)i]] forState:UIControlStateNormal];
        [b setTitle:[NSString stringWithFormat:@" %@", titles[i]] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(zu_tabTap:) forControlEvents:UIControlEventTouchUpInside];
        [bar addSubview:b];
        [btns addObject:b];
    }
    [self.view addSubview:bar];
    self.zusTabBar = bar;
    self.zusTabBtns = btns;
    UITableView *tv = [[UITableView alloc] initWithFrame:CGRectMake(0, 48, w, self.view.bounds.size.height - 48) style:UITableViewStyleInsetGrouped];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.dataSource = self;
    tv.delegate = self;
    [self.view addSubview:tv];
    self.zusTV = tv;
    // 1.1.6: bản đầu ghim khung từ y=0 nên thanh tab chui dưới tai thỏ và
    // thanh trạng thái, bị che mất (máy anh là 12 Pro tai thỏ). Neo thanh
    // tab + bảng theo vùng an toàn, và tắt tiêu đề lớn của thanh điều
    // hướng cho khỏi đè lên nhau.
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    if (self.navigationController) self.navigationController.navigationBar.prefersLargeTitles = NO;
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:48],
        [tv.topAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(zu_refresh) name:@"ZUSLicenseChanged" object:nil];
    [self zus_updateLicenseVeil];
    [self zu_rebuild];
    [self zu_applyTheme];
}

- (void)zu_done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)zu_tabTap:(UIButton *)sender {
    self.zusTab = sender.tag;
    [self zu_rebuild];
    [self zu_applyTheme];
    [self.zusTV reloadData];
    if (self.zusTV.numberOfSections > 0) [self.zusTV scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

- (void)zu_applyTheme {
    NSDictionary *t = self.zusTheme;
    self.view.backgroundColor = t[@"bg"];
    self.zusTabBar.backgroundColor = t[@"bg"];
    self.zusTV.backgroundColor = t[@"bg"];
    for (UIButton *b in self.zusTabBtns) {
        BOOL sel = (b.tag == self.zusTab);
        b.backgroundColor = sel ? t[@"accent"] : t[@"surface"];
        [b setTitleColor:sel ? [UIColor whiteColor] : t[@"text"] forState:UIControlStateNormal];
        b.tintColor = sel ? [UIColor whiteColor] : t[@"text"];
    }
    UINavigationBar *nb = self.navigationController.navigationBar;
    nb.barTintColor = t[@"bar"];
    nb.tintColor = t[@"accent"];
    nb.titleTextAttributes = @{NSForegroundColorAttributeName: t[@"barText"]};
}

- (void)zu_refresh {
    ZUSLoadPrefs();
    self.zusTheme = ZUSTheme();
    [self zu_rebuild];
    [self zu_applyTheme];
    [self.zusTV reloadData];
    [self zus_updateLicenseVeil];
}

- (NSDictionary *)zu_rowAt:(NSIndexPath *)ip {
    return self.zusSecs[(NSUInteger)ip.section][@"rows"][(NSUInteger)ip.row];
}

// Dựng mô hình bảng theo tab đang chọn. Mỗi dòng là một dict: kind +
// title + các trường riêng (key/def cho switch, cat cho tristate,
// act cho action, preset cho radio, colkey cho color, minkey cho time).
- (void)zu_rebuild {
    NSMutableArray *secs = [NSMutableArray array];
    if (self.zusTab == 0) {
        {
            long total = gBlockedRead + gBlockedTyping + gBlockedDelivered + gBlockedRecall;
            NSString *sum = [NSString stringWithFormat:@"Đã chặn phiên này: %ld (đã xem %ld • đang nhập %ld • đã nhận %ld • thu hồi %ld)", total, gBlockedRead, gBlockedTyping, gBlockedDelivered, gBlockedRecall];
            NSString *lic = gLicensed ? [NSString stringWithFormat:@"Bản quyền: ĐÃ kích hoạt — %@", gLicenseName] : @"Bản quyền: CHƯA kích hoạt — mọi tính năng đang tắt";
            [secs addObject:@{@"header": @"Tổng quan", @"rows": @[
                @{@"kind": @"info", @"title": sum},
                @{@"kind": @"info", @"title": lic},
            ]}];
        }
        [secs addObject:@{@"header": @"Công tắc chính", @"rows": @[
            @{@"kind": @"switch", @"title": @"Bật ZUS", @"key": ZUS_KEY_ENABLED, @"def": @YES},
            @{@"kind": @"switch", @"title": @"Chặn “đã xem” khi đọc tin", @"key": ZUS_KEY_UNSEEN, @"def": @YES},
            @{@"kind": @"switch", @"title": @"Chặn “đã nhận”", @"key": ZUS_KEY_DELIVERED, @"def": @YES},
            @{@"kind": @"switch", @"title": @"Tắt “đang nhập...”", @"key": ZUS_KEY_TYPING, @"def": @YES},
            @{@"kind": @"switch", @"title": @"Chống thu hồi tin nhắn", @"key": ZUS_KEY_ANTIRECALL, @"def": @YES},
        ]}];
        NSMutableDictionary *perSec = [NSMutableDictionary dictionary];
        if (gZUSCurrentThreadID.length) {
            perSec[@"header"] = gZUSCurrentThreadName.length ? [NSString stringWithFormat:@"Đoạn chat này — %@", gZUSCurrentThreadName] : @"Đoạn chat này";
            perSec[@"rows"] = @[
                @{@"kind": @"lockswitch", @"title": @"Khoá đoạn chat này (Face ID)"},
                @{@"kind": @"tristate", @"title": @"Ẩn “đã xem” cho đoạn này", @"cat": @1},
                @{@"kind": @"tristate", @"title": @"Ẩn “đang nhập” cho đoạn này", @"cat": @2},
                @{@"kind": @"tristate", @"title": @"Chống thu hồi cho đoạn này", @"cat": @4},
                @{@"kind": @"callblock", @"title": @"Chặn cuộc gọi từ đoạn này"},
                @{@"kind": @"action", @"title": @"Lưu ảnh đại diện / ảnh bìa", @"act": @"saveavatar"},
            ];
            perSec[@"footer"] = @"Cài riêng thắng cài chung ở tầng màn hình chat. Riêng “đã nhận” chạy ở tầng socket nên luôn theo cài chung.";
        } else {
            perSec[@"header"] = @"Đoạn chat này";
            perSec[@"rows"] = @[@{@"kind": @"info", @"title": @"Mở một đoạn chat rồi mở lại bảng để cài riêng, khoá và xem nhật ký của đoạn đó."}];
        }
        [secs addObject:perSec];
        [secs addObject:@{@"header": @"Chặn theo giờ", @"footer": @"Mặc định TẮT — chỉ khi anh chủ động bật và tự đặt giờ mới có tác dụng. Ngoài khung giờ, các chặn đã-xem / đang-nhập / đã-nhận nằm im; chống thu hồi không bị lịch chi phối.", @"rows": @[
            @{@"kind": @"switch", @"title": @"Bật chặn theo giờ", @"key": ZUS_KEY_SCHED, @"def": @NO},
            @{@"kind": @"time", @"title": @"Từ giờ", @"minkey": ZUS_KEY_SCHEDFROM, @"mindef": @(22 * 60)},
            @{@"kind": @"time", @"title": @"Đến giờ", @"minkey": ZUS_KEY_SCHEDTO, @"mindef": @(7 * 60)},
        ]}];
        [secs addObject:@{@"header": @"Cuộc gọi", @"footer": @"Chặn cuộc gọi theo từng người nằm trong mục cài riêng của đoạn chat đó (mở đoạn chat rồi mở lại bảng). Xác nhận trước khi gọi: ZUS hỏi lại một lần trước khi Zalo bắt đầu cuộc gọi đi, tránh bấm nhầm.", @"rows": @[
            @{@"kind": @"switch", @"title": @"Xác nhận trước khi gọi", @"key": ZUS_KEY_CONFIRMCALL, @"def": @NO},
        ]}];
        [secs addObject:@{@"header": @"Quảng cáo", @"footer": @"Vòng 2: ZUS móc đúng bộ xử lý danh sách chat bên trong Inbox, ô nào bị chỉ mặt là quảng cáo sẽ bị thu chiều cao về 0. Mọi lần chỉ mặt đều ghi vào ZUS.log — nếu giấu nhầm đoạn chat thật, tắt công tắc này là danh sách trở lại bình thường ngay.", @"rows": @[
            @{@"kind": @"switch", @"title": @"Chặn quảng cáo trong danh sách chat", @"key": ZUS_KEY_ADBLOCK, @"def": @NO},
        ]}];
        if (gLockedChats.count) {
            NSMutableArray *rows = [NSMutableArray array];
            for (NSString *tid in gLockedChats)
                [rows addObject:@{@"kind": @"locklist", @"title": [gLockedChats[tid] length] ? gLockedChats[tid] : tid, @"tid": tid}];
            [secs addObject:@{@"header": @"Đoạn chat đã khoá", @"footer": @"Gạt tắt ở đây để mở khoá — lối thoát khi không vào được đoạn chat.", @"rows": rows}];
        }
    } else if (self.zusTab == 1) {
        [secs addObject:@{@"header": @"Danh bạ", @"rows": @[
            @{@"kind": @"action", @"title": @"Sao lưu danh bạ Zalo", @"act": @"backup"},
            @{@"kind": @"action", @"title": @"Khôi phục danh bạ (đối chiếu)", @"act": @"restore"},
            @{@"kind": @"action", @"title": @"Kho tin đã thu hồi", @"act": @"vault"},
            @{@"kind": @"action", @"title": @"Thay đổi bạn bè", @"act": @"friendchg"},
        ]}];
        [secs addObject:@{@"header": @"Sao lưu tin nhắn & cuộc gọi", @"footer": @"Sao lưu đọc trực tiếp kho dữ liệu của Zalo trên máy (chỉ đọc — không ghi vào kho). Tin nhắn xuất ra .json + .txt dễ đọc; cuộc gọi ra .json + .csv. Backup toàn bộ gộp danh bạ + tin nhắn + cuộc gọi + hồ sơ ZUS vào một thư mục có ngày giờ.", @"rows": @[
            @{@"kind": @"action", @"title": @"Sao lưu tin nhắn", @"act": @"backupmsg"},
            @{@"kind": @"action", @"title": @"Sao lưu lịch sử cuộc gọi", @"act": @"backupcalls"},
            @{@"kind": @"action", @"title": @"Backup toàn bộ dữ liệu", @"act": @"backupall"},
        ]}];
        [secs addObject:@{@"header": @"Hồ sơ ZUS", @"rows": @[
            @{@"kind": @"action", @"title": @"Xuất hồ sơ ZUS", @"act": @"export"},
            @{@"kind": @"action", @"title": @"Nhập hồ sơ ZUS", @"act": @"import"},
        ]}];
        [secs addObject:@{@"header": @"Khác", @"footer": @"Cảnh báo link đang ở mức dò: quét link trong tin nhắn, gặp link rút gọn hoặc tên miền nhái ngân hàng / ví / Zalo thì bật cảnh báo. Mọi link gặp được đều ghi vào ZUS.log để hiệu chỉnh.", @"rows": @[
            @{@"kind": @"switch", @"title": @"Tải Story về máy", @"key": ZUS_KEY_STORYDL, @"def": @NO},
            @{@"kind": @"switch", @"title": @"Cảnh báo link đáng ngờ", @"key": ZUS_KEY_LINKWARN, @"def": @NO},
            @{@"kind": @"switch", @"title": @"Gửi ảnh chất lượng gốc (thử nghiệm)", @"key": ZUS_KEY_PHOTOORIG, @"def": @NO},
            @{@"kind": @"switch", @"title": @"Thêm emoji react (thử nghiệm)", @"key": ZUS_KEY_MOREEMOJI, @"def": @NO},
        ]}];
    } else if (self.zusTab == 2) {
        int preset = ZUSReadInt(ZUS_KEY_THEME, 0);
        [secs addObject:@{@"header": @"Bộ màu", @"rows": @[
            @{@"kind": @"radio", @"title": @"Tối", @"preset": @0},
            @{@"kind": @"radio", @"title": @"Sáng (trắng, chữ đen)", @"preset": @1},
            @{@"kind": @"radio", @"title": @"Xanh Zalo", @"preset": @2},
            @{@"kind": @"radio", @"title": @"Tự chọn", @"preset": @3},
        ], @"mark": @(preset)}];
        NSDictionary *t = ZUSTheme();
        [secs addObject:@{@"header": @"Tự chọn từng phần", @"footer": @"Chạm một phần để chọn màu — bảng tự chuyển sang bộ Tự chọn.", @"rows": @[
            @{@"kind": @"color", @"title": @"Nền", @"colkey": ZUS_KEY_COLBG, @"color": t[@"bg"]},
            @{@"kind": @"color", @"title": @"Thanh tab & tiêu đề", @"colkey": ZUS_KEY_COLBAR, @"color": t[@"bar"]},
            @{@"kind": @"color", @"title": @"Chữ", @"colkey": ZUS_KEY_COLTEXT, @"color": t[@"text"]},
            @{@"kind": @"color", @"title": @"Công tắc & nút", @"colkey": ZUS_KEY_COLACCENT, @"color": t[@"accent"]},
        ]}];
        [secs addObject:@{@"header": @"Tab của Zalo", @"footer": @"Mặc định KHÔNG ẩn tab nào — mỗi tab chỉ ẩn khi anh tự bật công tắc của nó. Đổi công tắc xong đóng bảng là Zalo áp dụng ngay.", @"rows": @[
            @{@"kind": @"switch", @"title": @"Ẩn tab Khám phá", @"key": ZUS_KEY_HIDETABDISC, @"def": @NO},
            @{@"kind": @"switch", @"title": @"Ẩn tab Nhật ký", @"key": ZUS_KEY_HIDETABTIME, @"def": @NO},
        ]}];
        [secs addObject:@{@"header": @"Trong Zalo", @"rows": @[
            @{@"kind": @"switch", @"title": @"Nút mở bảng trong màn hình chat", @"key": ZUS_KEY_INAPP, @"def": @YES},
            @{@"kind": @"switch", @"title": @"Ấn giữ thanh tab mở bảng ZUS", @"key": ZUS_KEY_LONGTAB, @"def": @YES},
            @{@"kind": @"switch", @"title": @"Giữ màn hình sáng khi dùng Zalo", @"key": ZUS_KEY_AWAKE, @"def": @NO},
            @{@"kind": @"switch", @"title": @"Che nội dung khi thoát ra đa nhiệm", @"key": ZUS_KEY_SHIELD, @"def": @NO},
        ]}];
    } else {
        [secs addObject:@{@"header": @"Bản quyền", @"footer": @"Bản dùng thật: chưa nhập key hợp lệ thì mọi chức năng ZUS đều tắt — kể cả trang ZUS trong Cài đặt. Kích hoạt một lần, dùng theo thời hạn của key.", @"rows": @[
            @{@"kind": @"info2", @"title": @"Trạng thái", @"detail": ZUSLicenseStatusText()},
            @{@"kind": @"action", @"title": @"Mã máy — chạm để chép", @"act": @"copycode"},
            @{@"kind": @"action", @"title": @"Nhập key kích hoạt", @"act": @"activate"},
        ]}];
        [secs addObject:@{@"header": @"Trạng thái", @"rows": @[
            @{@"kind": @"action", @"title": @"Xem trạng thái dò", @"act": @"diag"},
        ]}];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd";
        NSString *today = [df stringFromDate:[NSDate date]];
        NSMutableArray *jrows = [NSMutableArray array];
        for (NSString *tid in gJournal) {
            NSDictionary *e = gJournal[tid];
            if (![e[@"day"] isEqualToString:today]) continue;
            NSString *detail = [NSString stringWithFormat:@"đã xem %@ • đang nhập %@ • đã nhận %@ • thu hồi %@", e[@"seen"] ?: @0, e[@"typing"] ?: @0, e[@"delivered"] ?: @0, e[@"recall"] ?: @0];
            [jrows addObject:@{@"kind": @"info2", @"title": [e[@"name"] length] ? e[@"name"] : tid, @"detail": detail}];
        }
        if (!jrows.count) [jrows addObject:@{@"kind": @"info", @"title": @"Hôm nay chưa ghi được lần chặn nào theo đoạn chat (cần trích được mã đoạn chat)."}];
        [secs addObject:@{@"header": @"Nhật ký chặn hôm nay — theo đoạn chat", @"rows": jrows}];
        [secs addObject:@{@"header": @"", @"footer": @"ZUS 1.3.3 • Thay đổi ăn ngay, không cần mở lại Zalo.", @"rows": @[
            @{@"kind": @"switch", @"title": @"Ghi log gỡ lỗi", @"key": ZUS_KEY_DEBUG, @"def": @YES},
        ]}];
    }
    self.zusSecs = secs;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.zusSecs.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.zusSecs[(NSUInteger)section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *h = self.zusSecs[(NSUInteger)section][@"header"];
    return h.length ? h : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.zusSecs[(NSUInteger)section][@"footer"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = [self zu_rowAt:indexPath];
    NSString *kind = row[@"kind"];
    NSDictionary *t = self.zusTheme;
    UITableViewCellStyle style = ([kind isEqualToString:@"info2"] || [kind isEqualToString:@"time"]) ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:nil];
    cell.backgroundColor = t[@"surface"];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.textColor = t[@"text"];
    cell.textLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if ([kind isEqualToString:@"switch"] || [kind isEqualToString:@"lockswitch"] || [kind isEqualToString:@"locklist"]) {
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
        sw.onTintColor = t[@"accent"];
        sw.tag = (indexPath.section << 8) | indexPath.row;
        if ([kind isEqualToString:@"switch"]) sw.on = ZUSReadBool(row[@"key"], [row[@"def"] boolValue]);
        else if ([kind isEqualToString:@"lockswitch"]) sw.on = gLockedChats[gZUSCurrentThreadID] != nil;
        else sw.on = YES;
        [sw addTarget:self action:@selector(zu_switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else if ([kind isEqualToString:@"tristate"]) {
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"Chung", @"Bật", @"Tắt"]];
        seg.frame = CGRectMake(0, 0, 170, 30);
        seg.tag = (indexPath.section << 8) | indexPath.row;
        id v = gPerChat[gZUSCurrentThreadID][ZUSCatKey([row[@"cat"] intValue])];
        seg.selectedSegmentIndex = [v isKindOfClass:[NSNumber class]] ? ([v intValue] == 1 ? 1 : 2) : 0;
        // 1.1.8: nhuộm trạng thái chọn của nút phân đoạn — bản cũ để mặc
        // định hệ thống (xám trắng) nên nút đang chọn chìm hẳn, không
        // phân biệt được chọn/chưa (anh phản ánh từ ảnh chụp 1.1.7).
        seg.selectedSegmentTintColor = t[@"accent"];
        seg.backgroundColor = [t[@"text"] colorWithAlphaComponent:0.08];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]} forState:UIControlStateSelected];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: t[@"text"]} forState:UIControlStateNormal];
        [seg addTarget:self action:@selector(zu_triChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = seg;
    } else if ([kind isEqualToString:@"callblock"]) {
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"Tắt", @"Im lặng", @"Máy bận"]];
        seg.frame = CGRectMake(0, 0, 200, 30);
        seg.tag = (indexPath.section << 8) | indexPath.row;
        id v = gCallBlock[gZUSCurrentThreadID];
        seg.selectedSegmentIndex = [v isKindOfClass:[NSNumber class]] ? [v intValue] : 0;
        seg.selectedSegmentTintColor = t[@"accent"];
        seg.backgroundColor = [t[@"text"] colorWithAlphaComponent:0.08];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]} forState:UIControlStateSelected];
        [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: t[@"text"]} forState:UIControlStateNormal];
        [seg addTarget:self action:@selector(zu_callBlockChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = seg;
    } else if ([kind isEqualToString:@"time"]) {
        cell.detailTextLabel.text = ZUSMinToStr(ZUSReadInt(row[@"minkey"], [row[@"mindef"] intValue]));
        cell.detailTextLabel.textColor = [t[@"text"] colorWithAlphaComponent:0.6];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if ([kind isEqualToString:@"radio"]) {
        int cur = [self.zusSecs[(NSUInteger)indexPath.section][@"mark"] intValue];
        cell.accessoryType = ([row[@"preset"] intValue] == cur) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if ([kind isEqualToString:@"color"]) {
        UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
        swatch.backgroundColor = row[@"color"];
        swatch.layer.cornerRadius = 13;
        swatch.layer.borderWidth = 1;
        swatch.layer.borderColor = [t[@"text"] colorWithAlphaComponent:0.3].CGColor;
        cell.accessoryView = swatch;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if ([kind isEqualToString:@"action"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if ([kind isEqualToString:@"info"]) {
        cell.textLabel.textColor = [t[@"text"] colorWithAlphaComponent:0.55];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    } else if ([kind isEqualToString:@"info2"]) {
        cell.detailTextLabel.text = row[@"detail"];
        cell.detailTextLabel.textColor = [t[@"text"] colorWithAlphaComponent:0.6];
    }
    return cell;
}

- (void)zu_switchChanged:(UISwitch *)sender {
    NSIndexPath *ip = [NSIndexPath indexPathForRow:(sender.tag & 0xFF) inSection:(sender.tag >> 8)];
    NSDictionary *row = [self zu_rowAt:ip];
    NSString *kind = row[@"kind"];
    if ([kind isEqualToString:@"switch"]) {
        ZUSSetPrefBool(row[@"key"], sender.on);
        if ([row[@"key"] isEqualToString:ZUS_KEY_INAPP] && !sender.on) [self zu_rebuild];
    } else if ([kind isEqualToString:@"lockswitch"]) {
        NSMutableDictionary *locked = [gLockedChats mutableCopy] ?: [NSMutableDictionary dictionary];
        if (sender.on) locked[gZUSCurrentThreadID] = gZUSCurrentThreadName ?: @"";
        else [locked removeObjectForKey:gZUSCurrentThreadID];
        ZUSWriteSharedValue(ZUS_KEY_LOCKED, locked);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
        ZUSLog(@"khoá đoạn chat: %@ đoạn %@", sender.on ? @"ĐÃ KHOÁ" : @"đã mở khoá", gZUSCurrentThreadID);
        [self zu_refresh];
    } else if ([kind isEqualToString:@"locklist"]) {
        if (!sender.on) {
            NSMutableDictionary *locked = [gLockedChats mutableCopy] ?: [NSMutableDictionary dictionary];
            [locked removeObjectForKey:row[@"tid"]];
            ZUSWriteSharedValue(ZUS_KEY_LOCKED, locked);
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
            [self zu_refresh];
        }
    }
}

- (void)zu_triChanged:(UISegmentedControl *)sender {
    NSIndexPath *ip = [NSIndexPath indexPathForRow:(sender.tag & 0xFF) inSection:(sender.tag >> 8)];
    NSDictionary *row = [self zu_rowAt:ip];
    NSString *catKey = ZUSCatKey([row[@"cat"] intValue]);
    NSMutableDictionary *per = [gPerChat mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *entry = [per[gZUSCurrentThreadID] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (sender.selectedSegmentIndex == 0) [entry removeObjectForKey:catKey];
    else entry[catKey] = @(sender.selectedSegmentIndex == 1 ? 1 : 0);
    if (entry.count) per[gZUSCurrentThreadID] = entry;
    else [per removeObjectForKey:gZUSCurrentThreadID];
    ZUSWriteSharedValue(ZUS_KEY_PERCHAT, per);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
    ZUSLoadPrefs();
}

- (void)zu_callBlockChanged:(UISegmentedControl *)sender {
    NSMutableDictionary *cb = [gCallBlock mutableCopy] ?: [NSMutableDictionary dictionary];
    if (sender.selectedSegmentIndex == 0) [cb removeObjectForKey:gZUSCurrentThreadID];
    else cb[gZUSCurrentThreadID] = @(sender.selectedSegmentIndex);
    ZUSWriteSharedValue(ZUS_KEY_CALLBLOCK, cb);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
    ZUSLoadPrefs();
    ZUSLog(@"chặn cuộc gọi: đoạn %@ -> %@", gZUSCurrentThreadID,
           sender.selectedSegmentIndex == 1 ? @"IM LẶNG" : (sender.selectedSegmentIndex == 2 ? @"MÁY BẬN" : @"tắt"));
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = [self zu_rowAt:indexPath];
    NSString *kind = row[@"kind"];
    if ([kind isEqualToString:@"action"]) {
        NSString *act = row[@"act"];
        if ([act isEqualToString:@"backup"]) [self zus_backupContacts];
        else if ([act isEqualToString:@"backupmsg"]) [self zus_backupMessages];
        else if ([act isEqualToString:@"backupcalls"]) [self zus_backupCalls];
        else if ([act isEqualToString:@"backupall"]) [self zus_backupAll];
        else if ([act isEqualToString:@"friendchg"]) [self zus_showFriendChanges];
        else if ([act isEqualToString:@"saveavatar"]) [self zus_saveAvatarCover];
        else if ([act isEqualToString:@"restore"]) [self zus_restoreContacts];
        else if ([act isEqualToString:@"export"]) [self zus_exportProfile];
        else if ([act isEqualToString:@"import"]) [self zus_importProfile];
        else if ([act isEqualToString:@"diag"]) [self zu_showDiag];
        else if ([act isEqualToString:@"vault"]) [self zus_showVault];
        else if ([act isEqualToString:@"copycode"]) {
            [UIPasteboard generalPasteboard].string = ZUSDeviceCode();
            [self zus_showMessage:[NSString stringWithFormat:@"Đã chép mã máy: %@", ZUSDeviceCode()]];
        }
        else if ([act isEqualToString:@"activate"]) ZUSShowActivationPopup();
    } else if ([kind isEqualToString:@"time"]) {
        ZUSTimePickerController *tp = [[ZUSTimePickerController alloc] init];
        tp.title = row[@"title"];
        tp.zusInitial = ZUSReadInt(row[@"minkey"], [row[@"mindef"] intValue]);
        NSString *mk = row[@"minkey"];
        tp.zusDone = ^(int minutes) {
            ZUSWriteSharedValue(mk, @(minutes));
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
            ZUSLoadPrefs();
            [self zu_refresh];
        };
        [self.navigationController pushViewController:tp animated:YES];
    } else if ([kind isEqualToString:@"radio"]) {
        ZUSWriteSharedValue(ZUS_KEY_THEME, row[@"preset"]);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
        [self zu_refresh];
    } else if ([kind isEqualToString:@"color"]) {
        self.zusColorKey = row[@"colkey"];
        UIColorPickerViewController *cp = [[UIColorPickerViewController alloc] init];
        cp.delegate = self;
        cp.supportsAlpha = NO;
        cp.selectedColor = row[@"color"];
        [self presentViewController:cp animated:YES completion:nil];
    }
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    if (!self.zusColorKey) return;
    ZUSWriteSharedValue(self.zusColorKey, ZUSHexFromColor(viewController.selectedColor));
    ZUSWriteSharedValue(ZUS_KEY_THEME, @3);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ZUS_NOTIFY, NULL, NULL, true);
    self.zusColorKey = nil;
    [self zu_refresh];
}

- (void)zus_showMessage:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ZUS" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)zus_backupContacts {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *summary = ZUSBackupContacts();
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ZUS" message:summary preferredStyle:UIAlertControllerStyleAlert];
            if (gZUSLastBackupFiles.count) {
                [a addAction:[UIAlertAction actionWithTitle:@"Chia sẻ file" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    NSMutableArray *urls = [NSMutableArray array];
                    for (NSString *f in gZUSLastBackupFiles) [urls addObject:[NSURL fileURLWithPath:f]];
                    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
                    av.popoverPresentationController.sourceView = self.view;
                    [self presentViewController:av animated:YES completion:nil];
                }]];
            }
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        });
    });
}

- (void)zus_backupMessages {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *summary = ZUSBackupMessages();
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ZUS" message:summary preferredStyle:UIAlertControllerStyleAlert];
            if (gZUSLastMsgFiles.count) {
                [a addAction:[UIAlertAction actionWithTitle:@"Chia sẻ file" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    NSMutableArray *urls = [NSMutableArray array];
                    for (NSString *f in gZUSLastMsgFiles) [urls addObject:[NSURL fileURLWithPath:f]];
                    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
                    av.popoverPresentationController.sourceView = self.view;
                    [self presentViewController:av animated:YES completion:nil];
                }]];
            }
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        });
    });
}

- (void)zus_backupCalls {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *summary = ZUSBackupCalls();
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ZUS" message:summary preferredStyle:UIAlertControllerStyleAlert];
            if (gZUSLastCallFiles.count) {
                [a addAction:[UIAlertAction actionWithTitle:@"Chia sẻ file" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    NSMutableArray *urls = [NSMutableArray array];
                    for (NSString *f in gZUSLastCallFiles) [urls addObject:[NSURL fileURLWithPath:f]];
                    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
                    av.popoverPresentationController.sourceView = self.view;
                    [self presentViewController:av animated:YES completion:nil];
                }]];
            }
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        });
    });
}

- (void)zus_backupAll {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *summary = ZUSBackupAll();
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ZUS" message:summary preferredStyle:UIAlertControllerStyleAlert];
            if (gZUSLastAllFiles.count) {
                [a addAction:[UIAlertAction actionWithTitle:@"Chia sẻ file" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    NSMutableArray *urls = [NSMutableArray array];
                    for (NSString *f in gZUSLastAllFiles) [urls addObject:[NSURL fileURLWithPath:f]];
                    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
                    av.popoverPresentationController.sourceView = self.view;
                    [self presentViewController:av animated:YES completion:nil];
                }]];
            }
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        });
    });
}

- (void)zus_showFriendChanges {
    id v = ZUSReadObject(ZUS_KEY_FRIENDCHG);
    if (![v isKindOfClass:[NSArray class]] || ![v count]) {
        [self zus_showMessage:@"Chưa ghi nhận thay đổi bạn bè nào. ZUS đối chiếu mỗi lần anh sao lưu danh bạ — lần sao lưu đầu tiên chỉ lưu mốc, từ lần thứ hai mới có thay đổi để báo."];
        return;
    }
    ZUSFriendChangesController *vc = [[ZUSFriendChangesController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.zusChanges = v;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)zus_saveAvatarCover {
    ZUSSaveAvatarCover(self);
}

- (void)zus_restoreContacts {
    NSArray *files = ZUSBackupFileList();
    if (!files.count) {
        [self zus_showMessage:@"Chưa có bản sao lưu nào trong Documents của Zalo. Hãy 'Sao lưu danh bạ Zalo' trước."];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Chọn bản sao lưu để đối chiếu" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"dd/MM/yyyy HH:mm";
    for (NSString *path in files) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        NSString *when = [df stringFromDate:[attrs fileModificationDate] ?: [NSDate date]];
        NSData *data = [NSData dataWithContentsOfFile:path];
        id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *cnt = [parsed isKindOfClass:[NSArray class]] ? [NSString stringWithFormat:@" — %lu bạn", (unsigned long)[parsed count]] : @"";
        NSString *title = [NSString stringWithFormat:@"%@ (%@%@)", [path lastPathComponent], when, cnt];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                NSArray *missing = ZUSMissingFriendsFromPath(path);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!missing) { [self zus_showMessage:@"Bản sao lưu không đọc được."]; return; }
                    if (!missing.count) { [self zus_showMessage:@"Danh bạ hiện tại khớp hoàn toàn với bản đã chọn — không thiếu ai."]; return; }
                    ZUSMissingFriendsController *vc = [[ZUSMissingFriendsController alloc] initWithStyle:UITableViewStyleGrouped];
                    vc.zusMissing = missing;
                    [self.navigationController pushViewController:vc animated:YES];
                });
            });
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)zus_showVault {
    id v = ZUSReadObject(ZUS_KEY_VAULT);
    if (![v isKindOfClass:[NSArray class]] || ![v count]) {
        [self zus_showMessage:@"Kho đang trống. Khi có tin bị thu hồi mà ZUS chặn được và trích được nội dung, tin sẽ nằm ở đây."];
        return;
    }
    ZUSVaultController *vc = [[ZUSVaultController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.zusEntries = v;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)zus_exportProfile {
    NSString *path = ZUSExportProfile();
    if (!path) { [self zus_showMessage:@"Xuất hồ sơ không thành công."]; return; }
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    av.popoverPresentationController.sourceView = self.view;
    [self presentViewController:av animated:YES completion:nil];
}

- (void)zus_importProfile {
    NSString *summary = ZUSImportProfile();
    [self zu_refresh];
    [self zus_showMessage:summary];
}

- (void)zu_showDiag {
    NSNumber *cand = ZUSDiagRead(ZUS_DIAG_CANDIDATES);
    NSNumber *hooked = ZUSDiagRead(ZUS_DIAG_HOOKED);
    NSNumber *skipped = ZUSDiagRead(ZUS_DIAG_SKIPPED);
    NSNumber *blockedRead = ZUSDiagRead(ZUS_DIAG_BLOCKED_READ);
    NSNumber *blockedType = ZUSDiagRead(ZUS_DIAG_BLOCKED_TYPE);
    NSNumber *blockedDeliv = ZUSDiagRead(ZUS_DIAG_BLOCKED_DELIV);
    NSNumber *blockedRecall = ZUSDiagRead(ZUS_DIAG_BLOCKED_RECALL);
    NSString *last = ZUSDiagRead(ZUS_DIAG_LAST);
    NSString *scan = ZUSDiagRead(ZUS_DIAG_SCAN);
    NSString *ctor = ZUSDiagRead(ZUS_DIAG_CTOR);
    NSNumber *friends = ZUSDiagRead(ZUS_DIAG_FRIENDS);
    NSString *friendsrc = ZUSDiagRead(ZUS_DIAG_FRIENDSRC);
    NSString *msg;
    if (!cand && !hooked) {
        msg = ctor.length
            ? [NSString stringWithFormat:@"Tweak ĐÃ nạp vào Zalo lúc %@ nhưng chưa quét được dữ liệu.\n\nVào một đoạn chat bất kỳ, đợi vài giây rồi kiểm tra lại.", ctor]
            : @"Tweak CHƯA từng nạp vào Zalo (không có mốc nạp).";
    } else {
        msg = [NSString stringWithFormat:
            @"Đã nạp vào Zalo: %@\nLần quét gần nhất: %@\nỨng viên tìm thấy: %@\nĐã móc thành công: %@\nBỏ qua (kiểu dữ liệu không an toàn): %@\nĐã chặn 'đã xem': %@ lần\nĐã chặn 'đang nhập': %@ lần\nĐã chặn 'đã nhận': %@ lần\nĐã chặn 'thu hồi': %@ lần\nSự kiện gần nhất: %@\nBạn bè đã sao lưu: %@ (nguồn: %@)",
            ctor.length ? ctor : @"—", scan ?: @"—", cand ?: @0, hooked ?: @0, skipped ?: @0,
            blockedRead ?: @0, blockedType ?: @0, blockedDeliv ?: @0, blockedRecall ?: @0,
            last.length ? last : @"—", friends ?: @0, friendsrc.length ? friendsrc : @"—"];
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Trạng thái dò" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]])
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = [self.zusTheme[@"text"] colorWithAlphaComponent:0.55];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]])
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = [self.zusTheme[@"text"] colorWithAlphaComponent:0.55];
}

- (void)zus_openActivation {
    ZUSShowActivationPopup();
}

// Hết hạn dùng thử: phủ một lớp mờ lên bảng (nhìn thấy mà không dùng
// được) kèm nút kích hoạt ở giữa. Thanh điều hướng nằm ngoài view nên
// nút đóng bảng vẫn bấm được; Zalo không bị ảnh hưởng gì.
- (void)zus_updateLicenseVeil {
    UIView *old = [self.view viewWithTag:23199];
    if (gLicenseState == 1) { [old removeFromSuperview]; return; }
    if (old) return;
    UIVisualEffectView *veil = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    veil.tag = 23199;
    veil.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:veil];
    [NSLayoutConstraint activateConstraints:@[
        [veil.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [veil.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [veil.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [veil.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    UILabel *lab = [[UILabel alloc] init];
    lab.text = @"ZUS chưa kích hoạt";
    lab.font = [UIFont boldSystemFontOfSize:20];
    lab.textAlignment = NSTextAlignmentCenter;
    lab.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"Kích hoạt ZUS" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [btn addTarget:self action:@selector(zus_openActivation) forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [veil.contentView addSubview:lab];
    [veil.contentView addSubview:btn];
    [NSLayoutConstraint activateConstraints:@[
        [lab.centerXAnchor constraintEqualToAnchor:veil.contentView.centerXAnchor],
        [lab.centerYAnchor constraintEqualToAnchor:veil.contentView.centerYAnchor constant:-30],
        [btn.centerXAnchor constraintEqualToAnchor:veil.contentView.centerXAnchor],
        [btn.topAnchor constraintEqualToAnchor:lab.bottomAnchor constant:16],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self zus_updateLicenseVeil];
    if (gLicenseState != 1) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (gLicenseState != 1) ZUSShowActivationPopup();
        });
    }
}

@end

static void ZUSDownloadMedia(NSString *urlStr, BOOL isVideo, UIViewController *fromVC);
static void ZUSTranslateText(NSString *text);
static char kZUSMediaLPAssoc;

// Trích thông tin media/văn bản từ model của một tin nhắn: quét mọi
// thuộc tính chuỗi của model, phân loại video/ảnh theo đuôi file và tên
// khoá; ghi bản đồ thuộc tính một lần cho mỗi lớp model để hiệu chỉnh.
static NSDictionary *ZUSExtractMediaInfo(__unsafe_unretained id model) {
    NSMutableDictionary *info = [@{@"videos": [NSMutableArray array], @"photos": [NSMutableArray array], @"text": @""} mutableCopy];
    if (!model) return info;
    static NSMutableSet *loggedClasses = nil;
    if (!loggedClasses) loggedClasses = [NSMutableSet set];
    NSString *cn = NSStringFromClass([model class]);
    NSMutableArray *propNames = [NSMutableArray array];
    unsigned pc = 0;
    objc_property_t *pl = class_copyPropertyList([model class], &pc);
    for (unsigned i = 0; i < pc; i++) [propNames addObject:@(property_getName(pl[i]))];
    free(pl);
    if (![loggedClasses containsObject:cn]) {
        [loggedClasses addObject:cn];
        ZUSLog(@"media: lớp model %@ — thuộc tính: %@", cn, [propNames componentsJoinedByString:@", "]);
    }
    NSArray *textKeys = @[@"content", @"text", @"messageText", @"message", @"title"];
    for (NSString *k in textKeys) {
        id v = nil;
        @try { v = [model valueForKey:k]; } @catch (NSException *e) {}
        if ([v isKindOfClass:[NSString class]] && [v length]) { info[@"text"] = v; break; }
    }
    for (NSString *k in propNames) {
        id v = nil;
        @try { v = [model valueForKey:k]; } @catch (NSException *e) {}
        NSString *urlStr = nil;
        if ([v isKindOfClass:[NSString class]] && [v hasPrefix:@"http"]) urlStr = v;
        else if ([v isKindOfClass:[NSURL class]]) urlStr = [(NSURL *)v absoluteString];
        if (!urlStr) continue;
        NSString *low = [urlStr lowercaseString];
        NSString *lk = [k lowercaseString];
        BOOL isVideo = [low containsString:@".mp4"] || [low containsString:@".mov"] || [low containsString:@".m3u8"] || [lk containsString:@"video"];
        BOOL isPhoto = [low containsString:@".jpg"] || [low containsString:@".jpeg"] || [low containsString:@".png"] || [low containsString:@".webp"] || [lk containsString:@"photo"] || [lk containsString:@"image"];
        if (isVideo) [info[@"videos"] addObject:@{@"url": urlStr, @"key": k}];
        else if (isPhoto) [info[@"photos"] addObject:@{@"url": urlStr, @"key": k}];
    }
    return info;
}

static void ZUSPromptUnlock(UIViewController *vc, UIView *veil);

// ----- 1.3.3: tìm cửa sổ chính + thanh tab (dùng chung) -----
// Log 1.3.2 chốt: recognizer gắn trên UITabBar không bao giờ cháy —
// cái chạm không tới được thanh thật (Zalo phủ lớp riêng lên trên).
// Từ 1.3.3: gắn thêm "tai nghe" ấn-giữ lên các lớp BAO NGOÀI thanh tab
// (view cha của thanh + cửa sổ chính), lọc theo vị trí chạm.
static UIWindow *ZUSKeyWindow(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) return w;
    }
    return nil;
}

static UITabBar *ZUSFindTabBar(UIWindow *win, NSString **howOut) {
    if (howOut) *howOut = nil;
    if (!win) return nil;
    UIViewController *root = win.rootViewController;
    if ([root isKindOfClass:[UITabBarController class]]) {
        if (howOut) *howOut = @"UITabBarController gốc";
        return ((UITabBarController *)root).tabBar;
    }
    NSMutableArray *stack = [NSMutableArray arrayWithObject:win];
    while (stack.count) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if ([v isKindOfClass:[UITabBar class]]) { if (howOut) *howOut = @"quét cây view"; return (UITabBar *)v; }
        for (UIView *sub in v.subviews) [stack addObject:sub];
    }
    return nil;
}

// Hình chữ nhật vùng thanh tab quy về hệ toạ độ của `view` (nới thêm
// vài điểm cho dễ trúng). Không đo được khung thanh thật thì dự phòng
// bằng dải 64pt dưới đáy của chính view.
static CGRect ZUSTabBarRectInView(UIView *view) {
    if (!view) return CGRectZero;
    UIWindow *win = ZUSKeyWindow();
    UITabBar *bar = ZUSFindTabBar(win, nil);
    if (bar && bar.window && view.window && bar.window == view.window) {
        CGRect r = [bar convertRect:bar.bounds toView:view];
        if (r.size.width > 10 && r.size.height > 10) return CGRectInset(r, -6, -12);
    }
    CGRect b = view.bounds;
    return CGRectMake(0, b.size.height - 64, b.size.width, 64);
}

// 1.3.2: trình bày bảng ZUS qua MỘT đường chung. Log 1.3.1: ấn-giữ đã
// gắn mà bảng không hiện, handler cũ không ghi log nên không biết tịt
// ở bước nào. Từ bản này mọi bước đều ghi log, và nếu VC tìm theo
// responder không dùng được (không thuộc cửa sổ nào) thì dự phòng qua
// VC trên cùng của cửa sổ chính.
static void ZUSPresentPanel(UIViewController *vc, NSString *via) {
    @try {
        UIViewController *host = vc;
        if (!host || !host.view.window) {
            UIViewController *top = ZUSTopVC();
            if (top) {
                ZUSLog(@"bảng ZUS: %@ — VC theo responder không dùng được, dự phòng qua VC trên cùng (%@)", via, NSStringFromClass([top class]));
                host = top;
            }
        }
        if (!host) { ZUSLog(@"bảng ZUS: %@ — KHÔNG tìm được màn hình nào để hiện bảng", via); return; }
        // 1.3.3: nhiều tai nghe ấn-giữ có thể cùng cháy cho một lần ấn —
        // bảng đang mở sẵn thì bỏ qua lần gọi trùng.
        UIViewController *walk = host;
        for (;;) {
            UIViewController *cand = [walk isKindOfClass:[UINavigationController class]] ? ((UINavigationController *)walk).viewControllers.firstObject : walk;
            if ([cand isKindOfClass:[ZUSSettingsController class]]) { ZUSLog(@"bảng ZUS: %@ — bảng đang mở sẵn, bỏ qua lần gọi trùng", via); return; }
            if (!walk.presentedViewController) break;
            walk = walk.presentedViewController;
        }
        host = walk;
        ZUSSettingsController *panel = [[ZUSSettingsController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:panel];
        [host presentViewController:nav animated:YES completion:nil];
        ZUSLog(@"bảng ZUS: %@ — đã gọi hiện bảng từ %@", via, NSStringFromClass([host class]));
    } @catch (NSException *e) { ZUSLog(@"bảng ZUS: %@ — lỗi hiện bảng: %@", via, e.name); }
}

@interface ZUSInAppHandler : NSObject <UIGestureRecognizerDelegate>
- (void)zu_openSettings:(id)sender;
- (void)zu_openSettingsFromGesture:(UILongPressGestureRecognizer *)g;
- (void)zu_openSettingsFromParentGesture:(UILongPressGestureRecognizer *)g;
- (void)zu_unlockTap:(UITapGestureRecognizer *)g;
- (void)zu_mediaLongPress:(UILongPressGestureRecognizer *)g;
@end

@implementation ZUSInAppHandler

- (void)zu_openSettings:(id)sender {
    UIResponder *r = (UIResponder *)sender;
    UIViewController *vc = nil;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)r; break; }
        r = [r nextResponder];
    }
    if (!vc) ZUSLog(@"bảng ZUS: nút trong chat — không tìm thấy VC theo responder, sẽ dùng đường dự phòng");
    ZUSPresentPanel(vc, @"nút trong chat");
}

// 1.1.1 (anh chốt): ấn giữ trên thanh tab dưới đáy Zalo cũng mở bảng này.
// Chỉ chạy ở trạng thái Began (một lần mỗi lần ấn giữ), rung nhẹ xác nhận,
// và tự nạp lại cài đặt ngay trước khi quyết định — công tắc đã tắt là
// ấn giữ không làm gì cả.
- (void)zu_openSettingsFromGesture:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    ZUSLog(@"ấn-giữ tab: đã nhận ấn giữ trên %@ — bắt đầu mở bảng", NSStringFromClass([g.view class]));
    ZUSLoadPrefs();
    if (!gLongPressTab) { ZUSLog(@"ấn-giữ tab: công tắc ấn-giữ đang TẮT trong cài đặt — bỏ qua"); return; }
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    UIResponder *r = (UIResponder *)g.view;
    UIViewController *vc = nil;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)r; break; }
        r = [r nextResponder];
    }
    if (!vc) ZUSLog(@"ấn-giữ tab: không tìm thấy VC theo responder, sẽ dùng đường dự phòng");
    else ZUSLog(@"ấn-giữ tab: VC theo responder là %@", NSStringFromClass([vc class]));
    ZUSPresentPanel(vc, @"ấn-giữ tab");
}

// 1.3.3: đường ấn-giữ từ các lớp BAO NGOÀI thanh tab (view cha / cửa sổ
// chính). Delegate đã lọc sẵn: chỉ chạm trong vùng thanh tab mới tới
// đây. Không dò VC theo responder (từ cửa sổ đi không tới VC) — để
// ZUSPresentPanel tự dự phòng qua VC trên cùng.
- (void)zu_openSettingsFromParentGesture:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    ZUSLog(@"ấn-giữ tab: đã nhận ấn giữ trên lớp ngoài %@ — bắt đầu mở bảng", NSStringFromClass([g.view class]));
    ZUSLoadPrefs();
    if (!gLongPressTab) { ZUSLog(@"ấn-giữ tab: công tắc ấn-giữ đang TẮT trong cài đặt — bỏ qua"); return; }
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    ZUSPresentPanel(nil, @"ấn-giữ tab (lớp ngoài)");
}

// 1.3.3: delegate của các tai nghe lớp ngoài — chỉ nhận chạm nằm trong
// vùng thanh tab dưới đáy; vùng khác của màn hình thì không nhận diện,
// để ấn-giữ đọc tin nhắn / xem ảnh không bị ảnh hưởng.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    @try {
        UIView *host = gr.view;
        if (!host) return NO;
        CGRect barRect = ZUSTabBarRectInView(host);
        if (CGRectIsEmpty(barRect)) return NO;
        CGPoint pt = [touch locationInView:host];
        return CGRectContainsPoint(barRect, pt);
    } @catch (NSException *e) { return NO; }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES; // không giành chạm với recognizer của Zalo
}

- (void)zu_unlockTap:(UITapGestureRecognizer *)g {
    UIView *veil = g.view;
    UIResponder *r = veil;
    UIViewController *vc = nil;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)r; break; }
        r = [r nextResponder];
    }
    if (vc && veil) ZUSPromptUnlock(vc, veil);
}

- (void)zu_mediaLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIView *scroll = g.view;
    CGPoint pt = [g locationInView:scroll];
    id cell = nil;
    if ([scroll isKindOfClass:[UITableView class]]) {
        NSIndexPath *ip = [(UITableView *)scroll indexPathForRowAtPoint:pt];
        if (ip) cell = [(UITableView *)scroll cellForRowAtIndexPath:ip];
    } else if ([scroll isKindOfClass:[UICollectionView class]]) {
        NSIndexPath *ip = [(UICollectionView *)scroll indexPathForItemAtPoint:pt];
        if (ip) cell = [(UICollectionView *)scroll cellForItemAtIndexPath:ip];
    }
    if (!cell) { ZUSLog(@"media: ấn-giữ không trúng ô nào"); return; }
    static NSMutableSet *loggedCells = nil;
    if (!loggedCells) loggedCells = [NSMutableSet set];
    NSString *ccn = NSStringFromClass([cell class]);
    if (![loggedCells containsObject:ccn]) {
        [loggedCells addObject:ccn];
        ZUSLog(@"media: lớp ô tin nhắn: %@", ccn);
    }
    id model = nil;
    NSArray *mk = @[@"message", @"messageModel", @"model", @"item", @"data", @"entity", @"msg", @"contentModel", @"messageEntity", @"cellModel", @"viewModel"];
    for (NSString *k in mk) {
        @try { model = [cell valueForKey:k]; } @catch (NSException *e) {}
        if (model) break;
    }
    if (!model) {
        ZUSLog(@"media: chưa lấy được model từ ô %@ — %lu khoá ứng viên đều trượt", ccn, (unsigned long)mk.count);
        return;
    }
    NSDictionary *info = ZUSExtractMediaInfo(model);
    UIResponder *r = scroll;
    UIViewController *vc = nil;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)r; break; }
        r = [r nextResponder];
    }
    if (!vc) return;
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"ZUS" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *vd in info[@"videos"]) {
        NSString *u = vd[@"url"];
        NSString *low = [u lowercaseString];
        NSString *label = [low containsString:@"1080"] ? @"1080p (Full HD)" : [low containsString:@"720"] ? @"720p (HD)" : [low containsString:@"480"] ? @"480p" : [low containsString:@"360"] ? @"360p" : @"bản có sẵn";
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Tải video — %@", label] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { ZUSDownloadMedia(u, YES, vc); }]];
    }
    NSArray *photos = info[@"photos"];
    if (photos.count) {
        NSDictionary *best = photos[0];
        for (NSDictionary *ph in photos) {
            NSString *lk = [ph[@"key"] lowercaseString];
            if ([lk containsString:@"origin"] || [lk containsString:@"full"] || [lk containsString:@"large"]) { best = ph; break; }
        }
        NSString *u = best[@"url"];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Tải ảnh gốc" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { ZUSDownloadMedia(u, NO, vc); }]];
    }
    NSString *text = info[@"text"];
    if (text.length)
        [sheet addAction:[UIAlertAction actionWithTitle:@"Dịch tin nhắn" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { ZUSTranslateText(text); }]];
    if (!sheet.actions.count) {
        ZUSLog(@"media: model %@ không trích được media/văn bản nào", NSStringFromClass([model class]));
        return;
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = scroll;
    sheet.popoverPresentationController.sourceRect = CGRectMake(pt.x, pt.y, 1, 1);
    [vc presentViewController:sheet animated:YES completion:nil];
}

@end


// ----- 1.1.5: mã đoạn chat hiện tại + khoá đoạn chat bằng Face ID -----
// Trích mã đoạn chat từ màn hình chat đang mở: thử các đối tượng giữ
// cuộc trò chuyện (theo nhiều khoá quen thuộc) rồi đọc khoá mã/tên bằng
// KVC có bọc lỗi. Trúng thì: cài riêng theo đoạn, khoá Face ID và nhật ký
// theo đoạn cùng hoạt động; trượt thì log một lần để vòng sau bám đúng,
// các tính năng đó nằm im — lõi chặn không phụ thuộc vào việc này.
static BOOL gThreadExtractLogged = NO;
static __weak id gZUSCurrentModel = nil;

static void ZUSCaptureCurrentThread(__unsafe_unretained id vc) {
    @try {
        id objs[8];
        const char *via[8];
        int n = 0;
        objs[n] = vc; via[n++] = "vc";
        const char *holderKeys[] = {"conversationModel", "chatEntity", "entity", "talkEntity", "conversation", "model"};
        for (int i = 0; i < 6 && n < 8; i++) {
            id o = nil;
            @try { o = [(id)vc valueForKey:@(holderKeys[i])]; } @catch (NSException *e) {}
            if (o && o != (id)vc) { objs[n] = o; via[n++] = holderKeys[i]; }
        }
        NSArray *idKeys = @[@"threadId", @"conversationId", @"chatId", @"threadID", @"zaloId", @"uid", @"userId", @"id"];
        NSArray *nameKeys = @[@"displayName", @"displayname", @"name", @"contactName", @"title"];
        for (int i = 0; i < n; i++) {
            id o = objs[i];
            if (!o) continue;
            NSString *foundId = nil;
            for (NSString *k in idKeys) {
                id v = nil;
                @try { v = [o valueForKey:k]; } @catch (NSException *e) {}
                if ([v isKindOfClass:[NSString class]] && [v length]) { foundId = v; break; }
                if ([v isKindOfClass:[NSNumber class]]) { foundId = [v stringValue]; break; }
            }
            if (!foundId) continue;
            NSString *foundName = nil;
            for (NSString *k in nameKeys) {
                id v = nil;
                @try { v = [o valueForKey:k]; } @catch (NSException *e) {}
                if ([v isKindOfClass:[NSString class]] && [v length]) { foundName = v; break; }
            }
            if (![foundId isEqualToString:gZUSCurrentThreadID])
                ZUSLog(@"đoạn chat hiện tại: id=%@ tên=%@ (qua %@, lớp %@)", foundId, foundName ?: @"—", @(via[i]), NSStringFromClass([o class]));
            gZUSCurrentThreadID = [foundId copy];
            gZUSCurrentModel = o;
            if (foundName.length) gZUSCurrentThreadName = [foundName copy];
            return;
        }
        if (!gThreadExtractLogged) {
            gThreadExtractLogged = YES;
            ZUSLog(@"chưa trích được mã đoạn chat từ %@ — cài riêng/khoá/nhật ký theo đoạn tạm nghỉ vòng này", NSStringFromClass([(id)vc class]));
        }
    } @catch (NSException *e) {
        ZUSLog(@"lỗi trích mã đoạn chat: %@", e.name);
    }
}

static NSMutableSet *gZUSUnlockedThreads = nil;
static NSString *gZUSLastThreadID = nil;

static void ZUSPromptUnlock(UIViewController *vc, UIView *veil) {
    LAContext *ctx = [[LAContext alloc] init];
    NSError *err = nil;
    if (![ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&err]) {
        // Máy không có Face ID/mật mã khả dụng: mở tạm để không khoá cứng
        // chính chủ máy khỏi đoạn chat của mình, có ghi log rõ ràng.
        ZUSLog(@"khoá đoạn chat: không đánh giá được xác thực (%@) — mở tạm tránh khoá cứng", err.localizedDescription);
        [veil removeFromSuperview];
        if (!gZUSUnlockedThreads) gZUSUnlockedThreads = [NSMutableSet set];
        if (gZUSCurrentThreadID) [gZUSUnlockedThreads addObject:gZUSCurrentThreadID];
        return;
    }
    [ctx evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:@"Mở đoạn chat đã khoá bằng ZUS" reply:^(BOOL ok, NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                [veil removeFromSuperview];
                if (!gZUSUnlockedThreads) gZUSUnlockedThreads = [NSMutableSet set];
                if (gZUSCurrentThreadID) [gZUSUnlockedThreads addObject:gZUSCurrentThreadID];
                ZUSLog(@"khoá đoạn chat: xác thực OK cho đoạn %@", gZUSCurrentThreadID);
            } else {
                ZUSLog(@"khoá đoạn chat: xác thực trượt (%@) — quay lại danh sách", e.localizedDescription);
                UINavigationController *nav = vc.navigationController;
                if (nav) [nav popViewControllerAnimated:YES];
                else [vc dismissViewControllerAnimated:YES completion:nil];
            }
        });
    }];
}

// Nếu đoạn đang mở nằm trong danh sách khoá: phủ mờ + bắt xác thực.
// Sang đoạn khác rồi quay lại thì phải xác thực lại; mở bảng ZUS ngay
// trong đoạn (modal phủ lên) thì không bị hỏi lại.
static void ZUSApplyChatLockIfNeeded(__unsafe_unretained id self) {
    NSString *tid = gZUSCurrentThreadID;
    if (!tid.length) return;
    if (![tid isEqualToString:gZUSLastThreadID]) {
        [gZUSUnlockedThreads removeObject:tid];
        gZUSLastThreadID = [tid copy];
    }
    if (!gLockedChats[tid]) return;
    if ([gZUSUnlockedThreads containsObject:tid]) return;
    UIViewController *vc = (UIViewController *)self;
    UIView *v = vc.view;
    if (!v || [v viewWithTag:23126]) return;
    @try {
        static ZUSInAppHandler *lockHandler = nil;
        if (!lockHandler) lockHandler = [[ZUSInAppHandler alloc] init];
        UIVisualEffectView *veil = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
        veil.tag = 23126;
        veil.frame = v.bounds;
        veil.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UILabel *lab = [[UILabel alloc] initWithFrame:veil.bounds];
        lab.text = @"Đoạn chat đã khoá bằng ZUS\nChạm để xác thực bằng Face ID";
        lab.numberOfLines = 2;
        lab.textAlignment = NSTextAlignmentCenter;
        lab.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [veil.contentView addSubview:lab];
        [veil addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:lockHandler action:@selector(zu_unlockTap:)]];
        [v addSubview:veil];
        ZUSLog(@"khoá đoạn chat: đã phủ khoá đoạn %@", tid);
        ZUSPromptUnlock(vc, veil);
    } @catch (NSException *e) {
        ZUSLog(@"lỗi phủ khoá đoạn chat: %@", e.name);
    }
}

static void (*gOrigChatAppear)(__unsafe_unretained id, SEL, BOOL) = NULL;
static BOOL gInAppInstalled = NO;
static ZUSInAppHandler *gInAppHandler = nil;
static void ZUSInstallTabBarGesture(void);

// Điểm bám duy nhất vào giao diện Zalo: viewWillAppear: của lớp màn hình chat.
// LUÔN chạy bản gốc trước; phần thêm nút bọc try/catch, tắt công tắc thì gỡ nút.
static void ZUSChatViewWillAppear(__unsafe_unretained id self, SEL _cmd, BOOL animated) {
    if (gOrigChatAppear) gOrigChatAppear(self, _cmd, animated);
    ZUSLoadPrefs();
    ZUSApplyAwake();
    ZUSInstallTabBarGesture();
    ZUSCaptureCurrentThread(self);
    ZUSApplyChatLockIfNeeded(self);
    @try {
        UIViewController *vc = (UIViewController *)self;
        UIView *v = vc.view;
        if (!v) return;
        UIView *existing = [v viewWithTag:23125]; // "ZUS"
        if (!gInAppUI) { [existing removeFromSuperview]; return; } // 1.1.2: nút là lối vào cài đặt — luôn hiện kể cả khi tổng tắt, kẻo lỡ tắt là khoá ngoài
        if (existing) return;
        if (!gInAppHandler) gInAppHandler = [[ZUSInAppHandler alloc] init];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = 23125;
        UIImage *bi = ZUSButtonImage();
        if (bi) {
            [b setImage:bi forState:UIControlStateNormal];
            b.imageView.contentMode = UIViewContentModeScaleAspectFill;
        } else {
            [b setTitle:@"ZUS" forState:UIControlStateNormal];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            b.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        }
        b.layer.cornerRadius = 22;
        b.layer.masksToBounds = YES;
        b.frame = CGRectMake(v.bounds.size.width - 56, v.bounds.size.height - 150, 44, 44);
        b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [b addTarget:gInAppHandler action:@selector(zu_openSettings:) forControlEvents:UIControlEventTouchUpInside];
        [v addSubview:b];
        // 1.1.7: gắn ấn-giữ riêng vào khung cuộn của màn hình chat để mở
        // tuỳ chọn tải video/ảnh/dịch cho từng tin — không móc hàm nào
        // của Zalo, chỉ thêm một recognizer của mình.
        @try {
            UIView *scroll = nil;
            NSMutableArray *stack = [NSMutableArray arrayWithObject:v];
            while (stack.count && !scroll) {
                UIView *cur = stack.lastObject;
                [stack removeLastObject];
                if ([cur isKindOfClass:[UITableView class]] || [cur isKindOfClass:[UICollectionView class]]) { scroll = cur; break; }
                for (UIView *sub in cur.subviews) [stack addObject:sub];
            }
            if (scroll && !objc_getAssociatedObject(scroll, &kZUSMediaLPAssoc)) {
                objc_setAssociatedObject(scroll, &kZUSMediaLPAssoc, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                static ZUSInAppHandler *mediaHandler = nil;
                if (!mediaHandler) mediaHandler = [[ZUSInAppHandler alloc] init];
                UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:mediaHandler action:@selector(zu_mediaLongPress:)];
                lp.minimumPressDuration = 0.45;
                [scroll addGestureRecognizer:lp];
                ZUSLog(@"media: đã gắn ấn-giữ vào %@ của màn hình chat", NSStringFromClass([scroll class]));
            }
        } @catch (NSException *e) {
            ZUSLog(@"media: lỗi gắn ấn-giữ: %@", e.name);
        }
    } @catch (NSException *e) {
        ZUSLog(@"lỗi khi thêm nút trong Zalo: %@", e.name);
    }
}

static void ZUSInstallInAppButton(void) {
    if (gInAppInstalled) return;
    Class cls = objc_getClass("BaseChatTVC");
    if (!cls) { ZUSLog(@"không thấy BaseChatTVC — không lắp nút trong Zalo"); return; }
    SEL sel = @selector(viewWillAppear:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m || !ZUSEncodingIsSafe(m)) { ZUSLog(@"không lắp nút trong Zalo (viewWillAppear: không đạt cổng kiểm tra)"); return; }
    MSHookMessageEx(cls, sel, (IMP)ZUSChatViewWillAppear, (IMP *)&gOrigChatAppear);
    if (gOrigChatAppear) { gInAppInstalled = YES; ZUSLog(@"đã lắp nút cài đặt trong màn hình chat"); }
    else ZUSLog(@"lắp nút trong Zalo HỎNG");
}

// ---------------- Điểm vào ----------------

// ----- Ấn giữ thanh tab mở bảng ZUS (1.1.1, anh chốt thay lối vào chính) -----
// Không móc hàm nào của Zalo: chỉ gắn UILongPressGestureRecognizer vào
// UITabBar. Tìm thanh theo hai đường: UITabBarController gốc trước, dự phòng
// quét cây view của cửa sổ chính (dùng ngăn xếp tường minh, KHÔNG đệ quy
// bằng block). Không thấy UITabBar (Zalo tự vẽ thanh riêng) thì ghi log cấu
// trúc cửa sổ để vòng sau bám đúng — tuyệt đối không gắn bừa vào view lạ.
static BOOL gTabGestureInstalled = NO;
static void ZUSInstallTabBarGesture(void) {
    if (gTabGestureInstalled) return;
    if (!gLongPressTab) return; // công tắc ấn-giữ tắt thì không gắn gì cả
    @try {
        UIWindow *win = ZUSKeyWindow();
        if (!win) return; // giao diện chưa lên — lần mở chat / hẹn giờ sau sẽ gắn tiếp
        NSString *how = nil;
        UITabBar *tabBar = ZUSFindTabBar(win, &how);
        if (!tabBar) {
            UIViewController *root = win.rootViewController;
            NSMutableArray *names = [NSMutableArray array];
            if (root.view) for (UIView *sub in root.view.subviews)
                [names addObject:[NSString stringWithFormat:@"%@(y=%.0f,h=%.0f)", NSStringFromClass([sub class]), sub.frame.origin.y, sub.frame.size.height]];
            ZUSLog(@"ấn-giữ tab: chưa thấy UITabBar (gốc=%@) — các view con của view gốc: %@", NSStringFromClass([root class]), [names componentsJoinedByString:@", "]);
            return;
        }
        if (!gInAppHandler) gInAppHandler = [[ZUSInAppHandler alloc] init];
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:gInAppHandler action:@selector(zu_openSettingsFromGesture:)];
        lp.minimumPressDuration = 0.5;
        lp.cancelsTouchesInView = YES; // ấn giữ ăn luôn cái chạm — không nhảy tab
        [tabBar addGestureRecognizer:lp];
        ZUSLog(@"đã gắn ấn-giữ mở bảng ZUS vào thanh tab (%@, lớp %@)", how, NSStringFromClass([tabBar class]));
        // 1.3.3: gắn thêm tai nghe lên các lớp bao ngoài thanh tab —
        // log 1.3.2 cho thấy chạm không xuống được thanh thật (bị lớp
        // giao diện riêng của Zalo phủ lên). Tai nghe lớp ngoài chỉ
        // NGHE (không ăn chạm), delegate lọc đúng vùng thanh tab.
        NSMutableArray *hosts = [NSMutableArray array];
        if (tabBar.superview) [hosts addObject:tabBar.superview];
        if (![hosts containsObject:win]) [hosts addObject:win];
        for (UIView *host in hosts) {
            UILongPressGestureRecognizer *lp2 = [[UILongPressGestureRecognizer alloc] initWithTarget:gInAppHandler action:@selector(zu_openSettingsFromParentGesture:)];
            lp2.minimumPressDuration = 0.5;
            lp2.cancelsTouchesInView = NO;
            lp2.delegate = gInAppHandler;
            [host addGestureRecognizer:lp2];
            ZUSLog(@"ấn-giữ tab: đã gắn thêm tai nghe ấn-giữ lên lớp ngoài %@ (gốc %@)", NSStringFromClass([host class]), NSStringFromClass([tabBar class]));
        }
        gTabGestureInstalled = YES;
    } @catch (NSException *e) {
        ZUSLog(@"lỗi khi gắn ấn-giữ thanh tab: %@", e.name);
    }
}


// ----- 1.3.0: ẩn tab Khám phá / Nhật ký (dạng option) -----
// Yêu cầu của anh: KHÔNG ẩn mặc định — mỗi tab có công tắc riêng, chỉ ẩn
// khi anh tự bật. Cách làm: giữ danh sách tab gốc đầy đủ nhất từng thấy,
// khi có công tắc bật thì lọc bỏ tab Khám phá (TabDiscoverConnector...) /
// Nhật ký (ZATimelineConnector...) khỏi tab bar; tắt hết thì khôi phục
// nguyên danh sách gốc.
static __weak UITabBarController *gZUSTabCtl = nil;
static NSArray *gZUSTabOrigVCs = nil;
static NSString *gZUSTabAppliedState = nil;

static void ZUSApplyTabHiding(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { win = w; break; }
                if (win) break;
            }
            UIViewController *root = win.rootViewController;
            if (![root isKindOfClass:[UITabBarController class]]) return;
            UITabBarController *tbc = (UITabBarController *)root;
            if (gZUSTabCtl != tbc) { gZUSTabCtl = tbc; gZUSTabOrigVCs = nil; gZUSTabAppliedState = nil; }
            if (!gHideTabDiscover && !gHideTabTimeline) {
                if (gZUSTabOrigVCs && tbc.viewControllers.count != gZUSTabOrigVCs.count) {
                    tbc.viewControllers = gZUSTabOrigVCs;
                    ZUSLog(@"ẩn tab: đã khôi phục đủ %lu tab", (unsigned long)gZUSTabOrigVCs.count);
                }
                if (tbc.viewControllers.count) gZUSTabOrigVCs = tbc.viewControllers;
                gZUSTabAppliedState = @"none";
                return;
            }
            if (!gZUSTabOrigVCs || tbc.viewControllers.count > gZUSTabOrigVCs.count) gZUSTabOrigVCs = tbc.viewControllers;
            if (!gZUSTabOrigVCs.count) return;
            NSString *state = [NSString stringWithFormat:@"d%d-t%d", gHideTabDiscover, gHideTabTimeline];
            if ([state isEqualToString:gZUSTabAppliedState] && tbc.viewControllers.count != gZUSTabOrigVCs.count) return;
            NSMutableArray *keep = [NSMutableArray array];
            int hidden = 0;
            for (UIViewController *vc in gZUSTabOrigVCs) {
                UIViewController *top = vc;
                if ([vc isKindOfClass:[UINavigationController class]]) top = ((UINavigationController *)vc).topViewController ?: vc;
                NSString *cn = [NSString stringWithFormat:@"%@ %@", NSStringFromClass([vc class]), NSStringFromClass([top class])];
                BOOL hide = (gHideTabDiscover && [cn containsString:@"Discover"]) ||
                            (gHideTabTimeline && [cn containsString:@"Timeline"]);
                if (hide) hidden++; else [keep addObject:vc];
            }
            if (hidden == 0) { gZUSTabAppliedState = state; return; }
            if (!keep.count) { ZUSLog(@"ẩn tab: KHÔNG áp dụng — lọc xong không còn tab nào"); return; }
            UIViewController *sel = tbc.selectedViewController;
            tbc.viewControllers = keep;
            if (sel && ![keep containsObject:sel]) tbc.selectedIndex = 0;
            gZUSTabAppliedState = state;
            ZUSLog(@"ẩn tab: đã ẩn %d tab (Khám phá=%d, Nhật ký=%d) — còn %lu tab", hidden, gHideTabDiscover, gHideTabTimeline, (unsigned long)keep.count);
        } @catch (NSException *e) { ZUSLog(@"ẩn tab: lỗi áp dụng: %@", e.name); }
    });
}

// ----- 1.1.5: cảnh báo link đáng ngờ (tính năng dò — ghi log mọi URL gặp
// được để hiệu chỉnh; chỉ bật cảnh báo khi anh gạt công tắc riêng) -----
static NSMutableDictionary *gLinkOrigs = nil;
static NSMutableSet *gLinkAlerted = nil;
static int gLinkLogCount = 0;
static int gLinkAlertCount = 0;

static void ZUSPresentAlertTop(NSString *title, NSString *msg) {
    UIWindow *win = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { win = w; break; }
        if (win) break;
    }
    UIViewController *vc = win.rootViewController;
    if (!vc) return;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

static NSString *ZUSSuspiciousReason(NSURL *url) {
    NSString *host = [[url host] lowercaseString];
    if (!host.length) return nil;
    static NSArray *shorteners = nil;
    if (!shorteners) shorteners = @[@"bit.ly", @"tinyurl.com", @"t.co", @"rutgon.me", @"s.id", @"bom.so", @"tiny.cc", @"is.gd", @"cutt.ly", @"rb.gy"];
    for (NSString *sh in shorteners)
        if ([host isEqualToString:sh] || [host hasSuffix:[@"." stringByAppendingString:sh]])
            return @"link rút gọn — không thấy đích đến thật";
    static NSArray *brands = nil;
    if (!brands) brands = @[@"vietcombank", @"techcombank", @"mbbank", @"bidv", @"agribank", @"vpbank", @"sacombank", @"vietinbank", @"zalopay", @"momo", @"tpbank", @"acb"];
    static NSArray *official = nil;
    if (!official) official = @[@"vietcombank.com.vn", @"techcombank.com.vn", @"mbbank.com.vn", @"bidv.com.vn", @"agribank.com.vn", @"vpbank.com.vn", @"sacombank.com.vn", @"vietinbank.vn", @"zalopay.vn", @"momo.vn", @"tpbank.com.vn", @"acb.com.vn", @"zalo.me", @"zaloapp.com", @"chat.zalo.me"];
    for (NSString *o in official)
        if ([host isEqualToString:o] || [host hasSuffix:[@"." stringByAppendingString:o]]) return nil;
    for (NSString *b in brands)
        if ([host containsString:b]) return @"tên miền nhái thương hiệu ngân hàng/ví";
    if ([host containsString:@"zalo"]) return @"tên miền nhái Zalo";
    return nil;
}

static void ZUSScanStringForLinks(NSString *str) {
    if (!str.length || str.length > 4000) return;
    static NSDataDetector *det = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ det = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil]; });
    if (!det) return;
    NSArray *matches = [det matchesInString:str options:0 range:NSMakeRange(0, str.length)];
    for (NSTextCheckingResult *m in matches) {
        NSURL *url = m.URL;
        if (!url) continue;
        if (gLinkLogCount < 20) {
            gLinkLogCount++;
            ZUSLog(@"link: thấy %@ (lần %d)", url.absoluteString, gLinkLogCount);
        }
        NSString *reason = ZUSSuspiciousReason(url);
        if (!reason || !gLinkWarning) continue;
        if (!gLinkAlerted) gLinkAlerted = [NSMutableSet set];
        if ([gLinkAlerted containsObject:url.absoluteString] || gLinkAlertCount >= 5) continue;
        [gLinkAlerted addObject:url.absoluteString];
        gLinkAlertCount++;
        ZUSLog(@"link: ĐÁNG NGỜ %@ — %@", url.absoluteString, reason);
        NSString *msg = [NSString stringWithFormat:@"%@\n\nLý do: %@.\nKiểm tra kỹ trước khi mở hoặc nhập thông tin.", url.absoluteString, reason];
        dispatch_async(dispatch_get_main_queue(), ^{ ZUSPresentAlertTop(@"Cảnh báo link đáng ngờ", msg); });
    }
}

static void ZUSScanObjectForLinks(__unsafe_unretained id obj) {
    if (!obj) return;
    if ([obj isKindOfClass:[NSString class]]) { ZUSScanStringForLinks((NSString *)obj); return; }
    static NSArray *keys = nil;
    if (!keys) keys = @[@"content", @"text", @"message", @"messageText", @"link", @"url", @"href", @"displayUrl", @"displayURL", @"title", @"desc"];
    for (NSString *k in keys) {
        id v = nil;
        @try { v = [obj valueForKey:k]; } @catch (NSException *e) {}
        if ([v isKindOfClass:[NSString class]]) ZUSScanStringForLinks(v);
    }
}

// Hàm thay thế riêng cho móc dò link: luôn gọi bản gốc trước (giữ nguyên
// giá trị trả), rồi mới quét đối tượng tin nhắn + đối tượng parser.
static long long ZUSLinkHook(__unsafe_unretained id self, SEL _cmd, void *a1, void *a2, void *a3) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    NSArray *rec = gLinkOrigs[key];
    if (!rec) return 0;
    void *orig = [rec[0] pointerValue];
    int argc = [rec[1] intValue];
    long long r = 0;
    if (orig) {
        switch (argc) {
            case 0: r = ((long long (*)(__unsafe_unretained id, SEL))orig)(self, _cmd); break;
            case 1: r = ((long long (*)(__unsafe_unretained id, SEL, void *))orig)(self, _cmd, a1); break;
            case 2: r = ((long long (*)(__unsafe_unretained id, SEL, void *, void *))orig)(self, _cmd, a1, a2); break;
            default: r = ((long long (*)(__unsafe_unretained id, SEL, void *, void *, void *))orig)(self, _cmd, a1, a2, a3); break;
        }
    }
    @try {
        if (gLinkWarning || gDebug) {
            if (argc >= 1 && a1) ZUSScanObjectForLinks((__bridge id)a1);
            ZUSScanObjectForLinks(self);
        }
    } @catch (NSException *e) {}
    return r;
}

static void ZUSInstallLinkHooks(void) {
    if (!gLinkOrigs) gLinkOrigs = [NSMutableDictionary dictionary];
    // 1.3.0 tim lop bang objc_getClass(ten tran): LinkTableItem va
    // TextTableItem khong ton tai duoi ten do (lop Swift mang tien to
    // module trong ten runtime) nen khong moc nao cham duoc dung lop.
    // V2 tim theo ten cuoi trong danh sach lop + census lop *Link*.
    @try {
        unsigned cc = 0;
        Class *all = objc_copyClassList(&cc);
        int census = 0;
        for (unsigned i = 0; i < cc && census < 20; i++) {
            if (!ZUSClassIsZaloImage(all[i])) continue;
            NSString *shortN = ZUSClassShortName(all[i]);
            if (![[shortN lowercaseString] containsString:@"link"]) continue;
            unsigned mc = 0;
            Method *ml = class_copyMethodList(all[i], &mc);
            free(ml);
            ZUSLog(@"link: census lớp %@ (tên đầy đủ %@) — %d hàm", shortN, NSStringFromClass(all[i]), mc);
            census++;
        }
        free(all);
    } @catch (NSException *e) {}
    const char *names[] = {"MessageTableItem", "TextTableItem", "LinkTableItem", "PhotoTableItem", "VideoTableItem", "StickerTableItem"};
    int total = 0;
    for (int ci = 0; ci < 6; ci++) {
        NSString *want = @(names[ci]);
        NSMutableArray *matches = [NSMutableArray array];
        ZUSCollectClassesNamed(want, matches);
        if (!matches.count) { ZUSLog(@"link: KHÔNG thấy lớp tên %@ trong danh sách lớp", want); continue; }
        BOOL isLinkClass = (ci == 2);
        for (Class cls in matches) {
            unsigned mc = 0;
            Method *ml = class_copyMethodList(cls, &mc);
            int classHooks = 0;
            for (unsigned i = 0; i < mc; i++) {
                Method m = ml[i];
                NSString *sn = NSStringFromSelector(method_getName(m));
                NSString *low = [sn lowercaseString];
                if ([low containsString:@"undo"]) continue;
                BOOL nameHit = isLinkClass || [low containsString:@"link"] || [low containsString:@"url"] ||
                               [low containsString:@"parser"] || [low containsString:@"parse"];
                if (!nameHit) continue;
                int argc = (int)method_getNumberOfArguments(m) - 2;
                if (argc < 0 || argc > 3) continue;
                if (!ZUSEncodingIsSafeN(m, argc)) continue;
                NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(cls), sn];
                if (gLinkOrigs[key]) continue;
                void *orig = NULL;
                MSHookMessageEx(cls, method_getName(m), (IMP)ZUSLinkHook, (IMP *)&orig);
                if (orig) { gLinkOrigs[key] = @[[NSValue valueWithPointer:orig], @(argc)]; total++; classHooks++; ZUSLog(@"link: đã gắn móc dò %@.%@", NSStringFromClass(cls), sn); }
            }
            free(ml);
            ZUSLog(@"link: lớp %@ — %d hàm, gắn %d móc", NSStringFromClass(cls), mc, classHooks);
        }
    }
    ZUSLog(@"link: tổng %d móc dò link", total);
}


// ----- 1.1.7: tải media về thư viện Ảnh + dịch tin nhắn -----
// ----- 1.3.0: lưu ảnh đại diện / ảnh bìa của đoạn chat đang mở -----
// Nguồn link: (1) mô hình đoạn chat đang mở — thử các khoá avatar/bìa phổ
// biến và ghi log toàn bộ thuộc tính của mô hình để vòng sau chốt đúng tên
// trường; (2) mốc danh bạ / bản sao lưu gần nhất (trường avatar của
// BuddyEntity đã kiểm chứng trên máy). Tải về qua đúng đường tải media
// sẵn có (lưu vào Ảnh, hỏng thì mở bảng chia sẻ).
static NSString *ZUSFirstURLForKeys(id obj, NSArray *keys) {
    for (NSString *k in keys) {
        id v = nil;
        @try { v = [obj valueForKey:k]; } @catch (NSException *e) {}
        if ([v isKindOfClass:[NSString class]] && [v hasPrefix:@"http"]) return v;
        if ([v isKindOfClass:[NSURL class]]) return [v absoluteString];
    }
    return nil;
}

static void ZUSSaveAvatarCover(UIViewController *fromVC) {
    @try {
        NSMutableArray *found = [NSMutableArray array];
        id model = gZUSCurrentModel;
        if (model) {
            static BOOL propsLogged = NO;
            if (!propsLogged) {
                propsLogged = YES;
                NSMutableArray *props = [NSMutableArray array];
                unsigned pc = 0;
                objc_property_t *pl = class_copyPropertyList(object_getClass(model), &pc);
                for (unsigned i = 0; i < pc; i++) [props addObject:@(property_getName(pl[i]))];
                free(pl);
                ZUSLog(@"lưu avatar/bìa: mô hình đoạn chat %@ — thuộc tính: %@", NSStringFromClass(object_getClass(model)), [props componentsJoinedByString:@", "]);
            }
            NSString *av = ZUSFirstURLForKeys(model, @[@"avatarurl", @"avatarURL", @"avatarUrl", @"avatar", @"avatarPath", @"pictureUrl", @"photoUrl"]);
            if (av) [found addObject:@{@"label": @"Ảnh đại diện", @"url": av}];
            NSString *cv = ZUSFirstURLForKeys(model, @[@"bgavatarurl", @"coverURL", @"coverUrl", @"cover", @"coverPhoto", @"backgroundURL", @"backgroundUrl", @"bannerUrl"]);
            if (cv) [found addObject:@{@"label": @"Ảnh bìa", @"url": cv}];
        }
        BOOL hasAvatar = NO;
        for (NSDictionary *f in found) if ([f[@"label"] isEqualToString:@"Ảnh đại diện"]) hasAvatar = YES;
        if (!hasAvatar && gZUSCurrentThreadID.length) {
            NSArray *friends = nil;
            id snap = ZUSReadObject(ZUS_KEY_FRIENDSNAP);
            if ([snap isKindOfClass:[NSDictionary class]] && [snap[@"friends"] isKindOfClass:[NSArray class]]) friends = snap[@"friends"];
            if (!friends) {
                NSArray *files = ZUSBackupFileList();
                if (files.count) {
                    NSData *d = [NSData dataWithContentsOfFile:files[0]];
                    id p = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
                    if ([p isKindOfClass:[NSArray class]]) friends = p;
                }
            }
            for (NSDictionary *fd in friends) {
                if ([fd[@"id"] isEqualToString:gZUSCurrentThreadID] && [fd[@"avatar"] length]) {
                    [found addObject:@{@"label": @"Ảnh đại diện", @"url": fd[@"avatar"]}];
                    break;
                }
            }
        }
        if (!found.count) {
            ZUSLog(@"lưu avatar/bìa: chưa tìm được link nào cho đoạn %@ (model %@)", gZUSCurrentThreadID, model ? NSStringFromClass(object_getClass(model)) : @"(không có)");
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ZUS"
                message:@"Chưa tìm được link ảnh đại diện / ảnh bìa của đoạn chat này. Em đã ghi log các thuộc tính của mô hình đoạn chat — anh gửi ZUS.log cho em để chốt đúng tên trường ở vòng sau." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [fromVC presentViewController:a animated:YES completion:nil];
            return;
        }
        for (NSDictionary *f in found) {
            ZUSLog(@"lưu avatar/bìa: %@ -> %@", f[@"label"], f[@"url"]);
            ZUSDownloadMedia(f[@"url"], NO, fromVC);
        }
    } @catch (NSException *e) { ZUSLog(@"lưu avatar/bìa: lỗi: %@", e.name); }
}

static void ZUSDownloadMedia(NSString *urlStr, BOOL isVideo, UIViewController *fromVC) {
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return;
    ZUSLog(@"tải media: bắt đầu %@ (%@)", urlStr, isVideo ? @"video" : @"ảnh");
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *err) {
        if (err || !loc) {
            ZUSLog(@"tải media: LỖI %@", err.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{ ZUSPresentAlertTop(@"Tải media", @"Tải không thành công — kiểm tra mạng rồi thử lại."); });
            return;
        }
        NSString *ext = isVideo ? @"mp4" : (url.pathExtension.length ? url.pathExtension : @"jpg");
        NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ZUS-%@.%@", NSUUID.UUID.UUIDString, ext]];
        [[NSFileManager defaultManager] moveItemAtPath:loc.path toPath:dest error:nil];
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus st) {
            if (st == PHAuthorizationStatusAuthorized || st == PHAuthorizationStatusLimited) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    if (isVideo) [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:dest]];
                    else [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:dest]];
                } completionHandler:^(BOOL ok, NSError *e2) {
                    ZUSLog(@"tải media: lưu vào Ảnh %@", ok ? @"OK" : (e2.localizedDescription ?: @"trượt"));
                    dispatch_async(dispatch_get_main_queue(), ^{ ZUSPresentAlertTop(@"Tải media", ok ? @"Đã lưu vào thư viện Ảnh." : @"Không lưu được vào thư viện Ảnh."); });
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:dest]] applicationActivities:nil];
                    av.popoverPresentationController.sourceView = fromVC.view;
                    [fromVC presentViewController:av animated:YES completion:nil];
                });
            }
        }];
    }];
    [task resume];
}

static void ZUSTranslateText(NSString *text) {
    NSString *q = [text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *u = [NSString stringWithFormat:@"https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=vi&dt=t&q=%@", q];
    ZUSLog(@"dịch: gửi dịch %lu ký tự", (unsigned long)text.length);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:u] completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSString *out = nil;
        if (data) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSArray class]] && [json count] && [json[0] isKindOfClass:[NSArray class]]) {
                NSMutableString *acc = [NSMutableString string];
                for (id seg in json[0])
                    if ([seg isKindOfClass:[NSArray class]] && [seg count] && [seg[0] isKindOfClass:[NSString class]]) [acc appendString:seg[0]];
                if (acc.length) out = acc;
            }
        }
        ZUSLog(@"dịch: %@", out ? @"có kết quả" : @"KHÔNG có kết quả");
        dispatch_async(dispatch_get_main_queue(), ^{
            ZUSPresentAlertTop(@"Dịch tin nhắn", out ?: [NSString stringWithFormat:@"Không dịch được (mạng hoặc định dạng lạ).\n\nNguyên văn: %@", text]);
        });
    }];
    [task resume];
}


// ----- 1.3.0: luồng cuộc gọi — chặn cuộc gọi giữ bạn bè + xác nhận khi gọi -----
// Điểm bám đã có bằng chứng từ log ứng viên 1.0.3 của chính máy anh:
// RMIncomingAlertAction.executeActionWithThreadId:toMuteCall:profileInfo:
// dataUpdateHandler: — hành động "báo cuộc gọi đến". Mọi móc ở phần này
// đều qua cổng kiểm chữ ký lúc chạy: chữ ký lạ thì chỉ ghi log, không lắp.

static UIViewController *ZUSTopVC(void) {
    UIWindow *win = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { win = w; break; }
        if (win) break;
    }
    UIViewController *vc = win.rootViewController;
    if (!vc) return nil;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) vc = ((UINavigationController *)vc).topViewController ?: vc;
    else if ([vc isKindOfClass:[UITabBarController class]]) {
        vc = ((UITabBarController *)vc).selectedViewController ?: vc;
        if ([vc isKindOfClass:[UINavigationController class]]) vc = ((UINavigationController *)vc).topViewController ?: vc;
        while (vc.presentedViewController) vc = vc.presentedViewController;
    }
    return vc;
}

static BOOL gCallProbed = NO;
static void ZUSProbeCallFlow(void) {
    if (gCallProbed) return;
    gCallProbed = YES;
    @try {
        int total = 0;
        unsigned cc = 0;
        Class *classes = objc_copyClassList(&cc);
        for (unsigned i = 0; i < cc && total < 160; i++) {
            NSString *cn = NSStringFromClass(classes[i]);
            NSString *low = [cn lowercaseString];
            if (![low containsString:@"call"]) continue;
            if (!([low containsString:@"manager"] || [low containsString:@"controller"] || [low containsString:@"service"] ||
                  [low containsString:@"handler"] || [low containsString:@"action"] || [low containsString:@"alert"] ||
                  [low containsString:@"processor"] || [low containsString:@"helper"])) continue;
            unsigned mc = 0;
            Method *ml = class_copyMethodList(classes[i], &mc);
            for (unsigned j = 0; j < mc && total < 160; j++) {
                NSString *sn = NSStringFromSelector(method_getName(ml[j]));
                NSString *sl = [sn lowercaseString];
                if ([sl containsString:@"incoming"] || [sl containsString:@"receive"] || [sl containsString:@"decline"] ||
                    [sl containsString:@"reject"] || [sl containsString:@"busy"] || [sl containsString:@"answer"] ||
                    [sl containsString:@"startcall"] || [sl containsString:@"makecall"] || [sl containsString:@"voicecall"] ||
                    [sl containsString:@"videocall"] || [sl containsString:@"showcall"] || [sl containsString:@"presentcall"]) {
                    ZUSLog(@"cuộc gọi: ứng viên %@.%@ enc=%s", cn, sn, method_getTypeEncoding(ml[j]));
                    total++;
                }
            }
            free(ml);
        }
        free(classes);
        ZUSLog(@"cuộc gọi: dò xong — %d ứng viên luồng cuộc gọi", total);
        Class rm = objc_getClass("RMIncomingAlertAction");
        if (rm) {
            SEL es = sel_registerName("executeActionWithThreadId:toMuteCall:profileInfo:dataUpdateHandler:");
            Method m = class_getInstanceMethod(rm, es);
            ZUSLog(@"cuộc gọi: RMIncomingAlertAction.execute... %@ enc=%s", m ? @"CÓ" : @"KHÔNG THẤY", m ? method_getTypeEncoding(m) : "-");
        } else {
            ZUSLog(@"cuộc gọi: không thấy lớp RMIncomingAlertAction");
        }
    } @catch (NSException *e) { ZUSLog(@"cuộc gọi: lỗi dò: %@", e.name); }
}

static void ZUSTryDeclineCall(NSString *tid, __unsafe_unretained id actionSelf) {
    @try {
        NSArray *needles = @[@"decline", @"reject", @"endcall", @"hangup", @"busy"];
        if (actionSelf) {
            Class cls = object_getClass(actionSelf);
            unsigned mc = 0;
            Method *ml = class_copyMethodList(cls, &mc);
            for (unsigned i = 0; i < mc; i++) {
                NSString *sn = NSStringFromSelector(method_getName(ml[i]));
                NSString *sl = [sn lowercaseString];
                BOOL hit = NO;
                for (NSString *n in needles) if ([sl containsString:n]) { hit = YES; break; }
                if (!hit) continue;
                int argc = (int)method_getNumberOfArguments(ml[i]) - 2;
                ZUSLog(@"chặn cuộc gọi: ứng viên từ chối %@.%@ (argc %d, enc %s)", NSStringFromClass(cls), sn, argc, method_getTypeEncoding(ml[i]));
                if (argc == 0) {
                    ((void (*)(id, SEL))objc_msgSend)(actionSelf, method_getName(ml[i]));
                    ZUSLog(@"chặn cuộc gọi: đã gọi %@.%@ để báo bận cho %@", NSStringFromClass(cls), sn, tid);
                    free(ml);
                    return;
                }
            }
            free(ml);
        }
        ZUSLog(@"chặn cuộc gọi: chưa tìm thấy đường từ chối không tham số — chế độ MÁY BẬN tạm hoạt động như IM LẶNG ở bản này");
    } @catch (NSException *e) { ZUSLog(@"chặn cuộc gọi: lỗi thử từ chối: %@", e.name); }
}

static void (*gOrigIncomingAlert)(__unsafe_unretained id, SEL, __unsafe_unretained id, BOOL, __unsafe_unretained id, void *) = NULL;

static void ZUSIncomingAlertHook(__unsafe_unretained id self, SEL _cmd, __unsafe_unretained id threadId, BOOL toMute, __unsafe_unretained id profileInfo, void *handler) {
    NSString *tid = [threadId isKindOfClass:[NSString class]] ? (NSString *)threadId : [threadId description];
    static int pinfoLog = 0;
    if (pinfoLog++ < 3 && profileInfo) {
        NSMutableArray *props = [NSMutableArray array];
        unsigned pc = 0;
        objc_property_t *pl = class_copyPropertyList(object_getClass(profileInfo), &pc);
        for (unsigned i = 0; i < pc; i++) [props addObject:@(property_getName(pl[i]))];
        free(pl);
        ZUSLog(@"chặn cuộc gọi: cuộc gọi đến — threadId=%@, profileInfo lớp %@, thuộc tính: %@", tid, NSStringFromClass(object_getClass(profileInfo)), [props componentsJoinedByString:@", "]);
    }
    int mode = 0;
    @try {
        id v = tid ? gCallBlock[tid] : nil;
        if ([v isKindOfClass:[NSNumber class]]) mode = [v intValue];
    } @catch (NSException *e) {}
    if (mode == 1) {
        ZUSLog(@"chặn cuộc gọi: NUỐT báo cuộc gọi đến từ %@ (IM LẶNG) — máy không chuông, không hiện; bên kia vẫn nghe đổ chuông", tid);
        return;
    }
    if (mode == 2) {
        ZUSLog(@"chặn cuộc gọi: NUỐT báo cuộc gọi đến từ %@ (MÁY BẬN) — thử đường từ chối", tid);
        ZUSTryDeclineCall(tid, self);
        return;
    }
    if (gOrigIncomingAlert) gOrigIncomingAlert(self, _cmd, threadId, toMute, profileInfo, handler);
}


// ----- 1.3.2: chặn cuộc gọi qua executeActionWithItem:context: -----
static void (*gOrigIncomingItem)(__unsafe_unretained id, SEL, __unsafe_unretained id, __unsafe_unretained id) = NULL;

static void ZUSIncomingItemHook(__unsafe_unretained id self, SEL _cmd, __unsafe_unretained id item, __unsafe_unretained id context) {
    static int probe = 0;
    NSString *tid = nil;
    @try {
        NSArray *keys = @[@"threadId", @"threadID", @"conversationId", @"conversationID", @"userId", @"userID", @"uid", @"fromUserId", @"fromId", @"senderId", @"callerId", @"id"];
        tid = ZUSStringField(item, keys);
        if (!tid.length) tid = ZUSStringField(context, keys);
        if (probe < 3) {
            NSMutableArray *props = [NSMutableArray array];
            unsigned pc = 0;
            objc_property_t *pl = item ? class_copyPropertyList(object_getClass(item), &pc) : NULL;
            for (unsigned i = 0; i < pc; i++) [props addObject:@(property_getName(pl[i]))];
            free(pl);
            NSMutableArray *cprops = [NSMutableArray array];
            unsigned cc2 = 0;
            objc_property_t *pl2 = context ? class_copyPropertyList(object_getClass(context), &cc2) : NULL;
            for (unsigned i = 0; i < cc2; i++) [cprops addObject:@(property_getName(pl2[i]))];
            free(pl2);
            ZUSLog(@"chặn cuộc gọi: cuộc gọi đến (đường item) — item lớp %@ (thuộc tính: %@), context lớp %@ (thuộc tính: %@), mã đoạn trích được: %@",
                   item ? NSStringFromClass(object_getClass(item)) : @"(nil)", [props componentsJoinedByString:@", "],
                   context ? NSStringFromClass(object_getClass(context)) : @"(nil)", [cprops componentsJoinedByString:@", "],
                   tid.length ? tid : @"(chưa trích được)");
        }
    } @catch (NSException *e) {}
    if (probe < 3) probe++;
    int mode = 0;
    @try {
        id v = tid.length ? gCallBlock[tid] : nil;
        if ([v isKindOfClass:[NSNumber class]]) mode = [v intValue];
    } @catch (NSException *e) {}
    if (mode == 1) {
        ZUSLog(@"chặn cuộc gọi: NUỐT cuộc gọi đến từ %@ (IM LẶNG, đường item) — máy không chuông, không hiện", tid);
        return;
    }
    if (mode == 2) {
        ZUSLog(@"chặn cuộc gọi: NUỐT cuộc gọi đến từ %@ (MÁY BẬN, đường item) — thử đường từ chối", tid);
        ZUSTryDeclineCall(tid, self);
        return;
    }
    if (gOrigIncomingItem) gOrigIncomingItem(self, _cmd, item, context);
}

static BOOL gCallBlockInstalled = NO;
static void ZUSInstallCallBlock(void) {
    if (gCallBlockInstalled) return;
    @try {
        SEL es = sel_registerName("executeActionWithThreadId:toMuteCall:profileInfo:dataUpdateHandler:");
        // 1.3.0: objc_getClass tra ve mot lop khong co ham nay, trong khi
        // log ung vien 1.0.3 tung thay no — co the co nhieu lop trung ten
        // (binary chinh + framework nhung) hoac ham nam o lop khac. V2
        // liet ke MOI lop trung ten, dump danh sach ham cua tung lop vao
        // log, va moc vao lop nao co dung selector; chua thay thi thu lai.
        NSMutableArray *matches = [NSMutableArray array];
        ZUSCollectClassesNamed(@"RMIncomingAlertAction", matches);
        if (!matches.count) { ZUSLog(@"chặn cuộc gọi: không thấy lớp nào tên RMIncomingAlertAction"); return; }
        static BOOL dumped = NO;
        for (Class cls in matches) {
            Method m = class_getInstanceMethod(cls, es);
            if (!dumped) {
                unsigned mc = 0;
                Method *ml = class_copyMethodList(cls, &mc);
                NSMutableArray *names = [NSMutableArray array];
                for (unsigned i = 0; i < mc; i++) [names addObject:NSStringFromSelector(method_getName(ml[i]))];
                free(ml);
                ZUSLog(@"chặn cuộc gọi: lớp %@ (%@) — %d hàm: %@", NSStringFromClass(cls), ZUSClassIsZaloImage(cls) ? @"image Zalo" : @"image khác", mc, [names componentsJoinedByString:@", "]);
            }
            // 1.3.2: selector THẬT của bản Zalo này — thử trước.
            SEL ns = sel_registerName("executeActionWithItem:context:");
            Method nm = class_getInstanceMethod(cls, ns);
            if (nm) {
                NSString *e2 = [NSString stringWithUTF8String:method_getTypeEncoding(nm) ?: ""];
                char *a0 = method_copyArgumentType(nm, 2);
                char *a1 = method_copyArgumentType(nm, 3);
                BOOL ok2 = [e2 hasPrefix:@"v"] && (int)method_getNumberOfArguments(nm) - 2 == 2 && a0 && a1 && a0[0] == '@' && a1[0] == '@';
                free(a0); free(a1);
                if (ok2) {
                    MSHookMessageEx(cls, ns, (IMP)ZUSIncomingItemHook, (IMP *)&gOrigIncomingItem);
                    gCallBlockInstalled = YES;
                    dumped = YES;
                    ZUSLog(@"chặn cuộc gọi: đã lắp móc vào %@.executeActionWithItem:context: (enc %@)", NSStringFromClass(cls), e2);
                    return;
                }
                ZUSLog(@"chặn cuộc gọi: executeActionWithItem:context: chữ ký lạ (%@) trên %@ — không lắp", e2, NSStringFromClass(cls));
            }
            if (!m) continue;
            NSString *e = [NSString stringWithUTF8String:method_getTypeEncoding(m) ?: ""];
            BOOL ok = [e hasPrefix:@"v"] && ([e containsString:@"B"] || [e containsString:@"c"]) && [e containsString:@"@?"];
            if (!ok) {
                ZUSLog(@"chặn cuộc gọi: chữ ký executeAction lạ (%@) trên %@ — KHÔNG lắp móc chặn ở bản này, chỉ dò", e, NSStringFromClass(cls));
                gCallBlockInstalled = YES;
                dumped = YES;
                return;
            }
            MSHookMessageEx(cls, es, (IMP)ZUSIncomingAlertHook, (IMP *)&gOrigIncomingAlert);
            gCallBlockInstalled = YES;
            dumped = YES;
            ZUSLog(@"chặn cuộc gọi: đã lắp móc vào %@.executeAction... (enc %@)", NSStringFromClass(cls), e);
            return;
        }
        dumped = YES;
        ZUSLog(@"chặn cuộc gọi: %lu lớp tên RMIncomingAlertAction nhưng không lớp nào có executeAction... — sẽ thử lại", (unsigned long)matches.count);
        static int attempts = 0;
        if (++attempts <= 3) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSInstallCallBlock(); });
        }
    } @catch (NSException *e) { ZUSLog(@"chặn cuộc gọi: lỗi lắp: %@", e.name); }
}

// ----- Xác nhận trước khi gọi -----
static NSMutableDictionary *gConfirmOrigs = nil;
static id gPendSelf = nil;
static SEL gPendSel = NULL;
static id gPendA1 = nil;
static void *gPendOrig = NULL;
static int gPendArgc = 0;

static void ZUSRunPendingCall(void) {
    if (!gPendOrig) return;
    void *o = gPendOrig;
    id s = gPendSelf, a = gPendA1;
    SEL c = gPendSel;
    int argc = gPendArgc;
    gPendOrig = NULL; gPendSelf = nil; gPendA1 = nil; gPendSel = NULL;
    if (argc == 1) ((void (*)(id, SEL, id))o)(s, c, a);
    else ((void (*)(id, SEL))o)(s, c);
}

static void ZUSConfirmGate(id self, SEL _cmd, id a1, void *orig, int argc) {
    if (!orig) return;
    if (!gConfirmCall || !gEnabled || !gLicensed) {
        if (argc == 1) ((void (*)(id, SEL, id))orig)(self, _cmd, a1);
        else ((void (*)(id, SEL))orig)(self, _cmd);
        return;
    }
    gPendSelf = self; gPendSel = _cmd; gPendA1 = a1; gPendOrig = orig; gPendArgc = argc;
    ZUSLog(@"xác nhận gọi: giữ lại %@.%@ chờ anh xác nhận", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd));
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = ZUSTopVC();
        if (!vc) { ZUSRunPendingCall(); return; }
        NSString *who = gZUSCurrentThreadName.length ? gZUSCurrentThreadName : @"người này";
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Xác nhận cuộc gọi"
            message:[NSString stringWithFormat:@"Bắt đầu cuộc gọi với %@?", who] preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:^(UIAlertAction *act) {
            gPendOrig = NULL; gPendSelf = nil; gPendA1 = nil; gPendSel = NULL;
            ZUSLog(@"xác nhận gọi: anh đã huỷ cuộc gọi");
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Gọi" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) { ZUSRunPendingCall(); }]];
        [vc presentViewController:a animated:YES completion:nil];
    });
}

static void ZUSConfirmHook1(id self, SEL _cmd, id a1) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    ZUSConfirmGate(self, _cmd, a1, [gConfirmOrigs[key] pointerValue], 1);
}

static void ZUSConfirmHook0(id self, SEL _cmd) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    ZUSConfirmGate(self, _cmd, nil, [gConfirmOrigs[key] pointerValue], 0);
}

// 1.3.1: móc typed cho ứng viên gọi đi dạng 4 tham số (@,q,q,@) —
// ZACallOARouter.makeCallOAToUserId:callType:sourceCall:data: trong log
// 1.3.0 bị cổng chữ ký bỏ qua vì không thuộc dạng 0/1 tham số.
static id gPend4Self = nil;
static SEL gPend4Sel = NULL;
static id gPend4A1 = nil;
static long long gPend4A2 = 0;
static long long gPend4A3 = 0;
static id gPend4A4 = nil;
static void *gPend4Orig = NULL;

static void ZUSRunPendingCall4(void) {
    if (!gPend4Orig) return;
    void *o = gPend4Orig;
    id sf = gPend4Self; SEL c = gPend4Sel; id a1 = gPend4A1; long long a2 = gPend4A2, a3 = gPend4A3; id a4 = gPend4A4;
    gPend4Orig = NULL; gPend4Self = nil; gPend4A1 = nil; gPend4A4 = nil; gPend4Sel = NULL;
    ((void (*)(id, SEL, id, long long, long long, id))o)(sf, c, a1, a2, a3, a4);
}

static void ZUSConfirmHook4(id self, SEL _cmd, id a1, long long a2, long long a3, id a4) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gConfirmOrigs[key] pointerValue];
    if (!orig) return;
    if (!gConfirmCall || !gEnabled || !gLicensed) {
        ((void (*)(id, SEL, id, long long, long long, id))orig)(self, _cmd, a1, a2, a3, a4);
        return;
    }
    gPend4Self = self; gPend4Sel = _cmd; gPend4A1 = a1; gPend4A2 = a2; gPend4A3 = a3; gPend4A4 = a4; gPend4Orig = orig;
    ZUSLog(@"xác nhận gọi: giữ lại %@.%@ (dạng 4 tham số) chờ anh xác nhận", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd));
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = ZUSTopVC();
        if (!vc) { ZUSRunPendingCall4(); return; }
        NSString *who = gZUSCurrentThreadName.length ? gZUSCurrentThreadName : @"người này";
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Xác nhận cuộc gọi"
            message:[NSString stringWithFormat:@"Bắt đầu cuộc gọi với %@?", who] preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:^(UIAlertAction *act) {
            gPend4Orig = NULL; gPend4Self = nil; gPend4A1 = nil; gPend4A4 = nil; gPend4Sel = NULL;
            ZUSLog(@"xác nhận gọi: anh đã huỷ cuộc gọi");
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Gọi" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) { ZUSRunPendingCall4(); }]];
        [vc presentViewController:a animated:YES completion:nil];
    });
}

static BOOL gConfirmInstalled = NO;
static void ZUSInstallConfirmCall(void) {
    if (gConfirmInstalled) return;
    if (!gConfirmOrigs) gConfirmOrigs = [NSMutableDictionary dictionary];
    @try {
        NSArray *patterns = @[@"startcall", @"makecall", @"callwith", @"startvoicecall", @"startvideocall", @"placecall", @"initiatecall", @"ontapcall", @"callvoip"];
        NSArray *exclude = @[@"set", @"update", @"did", @"will", @"handle", @"receive", @"incoming", @"end", @"stop", @"finish", @"config", @"enable", @"state", @"answer", @"delete", @"fail", @"decline", @"reject"];
        int installed = 0;
        unsigned cc = 0;
        Class *classes = objc_copyClassList(&cc);
        for (unsigned i = 0; i < cc && installed < 4; i++) {
            NSString *cn = NSStringFromClass(classes[i]);
            if (!ZUSClassIsZaloImage(classes[i])) continue;
            NSString *cl = [cn lowercaseString];
            if (![cl containsString:@"chat"] && ![cl containsString:@"call"]) continue;
            unsigned mc = 0;
            Method *ml = class_copyMethodList(classes[i], &mc);
            for (unsigned j = 0; j < mc && installed < 4; j++) {
                Method m = ml[j];
                NSString *sn = NSStringFromSelector(method_getName(m));
                NSString *sl = [sn lowercaseString];
                BOOL hit = NO;
                for (NSString *p in patterns) if ([sl containsString:p]) { hit = YES; break; }
                if (!hit) continue;
                BOOL bad = NO;
                for (NSString *x in exclude) if ([sl containsString:x]) { bad = YES; break; }
                if (bad) continue;
                NSString *e = [NSString stringWithUTF8String:method_getTypeEncoding(m) ?: ""];
                int argc = (int)method_getNumberOfArguments(m) - 2;
                BOOL ok = [e hasPrefix:@"v"] && (argc == 0 || (argc == 1 && [e containsString:@"@"]));
                BOOL is4 = NO;
                if (!ok && argc == 4 && [e hasPrefix:@"v"]) {
                    char *c0 = method_copyArgumentType(m, 2);
                    char *c1 = method_copyArgumentType(m, 3);
                    char *c2 = method_copyArgumentType(m, 4);
                    char *c3 = method_copyArgumentType(m, 5);
                    is4 = c0 && c1 && c2 && c3 && c0[0] == '@' &&
                          (c1[0] == 'q' || c1[0] == 'Q' || c1[0] == 'l' || c1[0] == 'L') &&
                          (c2[0] == 'q' || c2[0] == 'Q' || c2[0] == 'l' || c2[0] == 'L') && c3[0] == '@';
                    free(c0); free(c1); free(c2); free(c3);
                    ok = is4;
                }
                ZUSLog(@"xác nhận gọi: ứng viên %@.%@ enc=%@ — %@", cn, sn, e, ok ? @"SẼ LẮP" : @"bỏ qua (chữ ký không an toàn)");
                if (!ok) continue;
                NSString *key = [NSString stringWithFormat:@"%@|%@", cn, sn];
                if (gConfirmOrigs[key]) continue;
                void *orig = NULL;
                IMP repl = is4 ? (IMP)ZUSConfirmHook4 : ((argc == 1) ? (IMP)ZUSConfirmHook1 : (IMP)ZUSConfirmHook0);
                MSHookMessageEx(classes[i], method_getName(m), repl, (IMP *)&orig);
                if (orig) { gConfirmOrigs[key] = [NSValue valueWithPointer:orig]; installed++; ZUSLog(@"xác nhận gọi: đã lắp móc vào %@", key); }
            }
            free(ml);
        }
        free(classes);
        if (installed) gConfirmInstalled = YES;
        ZUSLog(@"xác nhận gọi: tổng %d móc", installed);
    } @catch (NSException *e) { ZUSLog(@"xác nhận gọi: lỗi lắp: %@", e.name); }
}

// ----- 1.3.0: gửi ảnh chất lượng gốc (dò + ép thử) -----
// Chưa có bản đồ đường gửi ảnh trong log cũ nên bản này liệt kê các hàm
// liên quan chất lượng/gốc trên các lớp chat/media/ảnh, lắp móc ép thử
// vào các hàm 0 tham số trả BOOL (cờ "gửi gốc") hoặc số thực (hệ số nén)
// — công tắc photoOriginal bật thì ép về gốc/1.0, tắt thì cho qua nguyên.
static BOOL gPhotoProbed = NO;
static NSMutableDictionary *gPhotoOrigs = nil;

static BOOL ZUSPhotoBoolHook(__unsafe_unretained id self, SEL _cmd) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gPhotoOrigs[key] pointerValue];
    BOOL r = orig ? ((BOOL (*)(__unsafe_unretained id, SEL))orig)(self, _cmd) : NO;
    if (gPhotoOriginal) {
        static int lg = 0;
        if (lg++ < 5) ZUSLog(@"ảnh gốc: %@ gốc=%d -> ép YES", key, r);
        return YES;
    }
    return r;
}

static double ZUSPhotoQualityHook(__unsafe_unretained id self, SEL _cmd) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gPhotoOrigs[key] pointerValue];
    double r = orig ? ((double (*)(__unsafe_unretained id, SEL))orig)(self, _cmd) : 0.8;
    if (gPhotoOriginal) {
        static int lg = 0;
        if (lg++ < 5) ZUSLog(@"ảnh gốc: %@ gốc=%.2f -> ép 1.0", key, r);
        return 1.0;
    }
    return r;
}

static void ZUSInstallPhotoOriginal(void) {
    if (gPhotoProbed) return;
    if (!gPhotoOrigs) gPhotoOrigs = [NSMutableDictionary dictionary];
    @try {
        int logged = 0, hooked = 0;
        unsigned cc = 0;
        Class *classes = objc_copyClassList(&cc);
        for (unsigned i = 0; i < cc && logged < 80; i++) {
            NSString *cn = NSStringFromClass(classes[i]);
            if (!ZUSClassIsZaloImage(classes[i])) continue;
            NSString *cl = [cn lowercaseString];
            if (!([cl containsString:@"photo"] || [cl containsString:@"image"] || [cl containsString:@"chat"] || [cl containsString:@"media"])) continue;
            unsigned mc = 0;
            Method *ml = class_copyMethodList(classes[i], &mc);
            for (unsigned j = 0; j < mc && logged < 80; j++) {
                Method m = ml[j];
                NSString *sn = NSStringFromSelector(method_getName(m));
                NSString *sl = [sn lowercaseString];
                if (!([sl containsString:@"original"] || [sl containsString:@"quality"] || [sl containsString:@"compress"] || [sl containsString:@"hd"])) continue;
                if ([sl containsString:@"set"] || [sl containsString:@"update"] || [sl containsString:@"did"]) continue;
                NSString *e = [NSString stringWithUTF8String:method_getTypeEncoding(m) ?: ""];
                int argc = (int)method_getNumberOfArguments(m) - 2;
                ZUSLog(@"ảnh gốc: ứng viên %@.%@ enc=%@", cn, sn, e);
                logged++;
                if (argc != 0 || hooked >= 6) continue;
                NSString *key = [NSString stringWithFormat:@"%@|%@", cn, sn];
                if (gPhotoOrigs[key]) continue;
                void *orig = NULL;
                if ([e hasPrefix:@"B"] || [e hasPrefix:@"c"]) MSHookMessageEx(classes[i], method_getName(m), (IMP)ZUSPhotoBoolHook, (IMP *)&orig);
                else if ([e hasPrefix:@"d"] || [e hasPrefix:@"f"]) MSHookMessageEx(classes[i], method_getName(m), (IMP)ZUSPhotoQualityHook, (IMP *)&orig);
                if (orig) { gPhotoOrigs[key] = [NSValue valueWithPointer:orig]; hooked++; ZUSLog(@"ảnh gốc: đã lắp móc ép chất lượng vào %@", key); }
            }
            free(ml);
        }
        free(classes);
        if (logged || hooked) gPhotoProbed = YES;
        ZUSLog(@"ảnh gốc: dò xong — %d ứng viên, %d móc ép chất lượng", logged, hooked);
    } @catch (NSException *e) { ZUSLog(@"ảnh gốc: lỗi dò: %@", e.name); }
}

// ----- 1.3.0: thêm emoji react (dò + chèn thử) -----
// React của Zalo mang theo chuỗi biểu tượng (iconReactString trong log
// 1.0.3) nên còn hy vọng: bản này liệt kê các lớp/hàm react, lắp móc vào
// hàm trả danh sách react (0 tham số) — công tắc moreEmoji bật thì chèn
// thêm emoji vào danh sách nếu phần tử là chuỗi. Phía server có chấp
// nhận emoji lạ hay không, log + test thật mới trả lời được.
static BOOL gEmojiProbed = NO;
static NSMutableDictionary *gEmojiOrigs = nil;

static id ZUSEmojiListHook(id self, SEL _cmd) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gEmojiOrigs[key] pointerValue];
    id r = orig ? ((id (*)(id, SEL))orig)(self, _cmd) : nil;
    @try {
        static BOOL sampleLogged = NO;
        if (!sampleLogged && [r isKindOfClass:[NSArray class]] && [r count]) {
            sampleLogged = YES;
            id e0 = r[0];
            NSMutableArray *props = [NSMutableArray array];
            if (![e0 isKindOfClass:[NSString class]]) {
                unsigned pc = 0;
                objc_property_t *pl = class_copyPropertyList(object_getClass(e0), &pc);
                for (unsigned i = 0; i < pc; i++) [props addObject:@(property_getName(pl[i]))];
                free(pl);
            }
            ZUSLog(@"emoji react: danh sách mẫu — phần tử lớp %@, thuộc tính: %@, giá trị đầu: %@", NSStringFromClass(object_getClass(e0)), [props componentsJoinedByString:@", "], [e0 description]);
        }
        if (gMoreEmoji && [r isKindOfClass:[NSArray class]] && [r count] && [r[0] isKindOfClass:[NSString class]]) {
            NSArray *extra = @[@"😆", @"😮", @"😢", @"😡", @"👏", @"🔥"];
            NSMutableArray *out = [r mutableCopy];
            for (NSString *e in extra) if (![out containsObject:e]) [out addObject:e];
            if (out.count != [r count]) ZUSLog(@"emoji react: đã chèn thêm %lu emoji vào danh sách react", (unsigned long)(out.count - [r count]));
            return out;
        }
    } @catch (NSException *e) {}
    return r;
}

static void ZUSInstallEmojiProbe(void) {
    if (gEmojiProbed) return;
    gEmojiProbed = YES;
    if (!gEmojiOrigs) gEmojiOrigs = [NSMutableDictionary dictionary];
    @try {
        int logged = 0, hooked = 0;
        unsigned cc = 0;
        Class *classes = objc_copyClassList(&cc);
        for (unsigned i = 0; i < cc && logged < 100; i++) {
            NSString *cn = NSStringFromClass(classes[i]);
            if (!ZUSClassIsZaloImage(classes[i])) continue;
            NSString *cl = [cn lowercaseString];
            if (![cl containsString:@"react"] && ![cl containsString:@"emotion"]) continue;
            unsigned mc = 0;
            Method *ml = class_copyMethodList(classes[i], &mc);
            for (unsigned j = 0; j < mc && logged < 100; j++) {
                Method m = ml[j];
                NSString *sn = NSStringFromSelector(method_getName(m));
                NSString *sl = [sn lowercaseString];
                if ([sl containsString:@"react"] || [sl containsString:@"emotion"] || [sl containsString:@"emoji"]) {
                    ZUSLog(@"emoji react: ứng viên %@.%@ enc=%s", cn, sn, method_getTypeEncoding(m));
                    logged++;
                }
                int argc = (int)method_getNumberOfArguments(m) - 2;
                NSString *e = [NSString stringWithUTF8String:method_getTypeEncoding(m) ?: ""];
                if (argc == 0 && [e hasPrefix:@"@"] && hooked < 3 &&
                    ([sl containsString:@"list"] || [sl containsString:@"all"] || [sl containsString:@"items"] ||
                     [sl containsString:@"default"] || [sl containsString:@"emojis"] || [sl containsString:@"reactions"])) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", cn, sn];
                    if (!gEmojiOrigs[key]) {
                        void *orig = NULL;
                        MSHookMessageEx(classes[i], method_getName(m), (IMP)ZUSEmojiListHook, (IMP *)&orig);
                        if (orig) { gEmojiOrigs[key] = [NSValue valueWithPointer:orig]; hooked++; ZUSLog(@"emoji react: đã lắp móc danh sách vào %@", key); }
                    }
                }
            }
            free(ml);
        }
        free(classes);
        ZUSLog(@"emoji react: dò xong — %d ứng viên, %d móc danh sách", logged, hooked);
    } @catch (NSException *e) { ZUSLog(@"emoji react: lỗi dò: %@", e.name); }
}

// ----- 1.1.7: dò quảng cáo trong danh sách chat (mức dò) -----
static NSMutableDictionary *gAdOrigs = nil;
static NSMutableSet *gAdFlagged = nil;
static NSMutableDictionary *gAdHeightOrigs = nil;
static NSMutableDictionary *gAdCellOrigs = nil;
static NSMutableDictionary *gAdSizeOrigs = nil;

static BOOL ZUSAdScanCell(__unsafe_unretained id cell) {
    static NSMutableSet *logged = nil;
    if (!logged) logged = [NSMutableSet set];
    NSString *ccn = NSStringFromClass([cell class]);
    id model = nil;
    NSArray *mk = @[@"conversation", @"conversationModel", @"model", @"item", @"data", @"entity", @"object", @"viewModel", @"cellModel"];
    for (NSString *k in mk) {
        @try { model = [cell valueForKey:k]; } @catch (NSException *e) {}
        if (model) break;
    }
    NSString *combo = [NSString stringWithFormat:@"%@>%@", ccn, model ? NSStringFromClass([model class]) : @"-"];
    if (![logged containsObject:combo]) {
        [logged addObject:combo];
        if (model) {
            NSMutableArray *props = [NSMutableArray array];
            unsigned pc = 0;
            objc_property_t *pl = class_copyPropertyList([model class], &pc);
            for (unsigned i = 0; i < pc; i++) [props addObject:@(property_getName(pl[i]))];
            free(pl);
            ZUSLog(@"quảng cáo: ô %@ — model %@ — thuộc tính: %@", ccn, NSStringFromClass([model class]), [props componentsJoinedByString:@", "]);
        } else {
            ZUSLog(@"quảng cáo: ô %@ — chưa lấy được model từ ô", ccn);
        }
    }
    if (!model) return NO;
    NSArray *flags = @[@"isAds", @"isAd", @"ads", @"isSponsored", @"sponsored", @"isPromotion", @"promotion", @"isPromoted", @"isAdvertisement", @"advertisement", @"isAdsContent"];
    for (NSString *f in flags) {
        id v = nil;
        @try { v = [model valueForKey:f]; } @catch (NSException *e) {}
        if ([v isKindOfClass:[NSNumber class]] && [v boolValue]) {
            ZUSLog(@"quảng cáo: PHÁT HIỆN ô quảng cáo — %@.%@ = 1 (ô %@)", NSStringFromClass([model class]), f, ccn);
            return YES;
        }
    }
    NSString *mcn = NSStringFromClass([model class]);
    NSArray *nameHints = @[@"Ads", @"Advert", @"Sponsored", @"Promotion", @"MediaBox", @"ZCloud", @"QuangCao", @"BannerAd"];
    for (NSString *h in nameHints) {
        if ([ccn containsString:h] || [mcn containsString:h]) {
            ZUSLog(@"quảng cáo: PHÁT HIỆN theo tên lớp — ô %@, model %@", ccn, mcn);
            return YES;
        }
    }
    return NO;
}

static void ZUSAdWillDisplay(__unsafe_unretained id self, SEL _cmd, __unsafe_unretained id view, __unsafe_unretained id cell, __unsafe_unretained id ip) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gAdOrigs[key] pointerValue];
    if (orig) ((void (*)(__unsafe_unretained id, SEL, __unsafe_unretained id, __unsafe_unretained id, __unsafe_unretained id))orig)(self, _cmd, view, cell, ip);
    if (!gAdBlock) return;
    @try {
        if (ZUSAdScanCell(cell)) {
            ((UITableViewCell *)cell).hidden = YES;
            if (!gAdFlagged) gAdFlagged = [NSMutableSet set];
            [gAdFlagged addObject:[NSString stringWithFormat:@"%p|%ld-%ld", view, (long)[ip section], (long)[ip row]]];
        }
    } @catch (NSException *e) {}
}

static double ZUSAdHeightForRow(id self, SEL _cmd, id view, id ip) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gAdHeightOrigs[key] pointerValue];
    double h = orig ? ((double (*)(id, SEL, id, id))orig)(self, _cmd, view, ip) : 44.0;
    if (!gAdBlock) return h;
    @try {
        NSString *fk = [NSString stringWithFormat:@"%p|%ld-%ld", view, (long)[ip section], (long)[ip row]];
        if ([gAdFlagged containsObject:fk]) return 0.01;
    } @catch (NSException *e) {}
    return h;
}

static id ZUSAdCellForRow(id self, SEL _cmd, id view, id ip) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gAdCellOrigs[key] pointerValue];
    id cell = orig ? ((id (*)(id, SEL, id, id))orig)(self, _cmd, view, ip) : nil;
    if (!cell || !gAdBlock) return cell;
    @try {
        if (!gAdFlagged) gAdFlagged = [NSMutableSet set];
        NSString *fk = [NSString stringWithFormat:@"%p|%ld-%ld", view, (long)[ip section], (long)[ip row]];
        if (ZUSAdScanCell(cell)) {
            if (![gAdFlagged containsObject:fk]) {
                [gAdFlagged addObject:fk];
                ZUSLog(@"quảng cáo: đã đánh dấu ô %@ để thu gọn (mục %ld-%ld)", NSStringFromClass([cell class]), (long)[ip section], (long)[ip row]);
            }
            ((UITableViewCell *)cell).hidden = YES;
        } else {
            [gAdFlagged removeObject:fk];
        }
    } @catch (NSException *e) {}
    return cell;
}

static void ZUSFindTables(UIView *v, NSMutableArray *out, int depth) {
    if (!v || depth > 7) return;
    if ([v isKindOfClass:[UITableView class]]) [out addObject:v];
    for (UIView *sv in v.subviews) ZUSFindTables(sv, out, depth + 1);
}

// Vòng 2 (1.3.0): bản 1.1.7 móc willDisplayCell trên lớp của từng tab —
// InboxViewController không tự cài hàm đó nên danh sách chat không bao giờ
// được quét. Vòng này chui vào cây view của từng tab, tìm các bảng thật
// rồi móc delegate/dataSource THẬT của chúng (chiều cao + lấy ô + hiển thị).
static void ZUSAdHookTablesIn(__unsafe_unretained id vc) {
    @try {
        if (![vc isKindOfClass:[UIViewController class]]) return;
        UIView *root = ((UIViewController *)vc).viewIfLoaded;
        if (!root) return;
        NSMutableArray *tables = [NSMutableArray array];
        ZUSFindTables(root, tables, 0);
        if (!gAdHeightOrigs) gAdHeightOrigs = [NSMutableDictionary dictionary];
        if (!gAdCellOrigs) gAdCellOrigs = [NSMutableDictionary dictionary];
        if (!gAdFlagged) gAdFlagged = [NSMutableSet set];
        static NSMutableSet *loggedPairs = nil;
        if (!loggedPairs) loggedPairs = [NSMutableSet set];
        for (UITableView *tv in tables) {
            id del = tv.delegate;
            id ds = tv.dataSource;
            NSString *pair = [NSString stringWithFormat:@"%@|del:%@|ds:%@", NSStringFromClass([vc class]), del ? NSStringFromClass([del class]) : @"-", ds ? NSStringFromClass([ds class]) : @"-"];
            if (![loggedPairs containsObject:pair]) {
                [loggedPairs addObject:pair];
                ZUSLog(@"quảng cáo: bảng trong %@ — delegate %@, dataSource %@", NSStringFromClass([vc class]), del ? NSStringFromClass([del class]) : @"(không)", ds ? NSStringFromClass([ds class]) : @"(không)");
            }
            if (del) {
                Class dc = object_getClass(del);
                SEL hs = sel_registerName("tableView:heightForRowAtIndexPath:");
                if (class_getInstanceMethod(dc, hs)) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(dc), NSStringFromSelector(hs)];
                    if (!gAdHeightOrigs[key]) {
                        void *orig = NULL;
                        MSHookMessageEx(dc, hs, (IMP)ZUSAdHeightForRow, (IMP *)&orig);
                        if (orig) { gAdHeightOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc chiều cao ô vào %@", key); }
                    }
                }
                SEL ws = sel_registerName("tableView:willDisplayCell:forRowAtIndexPath:");
                if (class_getInstanceMethod(dc, ws)) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(dc), NSStringFromSelector(ws)];
                    if (!gAdOrigs[key]) {
                        void *orig = NULL;
                        MSHookMessageEx(dc, ws, (IMP)ZUSAdWillDisplay, (IMP *)&orig);
                        if (orig) { gAdOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc hiển thị ô (delegate thật) vào %@", key); }
                    }
                }
            }
            if (ds) {
                Class sc = object_getClass(ds);
                SEL cs = sel_registerName("tableView:cellForRowAtIndexPath:");
                if (class_getInstanceMethod(sc, cs)) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(sc), NSStringFromSelector(cs)];
                    if (!gAdCellOrigs[key]) {
                        void *orig = NULL;
                        MSHookMessageEx(sc, cs, (IMP)ZUSAdCellForRow, (IMP *)&orig);
                        if (orig) { gAdCellOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc lấy ô vào %@", key); }
                    }
                }
            }
        }
    } @catch (NSException *e) { ZUSLog(@"quảng cáo: lỗi chui cây view: %@", e.name); }
}


// ----- 1.3.1: quảng cáo v3 -----
// Log 1.3.0: walker cũ tìm UITableView trong cây view của từng tab bằng
// viewIfLoaded — tab chưa chọn thì view chưa nạp nên bỏ qua lặng lẽ, và
// ngay tab Inbox đang chọn cũng không có UITableView nào (danh sách chat
// nhiều khả năng là UICollectionView). V3 đi từ CỬA SỔ chính (thứ đang
// thật sự hiển thị), nhận cả hai loại danh sách, và ghi sổ từng danh
// sách thấy được để log vòng sau khỏi đoán mò.
static id ZUSAdCellForItem(id self, SEL _cmd, id view, id ip) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gAdCellOrigs[key] pointerValue];
    id cell = orig ? ((id (*)(id, SEL, id, id))orig)(self, _cmd, view, ip) : nil;
    if (!cell || !gAdBlock) return cell;
    @try {
        if (!gAdFlagged) gAdFlagged = [NSMutableSet set];
        NSString *fk = [NSString stringWithFormat:@"%p|%ld-%ld", view, (long)[ip section], (long)[ip row]];
        if (ZUSAdScanCell(cell)) {
            if (![gAdFlagged containsObject:fk]) {
                [gAdFlagged addObject:fk];
                ZUSLog(@"quảng cáo: đã đánh dấu ô %@ để thu gọn (mục %ld-%ld)", NSStringFromClass([cell class]), (long)[ip section], (long)[ip row]);
            }
            ((UIView *)cell).hidden = YES;
        } else {
            [gAdFlagged removeObject:fk];
        }
    } @catch (NSException *e) {}
    return cell;
}

static CGSize ZUSAdSizeForItem(id self, SEL _cmd, id cv, id layout, id ip) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gAdSizeOrigs[key] pointerValue];
    CGSize sz = orig ? ((CGSize (*)(id, SEL, id, id, id))orig)(self, _cmd, cv, layout, ip) : CGSizeMake(50, 50);
    if (!gAdBlock) return sz;
    @try {
        NSString *fk = [NSString stringWithFormat:@"%p|%ld-%ld", cv, (long)[ip section], (long)[ip row]];
        if ([gAdFlagged containsObject:fk]) return CGSizeMake(0.01, 0.01);
    } @catch (NSException *e) {}
    return sz;
}

static void ZUSFindScrolls(UIView *v, NSMutableArray *out, int depth) {
    if (!v || depth > 12) return;
    if ([v isKindOfClass:[UITableView class]] || [v isKindOfClass:[UICollectionView class]]) [out addObject:v];
    for (UIView *sv in v.subviews) ZUSFindScrolls(sv, out, depth + 1);
}

static void ZUSAdHookScrollsIn(UIView *root, NSString *where) {
    if (!root) return;
    @try {
        NSMutableArray *scrolls = [NSMutableArray array];
        ZUSFindScrolls(root, scrolls, 0);
        if (!gAdHeightOrigs) gAdHeightOrigs = [NSMutableDictionary dictionary];
        if (!gAdCellOrigs) gAdCellOrigs = [NSMutableDictionary dictionary];
        if (!gAdSizeOrigs) gAdSizeOrigs = [NSMutableDictionary dictionary];
        if (!gAdOrigs) gAdOrigs = [NSMutableDictionary dictionary];
        if (!gAdFlagged) gAdFlagged = [NSMutableSet set];
        static NSMutableSet *seenScrolls = nil;
        if (!seenScrolls) seenScrolls = [NSMutableSet set];
        for (UIView *sv in scrolls) {
            BOOL isTable = [sv isKindOfClass:[UITableView class]];
            id del = nil, ds = nil;
            if (isTable) { del = ((UITableView *)sv).delegate; ds = ((UITableView *)sv).dataSource; }
            else { del = ((UICollectionView *)sv).delegate; ds = ((UICollectionView *)sv).dataSource; }
            NSString *triple = [NSString stringWithFormat:@"%@|%@|del:%@|ds:%@", NSStringFromClass([sv class]), where,
                                del ? NSStringFromClass([del class]) : @"-", ds ? NSStringFromClass([ds class]) : @"-"];
            if (![seenScrolls containsObject:triple]) {
                [seenScrolls addObject:triple];
                ZUSLog(@"quảng cáo: thấy %@ trong %@ — delegate %@, dataSource %@", NSStringFromClass([sv class]), where,
                       del ? NSStringFromClass([del class]) : @"(không)", ds ? NSStringFromClass([ds class]) : @"(không)");
            }
            if (del) {
                Class dc = object_getClass(del);
                if (isTable) {
                    SEL hs = sel_registerName("tableView:heightForRowAtIndexPath:");
                    if (class_getInstanceMethod(dc, hs)) {
                        NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(dc), NSStringFromSelector(hs)];
                        if (!gAdHeightOrigs[key]) {
                            void *orig = NULL;
                            MSHookMessageEx(dc, hs, (IMP)ZUSAdHeightForRow, (IMP *)&orig);
                            if (orig) { gAdHeightOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc chiều cao ô vào %@", key); }
                        }
                    }
                } else {
                    SEL ss = sel_registerName("collectionView:layout:sizeForItemAtIndexPath:");
                    if (class_getInstanceMethod(dc, ss)) {
                        NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(dc), NSStringFromSelector(ss)];
                        if (!gAdSizeOrigs[key]) {
                            void *orig = NULL;
                            MSHookMessageEx(dc, ss, (IMP)ZUSAdSizeForItem, (IMP *)&orig);
                            if (orig) { gAdSizeOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc kích thước ô (collection) vào %@", key); }
                        }
                    }
                }
                SEL ws = sel_registerName(isTable ? "tableView:willDisplayCell:forRowAtIndexPath:" : "collectionView:willDisplayCell:forItemAtIndexPath:");
                if (class_getInstanceMethod(dc, ws)) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(dc), NSStringFromSelector(ws)];
                    if (!gAdOrigs[key]) {
                        void *orig = NULL;
                        MSHookMessageEx(dc, ws, (IMP)ZUSAdWillDisplay, (IMP *)&orig);
                        if (orig) { gAdOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc hiển thị ô (delegate thật) vào %@", key); }
                    }
                }
            }
            if (ds) {
                Class sc = object_getClass(ds);
                SEL cs = sel_registerName(isTable ? "tableView:cellForRowAtIndexPath:" : "collectionView:cellForItemAtIndexPath:");
                if (class_getInstanceMethod(sc, cs)) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(sc), NSStringFromSelector(cs)];
                    if (!gAdCellOrigs[key]) {
                        void *orig = NULL;
                        MSHookMessageEx(sc, cs, isTable ? (IMP)ZUSAdCellForRow : (IMP)ZUSAdCellForItem, (IMP *)&orig);
                        if (orig) { gAdCellOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc lấy ô vào %@", key); }
                    }
                }
            }
        }
    } @catch (NSException *e) { ZUSLog(@"quảng cáo: lỗi quét danh sách: %@", e.name); }
}

static void ZUSAttachMediaLPToView(UIView *root) {
    if (!root) return;
    @try {
        UIView *scroll = nil;
        NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
        while (stack.count && !scroll) {
            UIView *cur = stack.lastObject;
            [stack removeLastObject];
            if ([cur isKindOfClass:[UITableView class]] || [cur isKindOfClass:[UICollectionView class]]) { scroll = cur; break; }
            for (UIView *sub in cur.subviews) [stack addObject:sub];
        }
        if (scroll && !objc_getAssociatedObject(scroll, &kZUSMediaLPAssoc)) {
            objc_setAssociatedObject(scroll, &kZUSMediaLPAssoc, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            static ZUSInAppHandler *mediaHandler = nil;
            if (!mediaHandler) mediaHandler = [[ZUSInAppHandler alloc] init];
            UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:mediaHandler action:@selector(zu_mediaLongPress:)];
            lp.minimumPressDuration = 0.45;
            [scroll addGestureRecognizer:lp];
            ZUSLog(@"nhật ký: đã gắn ấn-giữ tải media vào %@ của màn hình Nhật ký", NSStringFromClass([scroll class]));
        }
    } @catch (NSException *e) { ZUSLog(@"nhật ký: lỗi gắn ấn-giữ: %@", e.name); }
}

static void ZUSAdWalkAndHook(void) {
    UIWindow *win = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { win = w; break; }
        if (win) break;
    }
    if (!win) { ZUSLog(@"quảng cáo: chưa thấy cửa sổ chính — sẽ thử lại"); return; }
    // 1.3.1: quét thẳng cây view của cửa sổ chính — bắt được danh sách
    // đang hiển thị dù nó thuộc tab/ màn hình nào, cả bảng lẫn collection.
    ZUSAdHookScrollsIn(win, @"cửa sổ chính");
    UIViewController *root = win.rootViewController;
    if (!root) return;
    NSMutableArray *tops = [NSMutableArray array];
    if ([root isKindOfClass:[UITabBarController class]]) {
        for (UIViewController *c in ((UITabBarController *)root).viewControllers) {
            UIViewController *top = c;
            if ([c isKindOfClass:[UINavigationController class]]) top = ((UINavigationController *)c).topViewController ?: c;
            if (top) [tops addObject:top];
        }
    } else [tops addObject:root];
    for (UIViewController *vc in tops) {
        Class cls = [vc class];
        ZUSLog(@"quảng cáo: màn hình tab — %@", NSStringFromClass(cls));
        const char *sels[] = {"tableView:willDisplayCell:forRowAtIndexPath:", "collectionView:willDisplayCell:forItemAtIndexPath:"};
        for (int i = 0; i < 2; i++) {
            SEL sel = sel_registerName(sels[i]);
            if (!class_getInstanceMethod(cls, sel)) continue;
            NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
            if (gAdOrigs[key]) continue;
            void *orig = NULL;
            MSHookMessageEx(cls, sel, (IMP)ZUSAdWillDisplay, (IMP *)&orig);
            if (orig) { gAdOrigs[key] = [NSValue valueWithPointer:orig]; ZUSLog(@"quảng cáo: đã gắn móc dò hiển thị ô vào %@", key); }
        }
        ZUSAdHookTablesIn(vc);
        if ([NSStringFromClass([vc class]) containsString:@"Timeline"]) ZUSAttachMediaLPToView(((UIViewController *)vc).viewIfLoaded);
    }
}

static void ZUSInstallAdDiscovery(void) {
    if (!gAdOrigs) gAdOrigs = [NSMutableDictionary dictionary];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSAdWalkAndHook(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSAdWalkAndHook(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSAdWalkAndHook(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(90 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSAdWalkAndHook(); });
}



// ----- 1.3.1: dò đường lật trạng thái thu hồi -----
// Log cả ngày 11-25 (bản 1.2.2): 4/7 cửa thu hồi cháy và chặn thật
// nhưng bong bóng vẫn lật thành "đã thu hồi"; 3 cửa còn lại
// (updateDBUndo / processUndoWithSocket / _handleRecallWithData)
// không bao giờ cháy. Trạng thái thu hồi được áp ngay trên entity /
// dữ liệu khi gói đồng bộ về, updateUndoWithParser chỉ là hệ quả lúc
// parse. Vòng này: (1) census mọi hàm chứa undo/recall/revoke trên các
// lớp TableItem/Entity/Message thuộc image Zalo; (2) thử ép các
// getter BOOL 0-tham-số tên chứa "undo" về NO khi chống thu hồi đang
// bật — nếu ô tin đọc trạng thái qua một getter như vậy thì bong bóng
// giữ được nội dung.
static BOOL gUndoProbeDone = NO;
static NSMutableDictionary *gUndoGetterOrigs = nil;

static BOOL ZUSUndoBoolHook(__unsafe_unretained id self, SEL _cmd) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd)];
    void *orig = [gUndoGetterOrigs[key] pointerValue];
    BOOL r = orig ? ((BOOL (*)(__unsafe_unretained id, SEL))orig)(self, _cmd) : NO;
    if (r && gEnabled && gAntiRecall && gLicensed) {
        static int n = 0;
        if (n++ < 10) ZUSLog(@"thu hồi: ép %@.%@ từ YES về NO (chống thu hồi đang bật)", NSStringFromClass(object_getClass(self)), NSStringFromSelector(_cmd));
        return NO;
    }
    return r;
}

static void ZUSInstallUndoProbe(void) {
    if (gUndoProbeDone) return;
    gUndoProbeDone = YES;
    if (!gUndoGetterOrigs) gUndoGetterOrigs = [NSMutableDictionary dictionary];
    @try {
        int logged = 0, hooked = 0;
        unsigned cc = 0;
        Class *classes = objc_copyClassList(&cc);
        for (unsigned i = 0; i < cc; i++) {
            if (!ZUSClassIsZaloImage(classes[i])) continue;
            NSString *shortN = ZUSClassShortName(classes[i]);
            NSString *sl0 = [shortN lowercaseString];
            if (!([sl0 containsString:@"tableitem"] || [sl0 containsString:@"entity"] || [sl0 containsString:@"message"])) continue;
            unsigned mc = 0;
            Method *ml = class_copyMethodList(classes[i], &mc);
            for (unsigned j = 0; j < mc; j++) {
                Method m = ml[j];
                NSString *sn = NSStringFromSelector(method_getName(m));
                NSString *sl = [sn lowercaseString];
                if (!([sl containsString:@"undo"] || [sl containsString:@"recall"] || [sl containsString:@"revoke"])) continue;
                if (logged < 120) { ZUSLog(@"thu hồi: ứng viên %@.%@ enc=%s", shortN, sn, method_getTypeEncoding(m)); logged++; }
                int argc = (int)method_getNumberOfArguments(m) - 2;
                const char *enc = method_getTypeEncoding(m);
                if (argc == 0 && enc && (enc[0] == 'B' || enc[0] == 'c') && [sl containsString:@"undo"] && hooked < 6) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(classes[i]), sn];
                    if (!gUndoGetterOrigs[key]) {
                        void *orig = NULL;
                        MSHookMessageEx(classes[i], method_getName(m), (IMP)ZUSUndoBoolHook, (IMP *)&orig);
                        if (orig) { gUndoGetterOrigs[key] = [NSValue valueWithPointer:orig]; hooked++; ZUSLog(@"thu hồi: đã lắp móc ép getter %@", key); }
                    }
                }
            }
            free(ml);
        }
        free(classes);
        ZUSLog(@"thu hồi: dò xong đường lật trạng thái — %d ứng viên, %d móc ép getter", logged, hooked);
    } @catch (NSException *e) { ZUSLog(@"thu hồi: lỗi dò: %@", e.name); }
}

// ----- 1.2.0: popup kích hoạt (cửa sổ riêng, luôn nằm trên bảng ZUS) -----
@interface ZUSLicenseController : UIViewController
@property (nonatomic, strong) UITextField *zusField;
@property (nonatomic, strong) UILabel *zusMsg;
@property (nonatomic, strong) UILabel *zusCount;
@property (nonatomic, strong) NSTimer *zusTimer;
@property (nonatomic) int zusLeft;
@property (nonatomic, strong) UIView *zusCard;
@property (nonatomic, strong) NSLayoutConstraint *zusCardCenterY;
@end

@implementation ZUSLicenseController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:card];
    self.zusCard = card;
    self.zusCardCenterY = [card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        self.zusCardCenterY,
        [card.widthAnchor constraintEqualToConstant:324],
    ]];
    UILabel *title = [[UILabel alloc] init];
    title.text = @"Kích hoạt ZUS";
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    self.zusMsg = [[UILabel alloc] init];
    self.zusMsg.numberOfLines = 0;
    self.zusMsg.font = [UIFont systemFontOfSize:14];
    self.zusMsg.textColor = [UIColor darkGrayColor];
    self.zusMsg.textAlignment = NSTextAlignmentCenter;
    self.zusMsg.text = [NSString stringWithFormat:@"ZUS chưa được kích hoạt.\nMã máy của bạn: %@\nDán key kích hoạt vào ô dưới rồi bấm OK — hoặc bấm Huỷ để thoát ra lấy key.", ZUSDeviceCode()];
    self.zusField = [[UITextField alloc] init];
    self.zusField.borderStyle = UITextBorderStyleRoundedRect;
    self.zusField.placeholder = @"ZUS1-.....";
    self.zusField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.zusField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.zusField.font = [UIFont systemFontOfSize:13];
    [self.zusField.heightAnchor constraintEqualToConstant:44].active = YES;
    UIButton *ok = [UIButton buttonWithType:UIButtonTypeSystem];
    [ok setTitle:@"OK" forState:UIControlStateNormal];
    [ok setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    ok.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    ok.backgroundColor = [UIColor colorWithRed:0.0 green:0.41 blue:1.0 alpha:1.0];
    ok.layer.cornerRadius = 9;
    [ok addTarget:self action:@selector(zus_ok) forControlEvents:UIControlEventTouchUpInside];
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:@"Huỷ" forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont systemFontOfSize:16];
    [cancel addTarget:self action:@selector(zus_cancel) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *btnRow = [[UIStackView alloc] initWithArrangedSubviews:@[cancel, ok]];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.distribution = UIStackViewDistributionFillEqually;
    btnRow.spacing = 12;
    [ok.heightAnchor constraintEqualToConstant:44].active = YES;
    self.zusCount = [[UILabel alloc] init];
    self.zusCount.font = [UIFont systemFontOfSize:12];
    self.zusCount.textColor = [UIColor grayColor];
    self.zusCount.textAlignment = NSTextAlignmentCenter;
    self.zusCount.text = @"Tự đóng sau 30 giây";
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, self.zusMsg, self.zusField, btnRow, self.zusCount]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
    ]];
    self.zusLeft = 30;
    self.zusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(zus_tick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(zus_kbShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(zus_kbHide:) name:UIKeyboardWillHideNotification object:nil];
}

// Bàn phím hiện lên thì tự nâng thẻ popup lên đủ cao để ô dán key và
// nút OK/Huỷ luôn nằm trên bàn phím (lỗi anh chụp ở 1.2.1: bàn phím che
// mất nửa dưới popup). Bàn phím hạ xuống thì thẻ về giữa như cũ.
- (void)zus_kbShow:(NSNotification *)n {
    CGRect kb = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect kbInView = [self.view convertRect:kb fromView:nil];
    [self.view layoutIfNeeded];
    CGFloat cardBottomAtZero = CGRectGetMaxY(self.zusCard.frame) - self.zusCardCenterY.constant;
    CGFloat shift = cardBottomAtZero - (kbInView.origin.y - 12);
    if (shift < 0) shift = 0;
    double dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:dur animations:^{
        self.zusCardCenterY.constant = -shift;
        [self.view layoutIfNeeded];
    }];
}

- (void)zus_kbHide:(NSNotification *)n {
    double dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:dur animations:^{
        self.zusCardCenterY.constant = 0;
        [self.view layoutIfNeeded];
    }];
}

- (void)zus_tick {
    if (self.zusField.isFirstResponder) return;
    self.zusLeft--;
    if (self.zusLeft <= 0) { [self zus_cancel]; return; }
    self.zusCount.text = [NSString stringWithFormat:@"Tự đóng sau %d giây", self.zusLeft];
}

- (void)zus_ok {
    NSString *k = [self.zusField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!k.length) {
        self.zusMsg.text = @"Hãy dán key vào ô trên — hoặc bấm Huỷ để thoát ra lấy key.";
        return;
    }
    if (ZUSActivateWithKey(k)) {
        [self.zusTimer invalidate];
        ZUSDismissActivationPopup();
        ZUSPresentAlertTop(@"Kích hoạt thành công", [NSString stringWithFormat:@"Cảm ơn bạn!\n%@", ZUSLicenseStatusText()]);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ZUSLicenseChanged" object:nil];
    } else {
        self.zusMsg.text = @"Key chưa đúng — kiểm tra lại rồi bấm OK.";
        self.zusLeft = 30;
        self.zusCount.text = @"Tự đóng sau 30 giây";
    }
}

- (void)zus_cancel {
    [self.zusTimer invalidate];
    ZUSDismissActivationPopup();
}

- (void)dealloc {
    [self.zusTimer invalidate];
}

@end

static UIWindow *gLicWindow = nil;

static void ZUSDismissActivationPopup(void) {
    if (!gLicWindow) return;
    gLicWindow.hidden = YES;
    gLicWindow.rootViewController = nil;
    gLicWindow = nil;
}

static void ZUSShowActivationPopup(void) {
    if (gLicWindow) return;
    UIWindow *kw = nil;
    for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows) if (w.isKeyWindow) { kw = w; break; }
        if (kw) break;
    }
    gLicWindow = kw ? [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)kw.windowScene] : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    gLicWindow.windowLevel = UIWindowLevelAlert + 100;
    gLicWindow.backgroundColor = [UIColor clearColor];
    gLicWindow.rootViewController = [[ZUSLicenseController alloc] init];
    gLicWindow.hidden = NO;
    ZUSLog(@"bản quyền: hiện popup kích hoạt");
}

%ctor {
    @autoreleasepool {
        gOrigs = [[NSMutableDictionary alloc] init];
        gCats = [[NSMutableDictionary alloc] init];
        gCalledOnce = [[NSMutableSet alloc] init];
        gLogLock = [[NSObject alloc] init];
        gLogFmt = [[NSDateFormatter alloc] init];
        gLogFmt.dateFormat = @"MM-dd HH:mm:ss";
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        gLogPath = [docs stringByAppendingPathComponent:@"ZUS.log"];
        ZUSLoadPrefs();
        ZUSApplyAwake();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, ZUSPrefsChanged,
                                        ZUS_NOTIFY, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        ZUSInstallShieldObservers();
        ZUSInstallCaptureHooks();
        ZUSInstallLinkHooks();
        ZUSInstallAdDiscovery();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSApplyTabHiding(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(26 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSApplyTabHiding(); });
        ZUSLog(@"ZUS 1.3.3 nạp vào Zalo (bật=%d, unseen=%d, ẩn đang nhập=%d)", gEnabled, gUnseen, gHideTyping);
        {
            NSDictionary *fp0 = ZUSReadFilePrefs();
            id fe0 = fp0[ZUS_KEY_ENABLED];
            ZUSLog(@"nguồn cài đặt: file chung %@, khoá bật trong file: %@, hiệu lực bật=%d", fp0 ? @"đọc được" : @"KHÔNG đọc được", fe0 ? [fe0 description] : @"(chưa có)", gEnabled);
        }
        ZUSCheckZaloVersion();
        // Mốc "đã nạp" ghi thẳng vào kho prefs ngay khi ctor chạy (thêm ở 1.0.1):
        // bằng chứng tweak có chạy trong Zalo hay không, đọc được ở trang Cài đặt
        // lẫn file /var/mobile/Library/Preferences/com.anhdang.zalounseen.plist —
        // không phụ thuộc file log trong Documents của Zalo như bản 1.0.0.
        ZUSWriteSharedValue(ZUS_DIAG_CTOR, [gLogFmt stringFromDate:[NSDate date]]);
        // Lắp móc theo danh sách trắng sau 1 giây (thử lại 7 giây sau đó cho mục
        // nào class nạp muộn; hàm đã móc rồi thì tự bỏ qua).
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ZUSInstallWhitelist();
            ZUSInstallInAppButton();
            ZUSInstallStoryDownload();
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{ ZUSProbeStore(); });
            ZUSInstallCallBlock();
            ZUSInstallConfirmCall();
            ZUSInstallPhotoOriginal();
            ZUSInstallEmojiProbe();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(13 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSProbeCallFlow(); ZUSInstallUndoProbe(); });
            ZUSInstallTabBarGesture();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ZUSInstallWhitelist(); ZUSInstallTabBarGesture(); ZUSInstallCallBlock(); ZUSInstallConfirmCall(); ZUSInstallPhotoOriginal(); ZUSInstallEmojiProbe(); });
        });
    }
}
