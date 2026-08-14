# Project Context — BHTikTok++ (BHTTR fork)

> **Read this first.** This file captures a full study of the codebase **and** the decrypted
> TikTok 46.5.0 IPA so future sessions don't need to rescan everything.
> Last updated: 2026-08-14 (after full codebase read + IPA binary audit).

> **🔧 MAINTENANCE MISSION (2026-08-14):** Upstream author (raulsaeed) abandoned the free
> tweak (went paid). **This fork is the free continuation.** Goal: **keep the tweak working
> on the latest TikTok.** Latest TestFlight = **46.5.0 (465030)** — the §8 audit covers it.
>
> **Phase 2 COMPLETE (46.5.0 compatibility fixes applied, v1.6):**
> - Removed dead `%hook TTKPassportAppStoreRegionModel` (class replaced by PNS* DTOs; region
>   spoofing still covered by the other 7 region hooks).
> - Removed dead `%hook TIKTOKProfileHeaderView`; **copy-profile-info re-implemented on
>   `TTKProfileRootView`** (`initWithFrame:` + real `%new addHandleLongPress`/`handleLongPress:`
>   — also fixes the latent crash where `%new` was missing entirely; copies nickname/@username/
>   followers/following/bio from `AWEUserModel`).
> - `downloadMusic:` now downloads the **actual audio stream** (`model.music.playURL`, was the
>   video stream mislabeled .mp3) — fixed in both cell classes.
> - `copyDecription:` now copies the **real caption** (`AWEAwemeModel.desc` via KVC, fallback
>   song name) — both cell classes. Wrong alert texts unified.
> - Header type fixes (`selectedRegion`→NSDictionary, `selectedSpeed`→NSNumber), follower-field
>   prefill key fix (`follower_count`), LiveActions type fix, PlaybackSpeed alert title fix.
> - `control` 1.5→1.6. Structural checks: 58 %hook = 58 %end, braces balanced.
> - **Belt-and-braces region coverage:** added `%hook TTKStoreRegionManager` (11 methods:
>   storeRegion/getStoreRegion(→lowercase), getStoreRegionUpperCase/appStoreRegion/
>   appSettingStoreRegion/userStoreRegion/ttStoreRegion/individualAccountStoreRegion(→raw code)
>   + setters) and `%hook TTRegionManager` (11 methods: region/systemRegion/localRegion/
>   currentAppRegion/appStoreRegion(→raw), storeRegion/getStoreRegion(→lowercase) + setters).
>   Selectors inferred from the 46.5.0 binary's method pool — unimplemented ones are harmless
>   no-ops. Now 60 %hook = 60 %end. Device test will confirm which are live.
> - **Settings-row vanishing fix:** replaced one-shot `viewDidLoad` insertion in
>   `AWESettingsNormalSectionViewModel` with **`modelsArray` getter injection** (dedupe by
>   `bhtiktok_settings` identifier + `%property bhtiktokCell` cache) — self-heals across
>   TikTok's async section rebuilds.
> - **"Bundle Not Found" alert:** comes from the OLD pre-fork dylib (strings
>   `BHTikTokpp.bundle`, `/Library/Application Support/...` live only in that binary, from the
>   since-removed `SettingsViewController`). Current source has no bundle code → rebuilding
>   from source eliminates it. No code change needed.
> - **Feature #4 DONE — Bypass Screenshot Detection** (key `disable_screenshot_detection`,
>   settings row in Other section): `%hook NSNotificationCenter` blocks registration of
>   `UIApplicationUserDidTakeScreenshotNotification` observers (both `addObserver:selector:`
>   and `addObserverForName:` variants) → TikTok's screenshot handlers (live/chat detection
>   AND the share popup) never fire, app-wide. Single toggle covers both since both are
>   notification-driven; if device test shows the popup surviving, add targeted hooks on
>   `ScreenshotExternalShareFrequencyManager`/`ShareScreenshotPopupConfiguration` (method
>   names need FLEX runtime verification first).
> - **Developer section rebranded:** upstream author links (found deleted mid-session, user
>   confirmed intentional) replaced with pisknk's: row 0 = "Neil Bayron (pisknk)" →
>   github.com/pisknk, row 1 = "BHTTR Source Code & Updates" → github.com/pisknk/BHTTR.
>   Section 7 row count now 2 (was 3). User has NO X/donation links (community project) —
>   Developer section stays at 2 rows permanently.
> - **Feature #2 DONE — DM Ghost Mode** (new "Privacy" settings section 8, 2 rows):
>   - Read receipts (`ghost_read_receipts`): `%hook AWEIMMessageReadComponent` +
>     `AWEIMMessageDataController` (belt-and-braces) on `p_markReadSyncToServerWithMessage:`
>     → no-op; messages still appear read locally, "Seen" never reaches the server.
>     NOTE: `chatRoomDidAppear:` deliberately NOT blocked (it does UI work too).
>   - Typing (`ghost_typing`): `%hook TIMInputStatusManager sendInputStatusWithConversationID:
>     inputStatus:` → no-op (TTIMSDK ObjC layer, confirmed via .jojo source path string).
>   - Device-test watch-items: if receipts/typing still leak, FLEX-verify owner classes;
>     fallback candidates: `conversationReadManager` (TIMOConversationReadManager),
>     `sendSignal:toUsers:channel:finished:`, AB flags `enableReadReceiptPolling`/
>     `enableNewTypingIndicator` (usable once feature #1 Labs exists).
> - **Feature #1 (Labs A/B explorer): PLANNED, not started — full recon + implementation plan
>   lives in `PLAN.md`** (Libra stack evidence, Phase A discovery → Phase B UI → Phase C override
>   hook, open questions, testing, risks). pisknk implements after class; start at Phase A.
> - **CI build fix (first workflow run failed, 6 errors in Tweak.x):**
>   1. `%property bhtiktokCell` lacked its `@property` declaration in TikTokHeaders.h — this
>      codebase's Logos requires header declarations for `%property` (same as hud/elementsHidden/
>      fileextension/progressView). Declaration added to `AWESettingsNormalSectionViewModel`.
>   2. Single-line `%orig`-in-block (`showConfirmation(^(void) { %orig; });`, 5 sites) breaks the
>      Logos preprocessor in current Theos — expanded all 5 to multi-line blocks (UIButton,
>      AWEPlayInteractionUserAvatarElement, AWEFeedVideoButton, AWECommentPanelCell onLike/onDislike).
>      NOTE: all other .m files compiled fine; only Tweak.x failed.
> **Next:** push → CI build → user TrollFools-injects into 46.5.0 → device test.
> Remaining known gaps: story download (TODO), follow-confirm quirk, tikwm.com HD endpoint
> (3rd-party, needs on-device verification).
> - **Region spoof — CONFIRMED client/server boundary (user device tests, 46.5.0):**
>   - **NEW account created while US spoof active** → server registered it as US: US rewards
>     program (USD balances, Amazon gift-card offers), US FYP/offers; PH-local videos shown
>     exactly once (first-impression batch keyed to IP) then never; **no TikTok Shop tab**.
>   - **OLD PH account under the same spoof** → rewards page stays PH (₱ balances, PH daily
>     tasks, "Search … on TikTok Shop" tasks) → rewards/Shop are **server-side account
>     provisioning**, not client-region-driven.
>   - **KEY FINDING: the spoof leaks server-side at SIGNUP** — region reported during
>     registration shapes the account's server-side region, but once the account exists its
>     region is pinned; only the official `PNSChangeRegion` migration can move it (that is
>     exactly what the new "Show Region Change Option" toggle surfaces).
>   - US rewards surface still *mentions* "TikTok Shop Coupons" in promo copy, but the Shop
>     tab itself stays server-gated.
> - **PNSChangeRegion placement/UX recon (46.5.0 MusicallyCore, for the "Show Region Change Option" test):**
>   - Entry surface: `TTKSettingsChangeRegionManager` (compiled inside Swift module
>     `PNSChangeRegionAdapterImpl`) → plugs into **Settings and privacy → Account area**;
>     l10n key family `chg_acct_region_*` ("change account region") + tracking event
>     `account_region_status_click` (there is a tappable status page).
>   - Signup surface instead routes via `aweme://signup/selectCountry` (irrelevant post-signup).
>   - Post-change UX: `chg_acct_region_refresh_popup_{title,desc,button}` + `relaunch_app_prompt_page`
>     → successful migration ends with a "relaunch app" prompt.
>   - TWO gates: client `isChangeRegionEnabled` (we force YES on 6 classes) AND server
>     `hasEntranceShowInfo`/`entranceShowType` (`NSInteger`/`BOOL`, ObjC-runtime visible per type
>     encodings `Tq,N,V…`/`TB,N,V…`) delivered by `PNSSettingsChangeRegionDataManagerV2.fetch`
>     over `com.pns.changeregion.v2`. **If the entry does NOT appear in the test, the server
>     isn't offering the entrance → next step: also hook `hasEntranceShowInfo` → YES.**
>   - Labels are server-localized (`localizedCountryName` etc.) — NOT in en.lproj, so no
>     static string to grep for the entry title.
>   - Other models: `PNSChangeRegionSettingsModel(V2)`, `PNSChangeRegionCountryModel(V2)`,
>     `PNSAppStoreRegionResponse(Data)`, `current_store_region` (`TTKStoreRegionModel`).
> - **2026-08-14 — Region-change hooks REBUILT on verified evidence (supersedes the no-op builds):**
>   - **Binary layout**: `Payload/TikTok.app/TikTok` is a 0.1 MB stub; ALL real code lives in
>     `Frameworks/MusicallyCore.framework/MusicallyCore` (**778 MB**, thin arm64, MH_DYLIB).
>   - **Device test proved prior hooks were no-ops**: `TTKChangeRegionInitConfig`,
>     `TTKSettingsChangeRegionManager`, `PNSSettingsChangeRegionDataManagerV2` etc. are **Swift
>     classes registered under mangled names** (`_TtC26PNSChangeRegionAdapterImpl25TTKChangeRegionInitConfig`)
>     → `objc_getClass("TTK…")` = nil → Logos silently skips. Strings for Swift classes appear in
>     `__cstring`/`__swift5_reflstr`, NOT `__objc_classname` — check that section before trusting a name.
>   - **VERIFIED gate owners (full ObjC metadata walk of all 104,114 classes)**:
>     `PNSChangeRegionSettingsModel` + `PNSChangeRegionSettingsModelV2` own `@property BOOL
>     isChangeRegionEnabled`; `PNSChangeRegionCountryModelV2` owns `@property BOOL
>     hasEntranceShowInfo` + `@property NSInteger entranceShowType`. Tweak.x now hooks exactly
>     these 3 classes (was 9 wrong ones). V1 CountryModel has no such props.
>   - **Official page is a webview**: `https://www.tiktok.com/tpp/inapp/pns_product_poseidon/change-region-selector.html`
>     (PNS = "poseidon" SDK; JS bridge namespace `com.pns.changeregion[.v2]`). New settings cell
>     **"Change Region (Official)"** (Region section, row 3) opens it via live route
>     `aweme://webview/?hide_nav_bar=1&use_spark=1&show_loading=1&url=<pct-encoded>` — bypasses
>     ALL entrance gating; server still validates the migration itself.
>   - **Analysis tooling** (in `%TEMP%`, recreate from this note if wiped): `SectScan.cs` =
>     Mach-O section mapper + single-pass multi-pattern string scanner; `ObjCWalk.cs` = full ObjC
>     classlist walker with **chained-fixup pointer decoding** (DYLD_CHAINED_PTR_64/arm64e formats;
>     class_ro layout: name@+24, baseMethods@+32, baseProps@+64) and **relative method lists whose
>     name field is a selref-relative s32** (entry+f0 → `__objc_selrefs` slot → chained ptr → string;
>     types = entry+4+f1 direct s32; imp = entry+8+f2). CodeDom-compiled via CSharpCodeProvider.
>   - **Future spoof idea**: `@property NSString *account_region` lives on
>     `GBLXBridgeApiParamMethodResultModel` (JS-bridge result model) — hooking its getter could
>     make web pages (incl. the poseidon page) read a spoofed account region. Untested.
>   - Prior test builds: run #4 (`d2dc865`, "second gate") built OK but hooks were no-ops.

---

## 1. Project at a Glance

- **What**: Theos/Logos MobileSubstrate tweak for TikTok (iOS), injected via Cydia Substrate / ElleKit.
- **Package**: `com.raulsaeed.bhtiktok++` v1.5 ("BHTikTok++"), section Tweaks, depends `mobilesubstrate`.
- **Fork**: `origin` = https://github.com/pisknk/BHTTR.git · `upstream` = https://github.com/raulsaeed/BHTikTokPlusPlus.git · branch `main`.
- **Target processes** (BHTikTok.plist filter): `com.zhiliaoapp.musically`, `com.ss.iphone.ugc.Ame`.
- **Local decrypted IPA** (analysis reference): `com.zhiliaoapp.musically_46.5.0_decrypted/Payload/TikTok.app`
  — TikTok **46.5.0 (build 465030)**, already patched with the tweak via **TrollFools**. Do NOT commit this folder (gitignored).

## 2. Repository Layout

| Path | Lines | Role |
|---|---|---|
| `Tweak.x` | 1884 | All Logos `%hook`s + `%ctor` |
| `TikTokHeaders.h` | 349 | Forward declarations of TikTok private classes + helpers `is_iPad()`, `topMostController()` |
| `BHIManager.h/m` | 47/212 | Settings facade: one class method per flag → `NSUserDefaults`; plus `cleanCache`, `saveMedia:fileExtension:` (→ Photos), `showSaveVC:` (UIActivityViewController, iPad-aware), `getDownloadingPersent:`, `isEmpty:` |
| `BHDownload.h/m` | 29/42 | Single-file downloader (`NSURLSessionDownloadTask` wrapper), `BHDownloadDelegate` |
| `BHMultipleDownload.h/m` | 11/58 | Multi-file variant for photo albums; UUID-names files into Documents |
| `SecurityViewController.h/m` | 4/42 | App lock: blur overlay + `LAContext` `LAPolicyDeviceOwnerAuthentication`; no-op on failure |
| `Settings/ViewController.m` | 502 | Settings UI: plain UITableView, **8 sections** (Feed=15, Profile=4, Confirm=4, Other=10, Region=2, Live=2, Playback=2, Developer=3); switch cells write bools via `switch.accessibilityLabel = key`; text fields (tag 1=following, tag 2=follower) |
| `Settings/CountryTable.m` | 93 | Region picker: 38 countries `{area,name,code,mcc,mnc}` → `region` key; calls `p_showStoreRegionChangedDialog` on `AWEStoreRegionChangeManager` |
| `Settings/LiveActions.m` | 59 | LIVE-button remap: 0=Default, 1=BHTikTok++ Settings, 2=Playback Speed → `live_action` |
| `Settings/PlaybackSpeed.m` | 58 | Speed picker 0.5/1.0/1.5/2.0 → `playback_speed` |
| `JGProgressHUD/` | ~2600 | Vendored stock library (Jonas Gessner) — download HUD; untouched |
| `Makefile`, `control`, `BHTikTok.plist`, `README.md` | — | Build / packaging / filter / docs |

## 3. Build System (Makefile)

```
TARGET := iphone:clang:16.5
INSTALL_TARGET_PROCESSES = TikTok
THEOS_DEVICE_IP = 192.168.100.246   (hardcoded, user root)
TWEAK_NAME = BHTikTok
BHTikTok_FILES = Tweak.x $(wildcard *.m JGProgressHUD/*.m Settings/*.m)
BHTikTok_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices
                      SystemConfiguration SafariServices Security QuartzCore
BHTikTok_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-value
                  -Wno-deprecated-declarations -Wno-nullability-completeness
                  -Wno-unused-function -Wno-incompatible-pointer-types
```

- ARC on; code intentionally relies on suppressed incompatible-pointer warnings (see §7).
- Output: `BHTikTok.dylib` → injected into `TikTok.app/Frameworks` (see §8.3).

### 3.1 CI — GitHub Actions (`.github/workflows/build.yml`)

Adapted from `pisknk/Direct.FM`'s `build.yml`. Triggers: push/PR to `main`/`master` + `workflow_dispatch`.
Runs on `macos-latest`: brew `make`+`ldid` → clones theos → sparse-checkouts **iPhoneOS16.5.sdk**
(matches Makefile TARGET) → bumps control version to `1.5.${{ github.run_number }}` →
`make package THEOS_PACKAGE_SCHEME=rootless DEBUG=0 FINALPACKAGE=1 ARCHS="arm64 arm64e" TARGET=iphone:clang:16.5:15.0` (control version bumped to `1.6.${{ github.run_number }}`)
→ artifact `bhtiktok-package` = `.deb` (jailbreak users) **+ raw `BHTikTok.dylib`** (TrollFools users).


## 4. Architecture & Data Flow

```
Settings UI (Settings/*.m)  ──writes──>  NSUserDefaults (plain keys, §5)
                                              |
BHIManager + (BOOL)featureX  <──reads─────────┘
                                              |
Tweak.x %hook methods  ──calls──>  [BHIManager featureX] to decide behavior

Download pipeline: cell %new methods → BHDownload / BHMultipleDownload
   → JGProgressHUD progress → file moved to Documents (UUID name)
   → [BHIManager shareSheet] or audio ext?  showSaveVC (UIActivityViewController)
                                          :  saveMedia → PHPhotoLibrary
Cache hygiene: AppDelegate didFinishLaunching → [BHIManager cleanCache]
   (deletes mp4/png/jpeg/mp3/m4a/mov/tmp from Documents + NSTemporaryDirectory)
```

- Tweak state attached to TikTok cells via Logos `%property` (`hud`, `elementsHidden`, `fileextension`, `progressView`).
- Helper methods injected into TikTok classes via `%new` (e.g. `bestURLtoDownload` on AWEURLModel).
- Confirmation dialogs via TikTok's own `AWEUIAlertView showAlertWithTitle:…` (`showConfirmation()` in Tweak.x).
- Anti-jailbreak: `%ctor` fills global `jailbreakPaths` (~60 paths incl. `/jb/*` rootless), then `%init`; `NSFileManager fileExistsAtPath` hooks lie about those paths.

## 5. NSUserDefaults Keys Reference

*(typos in keys are intentional — must be preserved for compatibility)*

- **Feed**: `hide_ads`¹ `download_button`¹ `share_sheet` `remove_watermark` `remove_elements_button`¹ `stop_play` `auto_play` `show_porgress_bar`¹ `transparent_commnet` `show_username` `disable_unsensitive` `disable_warnings` `disable_live` `skip_recommnedations` `upload_region`
- **Profile**: `save_profile`¹ `copy_profile_information`¹ `video_like_count` `video_upload_date` `uploaded_videos` (in BHIManager; no switch row in settings UI)
- **Confirm**: `like_confirm` `like_comment_confirm` `dislike_comment_confirm` `follow_confirm`
- **Other**: `openInBrowser` `en_fake` `follower_count`(string) `following_count`(string) `fake_verify` `extended_bio`¹ `extendedComment`¹ `upload_hd` `padlock` `flex_enebaled`
- **Region**: `en_region` + `region` (dict name/code/mcc/mnc/area)
- **Live button**: `en_livefunc` + `live_action` (0=default, 1=settings, 2=speed)
- **Playback**: `playback_en` + `playback_speed` (NSNumber 0.5–2.0)
- **Meta**: `BHTikTokFirstRun` (first-run marker)

¹ = default **true** on first run (set in AppDelegate `didFinishLaunchingWithOptions:`).

## 6. Feature → Hook Map (Tweak.x)

| Hook | Purpose |
|---|---|
| `AppDelegate` | first-run defaults, FLEX explorer (`flex_enebaled`; FLEXManager absent → no-op), cleanCache, app lock via SecurityViewController (`isAuthenticationShowed` guard) |
| `TTKMediaSpeedControlService setPlaybackRate:` | persistent playback speed |
| `AWEUserWorkCollectionViewCell` | profile-grid overlays: like count (tag 1001) + upload date (tag 1002); `%new formattedNumber:` / `formattedDateStringFromTimestamp:` |
| `TTKProfileRootView` | "Video Count: N" label (`visibleVideosCount`) |
| `BDImageView` | long-press save profile image → Photos (`%new addHandleLongPress` / `handleLongPress:`) |
| `AWEUserNameLabel` | fake verified icon on own profile (TTKProfileHomeViewController) |
| `TTTAttributedLabel` | long-press copy bio text |
| `TTKSettingsBaseCellPlugin` + `AWESettingsNormalSectionViewModel` | inject "BHTikTok++ settings" row (identifier `bhtiktok_settings`, type 99) at top of "account" section → opens Settings/ViewController |
| `SparkViewController` | alwaysOpenSafari: extracts `url` query param → Safari, closes in-app browser |
| `CTCarrier`, `TTKStoreRegionService`, `TIKTOKRegionManager`, `TTKPassportAppStoreRegionModel`, `ATSRegionCacheManager`, `TTKStoreRegionModel`, `TTInstallIDManager`, `BDInstallGlobalConfig` | region spoofing (code/mcc/mnc/name from `region` dict) |
| `ACCCreationPublishAction` | always upload HD (`is_open_hd`/`is_have_hd` → 1) |
| `TTKCommentPanelViewController` | transparent comments (alpha 0.90) |
| `AWEAwemeModel` | hide ads (init → nil if `isAds`), progressBarDraggable/Visible, disable live (live JSON transformers → nil) |
| `AWEPlayInteractionWarningElementView` | disable warnings (nil image/label) |
| `TUXLabel setText:` | show username instead of nickname (via `AWEPlayInteractionAuthorUserNameButton` superview check + `yy_viewController`) |
| `AWENewFeedTableViewController` | disable pull-to-refresh |
| `AWEPlayVideoPlayerController` | auto-play-next (scrollToNextVideo on loop), stop loop, skip recommendations (`isUserRecommendBigCard`) |
| `AWEMaskInfoModel` | disable sensitive-content mask |
| `AWEAwemeACLItem` | watermark removal (`watermarkType` forced 1) |
| `UIButton _onTouchUpInside`, `AWEPlayInteractionUserAvatarElement` | follow confirmation (code comment: "broken") |
| `AWEFeedVideoButton` | like confirmation (`imageNameString == ic_like_fill_1_new`) |
| `AWECommentPanelCell` | like/dislike comment confirmation |
| `AWEUserModel`, `TTKProfileBaseComponentModel` | fake follower/following; fake verify component (`user_account_verify`); `%new numberFromUserDefaultsForKey:` / `formattedStringFromNumber:` |
| `AWETextInputController` / `AWEProfileEditTextViewController` | extended comments (500) / extended bio (222) |
| `AWEPlayInteractionAuthorView` | upload-region flag emoji (tag 666); `%new emojiForCountryCode:` |
| `TIKTOKProfileHeaderView` | copy profile info long-press — **see issue #1 (§7)** |
| `AWELiveFeedEntranceView` | LIVE button remap (`switchStateWithTapped:`) |
| `AWEFeedViewTemplateCell` + `AWEAwemeDetailTableViewCell` (duplicated impls) | download button (tag 998, y=90) + hide-elements button (tag 999, y=50); UIMenu: Download Video / **HD via `https://tikwm.com/video/media/hdplay/{itemID}.mp4`** / Music / Copy Music link / Copy Video link / Copy Description; photo-album controllers get per-photo + all-photos actions (BHMultipleDownload); hide toggles `hideAllElements:exceptArray:` on `TTKFeedInteractionLegacyMainContainerElement` |
| `TTKStoryDetailTableViewCell` | **empty hook — TODO story download (README TODO)** |
| `AWEURLModel` | `%new bestURLtoDownload` / `bestURLtoDownloadFormat` (scans `originURLList` for video_mp4/.jpeg/.mp3/.png/.m4a) |
| `NSFileManager`, `BDADeviceHelper`, `UIDevice btd_isJailBroken`, `TTInstallUtil`, `AppsFlyerUtils`, `PIPOIAPStoreManager`, `IESLiveDeviceInfo`, `PIPOStoreKitHelper`, `BDInstallNetworkUtility`, `TTAdSplashDeviceHelper` | anti-jailbreak-detection (path spoofing + isJailBroken→NO) |
| `GULAppEnvironmentUtil`, `FBSDKAppEventsUtility`, `AWEAPMManager`, `NSBundle pathForResource:ofType:`, `AWESecurity`, `MSManagerOV`, `MSConfigOV` | sideload spoofing (isFromAppStore YES, signInfo "AppStore", hide .mobileprovision, no-op security modes) |
| `%ctor` (line 1852) | fills `jailbreakPaths`, then `%init` |


## 7. Known Latent Issues in Tweak Source

1. **`%hook TIKTOKProfileHeaderView` (Tweak.x:1034)** calls `[self addHandleLongPress]` but **no `%new` implementation exists** for that class (only `BDImageView` and `TTTAttributedLabel` define it). TikTok does NOT implement it either (verified by binary scan) → would be an unrecognized-selector crash; moot on 46.5.0 because the class itself is gone (Logos skips missing classes safely). `AWEProfileImagePreviewView` is declared in headers but never hooked.
2. **Header type mismatches** (masked by `-Wno-incompatible-pointer-types`): `BHIManager.h` declares `+ (NSNumber *)selectedRegion` / `+ (NSDictionary *)selectedSpeed` but the .m returns dictionary/NSNumber respectively; `LiveActions.m:53` assigns `NSString*` to `NSNumber*`.
3. **`Settings/ViewController.m:247`**: the *Follower* text field (tag 2) pre-fills from key `following_count` instead of `follower_count`.
4. **`TTKStoryDetailTableViewCell`** hook is an empty TODO (story download unimplemented — matches README TODO).
5. **Follow confirmation** via `UIButton._onTouchUpInside` is commented "broken" in source.
6. **Copy-paste artifacts**: "Live Option Selected" alert title reused in PlaybackSpeed; wrong alert text in `copyVideo`/`copyDecription` ("doesn't have music"); `downloadMusic:` downloads from `video.playURL` but labels it mp3; unused `NSString *as` locals; duplicated removal loop in `AWEUserWorkCollectionViewCell`.
7. **`SecurityViewController`** does nothing on auth failure (user can only retry via button).

---

## 8. Decrypted IPA Study — TikTok 46.5.0 (build 465030)

### 8.1 Bundle Facts

- `Payload/TikTok.app`, arm64 single-slice Mach-O, decrypted (FairPlay stripped).
- `CFBundleIdentifier com.zhiliaoapp.musically`, `CFBundleShortVersionString 46.5.0`, `CFBundleVersion 465030`.
- Built with **iOS 26.0 SDK** (`DTSDKName iphoneos26.0`), MinimumOSVersion **15.0**.
- 58 `.lproj` localizations, ~200 `.bundle` resource packs, 1 `.appintents`, 9 app extensions in `PlugIns/` (`AwemeBroadcastExtension`, `AwemeNotificationService`, `AwemeShareExtension`, `AwemeWidgetExtension`, `AWEVideoWidget`, `TikTokIntentExtension`, `TikTokMessageExtension`, `WalletAuthExtension`, `WalletShareExtension`).
- URL schemes incl. `tiktok`, `musically`, `snssdk1180`, `tiktokshop`, `tiktokpay`, `tiktokopensdk/sharesdk`, FB/Google/Twitter(K)/VK/Kakao/Line login schemes.
- `NSPhotoLibrary(Add)UsageDescription` present (needed by tweak's save-to-Photos).
- `UIBackgroundModes`: fetch, audio, remote-notification, voip.

### 8.2 Binary Architecture

- **`TikTok` stub (~0.1 MB)**: pure launcher; loads `@rpath/MusicallyCore.framework/MusicallyCore` + JSCore + system libs; rpath `@executable_path/Frameworks`. **No tweak injection in the stub** (verified: full load-command dump; cmd 0xB is LC_DYSYMTAB, not an env-var trick).
- **`MusicallyCore` (778.6 MB)**: the entire app as one monolithic framework. ObjC + Swift (mangled `_TtC13TikTokPadImpl…`); monorepo source paths survive as strings (`.jojo/repos/TikTokUserProfileImpl/.../TTKProfileHeaderAdaptor.m`).
- **17 bundled frameworks**: media (`TTFFmpeg`, `bytevc1enc` = H.266/VVC encoder, `libvcn`, `ffmpeg_dashdec`), crypto (`boringssl`, `crypto`, `WCDBSQLCipherFrameworkA`), ads (`OMSDK_Bytedance1`), launch infra (`AAAASingularity`, `AAWEBootChecker`, `AAWELaunchTracker`), 3rd-party (`SCSDKCoreKit`/`SCSDKCreativeKit` Snapchat, `SpotifyLogin`, `TTPOrbuService`), plus injected `CydiaSubstrate.framework`.


### 8.3 Tweak Injection Chain (this IPA is already TrollFools-patched)

```
TikTok stub → MusicallyCore → AAAASingularity (loads first; "AAAA" sorts first)
                                   ├─ WEAK @rpath/BHTikTokTrollFools.dylib
                                   └─ WEAK @rpath/BHTikTok.dylib
                                          └─ LOAD @executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
```

- TrollFools inserted two `LC_LOAD_WEAK_DYLIB` commands into **`AAAASingularity.framework`** (empty `.troll-fools` marker file in CydiaSubstrate.framework confirms tool). Neither stub nor MusicallyCore references the tweak directly.
- `CydiaSubstrate.framework` = **ElleKit shim** (install name `/usr/local/lib/libellekit.dylib`) masquerading as "Cydia Substrate 0.9/6.0" (`com.saurik.CydiaSubstate`). Provides the Logos runtime on TrollStore/rootless.
- `BHTikTok.dylib` (503,315 B) and `BHTikTokTrollFools.dylib` (503,331 B): same build, duplicated as belt-and-braces weak loads.

### 8.4 ⚠️ Bundled dylib Is STALE vs. Source

Marker-string scan of the bundled dylib proves it predates current source:

- **Missing**: `openInBrowser`, `alwaysOpenSafari`, `SparkViewController`, `didTapCloseButton` → built **before the alwaysOpenSafari feature**.
- Still links **`/System/Library/PrivateFrameworks/Preferences.framework`** → built **before commit `0d26b18` ("Removed dependency of Private framework…")**.
- All 45 other markers present (all settings keys, `bhtiktok_settings`, tikwm HD endpoint, region/fake/padlock).
- Dylib rpaths: `/var/jb/...`, `@loader_path/.jbroot/...` (rootless-jailbreak-oriented build).

### 8.5 Hook Compatibility Audit vs. 46.5.0

Full class+selector scan of MusicallyCore (substring cstring match over `__objc_*` sections):

**✅ 76/80 hooked classes + 95/97 selectors still exist.** The 2 "missing" selectors are the tweak's own `%property`/`%new` names (`elementsHidden`, `addHandleLongPress`) — expected. Settings-injection classes, feed/download classes, all playback classes, all anti-jb classes, and most region classes are intact.

**❌ 4 classes gone/renamed in 46.5.0:**

| Tweak references | 46.5.0 reality |
|---|---|
| `TIKTOKProfileHeaderView` (copy profile info; `TIKTOKProfileHeaderViewController` also gone) | Renamed → `TTKProfileHeaderView` family: `TTKProfileHeaderAdaptor`, `TTKProfileHeaderAdaptorView`, `TTKProfileHeaderViewComponent`, `TTKProfileHeaderTopContainerView`, `TTKChangeFrameProfileHeaderView` |
| `TTKStoryContainerViewController` | Story stack reworked → `TTKStoryContainerCollectionView`, `TTKStoryContainerConfiguration`; **but** `TTKStoryDetailTableViewCell` + `TTKStoryDetailContainerViewController` still exist |
| `TTKPassportAppStoreRegionModel` (region spoof) | Replaced → `PNSAppStoreRegion`, `PNSAppStoreRegionResponse`, `PNSAppStoreRegionResponseData` (`setAppStoreRegion:`, `getAppStoreRegionPath`, `getAppStoreRegionDiffWithUserRegion:`) |
| `FLEXManager` | Never shipped in app (dev-only; `%c()` nil → harmless no-op) |

### 8.6 TikTok-Side Jailbreak Detection

MusicallyCore embeds its own detection strings (`/Library/MobileSubstrate/…`, `TweakInject`, `CydiaSubstrate`, `/Library/MobileSubstrate/DynamicLibraries/{LiveClock,Veency}.plist`) — exactly what the tweak's `NSFileManager` path-spoof + `isJailBroken→NO` hooks counter. All targeted classes (`BDADeviceHelper`, `TTInstallUtil`, `AppsFlyerUtils`, `PIPO*`, `IESLiveDeviceInfo`, `BDInstallNetworkUtility`, `TTAdSplashDeviceHelper`, `GULAppEnvironmentUtil`, `FBSDKAppEventsUtility`, `AWEAPMManager`, `AWESecurity`, `MSManagerOV`, `MSConfigOV`) still exist in 46.5.0.

---

## 9. Analysis Tooling (kept in %TEMP%, reusable)

- `machoscan.ps1 -Binary <file> -PatternFile <txt>` — multi-pattern byte scan (finds class/selector/key strings in Mach-O), ~15 s for the 778 MB binary.
- `machostrings.ps1 -Binary <file> -SubstringFile <txt> [-MaxResults N]` — ASCII-strings extractor filtered by substrings (finds renamed classes).
- `macholoads.ps1 -Binary <file>` — Mach-O 64 dylib/rpath load-command list.
- `machodump.ps1 -Binary <file>` — raw load-command dump (all types).
- Pattern lists used: `patterns_classes.txt`, `patterns_selectors.txt`, `patterns_markers.txt`, `subs_missing.txt`, `subs_load.txt`, `subs_dylibs.txt`, `subs_substrate.txt` (all in %TEMP%).
- Caveat: PowerShell `Measure-Object -Line` counts **non-blank** lines — real line counts of source files are higher (e.g. Tweak.x = 1884 actual).

## 10. Git State (at time of study)

- HEAD: `6add794` "Delete .vscode directory" (main).
- Recent notable: `0d26b18` removed Private-framework dependency + unused SettingsViewController; `4ef3432` fixed buggy playback speed; `14781b0` alpha Settings.
- Remotes: `origin` (pisknk/BHTTR — this fork), `upstream` (raulsaeed/BHTikTokPlusPlus).
