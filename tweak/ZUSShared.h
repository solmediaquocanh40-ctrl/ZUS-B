// ZUSShared.h — hằng dùng chung cho tweak (chích vào Zalo) và gói Cài đặt.
// Hai bản giống hệt nhau nằm ở tweak/ và prefs/.
#ifndef ZUS_SHARED_H
#define ZUS_SHARED_H

#define ZUS_DOMAIN @"com.anhdang.zalounseen"
// Tên thông báo Darwin ở dạng CFString sẵn (CFSTR) — KHÔNG để chuỗi C rồi __bridge
// sang CFStringRef: bản 1.0.0 build đầu chết đúng lỗi đó, còn làm clang sập.
#define ZUS_NOTIFY CFSTR("com.anhdang.zalounseen/prefsChanged")

// Khoá cài đặt (khớp Root.plist)
#define ZUS_KEY_ENABLED @"enabled"
#define ZUS_KEY_UNSEEN  @"unseen"
#define ZUS_KEY_TYPING  @"hideTyping"
#define ZUS_KEY_DEBUG   @"debug"
#define ZUS_KEY_DELIVERED @"hideDelivered"
#define ZUS_KEY_ANTIRECALL @"antiRecall"
#define ZUS_KEY_AWAKE     @"keepAwake"
#define ZUS_KEY_INAPP     @"inAppUI"
#define ZUS_KEY_LONGTAB   @"longPressTab"
#define ZUS_KEY_STORYDL   @"storyDownload"
#define ZUS_KEY_SHIELD    @"privacyShield"
#define ZUS_KEY_ZALOVER   @"lastZaloVersion"
// 1.1.5: lịch giờ, giao diện, cài riêng theo đoạn chat, khoá đoạn chat,
// nhật ký chặn theo đoạn chat, cảnh báo link.
#define ZUS_KEY_SCHED     @"schedEnabled"
#define ZUS_KEY_SCHEDFROM @"schedFromMin"
#define ZUS_KEY_SCHEDTO   @"schedToMin"
#define ZUS_KEY_THEME     @"themePreset"
#define ZUS_KEY_COLBG     @"colBg"
#define ZUS_KEY_COLBAR    @"colBar"
#define ZUS_KEY_COLTEXT   @"colText"
#define ZUS_KEY_COLACCENT @"colAccent"
#define ZUS_KEY_PERCHAT   @"perChat"
#define ZUS_KEY_LOCKED    @"lockedChats"
#define ZUS_KEY_JOURNAL   @"journal"
#define ZUS_KEY_LINKWARN  @"linkWarning"
#define ZUS_KEY_ADBLOCK   @"adBlock"
#define ZUS_KEY_VAULT     @"recallVault"
#define ZUS_KEY_LICENSE   @"licenseKey"
// 1.3.0: ẩn tab dạng option, xác nhận trước khi gọi, ảnh gốc, emoji react,
// chặn cuộc gọi theo từng đoạn chat, theo dõi thay đổi bạn bè.
#define ZUS_KEY_HIDETABDISC @"hideTabDiscover"
#define ZUS_KEY_HIDETABTIME @"hideTabTimeline"
#define ZUS_KEY_CONFIRMCALL @"confirmCall"
#define ZUS_KEY_PHOTOORIG   @"photoOriginal"
#define ZUS_KEY_MOREEMOJI   @"moreEmoji"
#define ZUS_KEY_CALLBLOCK   @"callBlock"
#define ZUS_KEY_FRIENDSNAP  @"friendSnap"
#define ZUS_KEY_FRIENDCHG   @"friendChanges"




// Khoá chẩn đoán: tweak ghi, trang Cài đặt đọc để hiện trạng thái dò.
#define ZUS_DIAG_CANDIDATES   @"diag_candidates"
#define ZUS_DIAG_HOOKED       @"diag_hooked"
#define ZUS_DIAG_SKIPPED      @"diag_skipped"
#define ZUS_DIAG_BLOCKED_READ @"diag_blockedRead"
#define ZUS_DIAG_BLOCKED_TYPE @"diag_blockedTyping"
#define ZUS_DIAG_BLOCKED_DELIV  @"diag_blockedDelivered"
#define ZUS_DIAG_BLOCKED_RECALL @"diag_blockedRecall"
#define ZUS_DIAG_LAST         @"diag_lastEvent"
#define ZUS_DIAG_SCAN         @"diag_lastScan"
#define ZUS_DIAG_CTOR         @"diag_ctor"
#define ZUS_DIAG_FRIENDS     @"diag_friendCount"
#define ZUS_DIAG_FRIENDSRC   @"diag_friendSource"
#define ZUS_DIAG_ZALOUPD     @"diag_zaloUpdated"

#endif
