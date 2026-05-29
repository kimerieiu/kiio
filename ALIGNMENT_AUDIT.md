# frontend-ios Alignment Audit

This checklist records the current visible-path alignment against `frontend-app`.
Business-boundary items are intentionally deferred and must not surface as active
entry points in the iOS app.

| Area | frontend-app reference | frontend-ios status | Notes |
| --- | --- | --- | --- |
| Splash / language / welcome / auth | `pages/splash`, `pages/language`, `pages/welcome`, `pages/auth` | Aligned | Native splash timing, language selection, paged welcome, and auth modes are present. SM2 is deferred. |
| Main tabs | Home, Chat, Device, Profile | Aligned | Uses native `TabView` and `NavigationStack`; tab order matches core business paths. |
| Home tools | Reminder, Accounting, Outfit, News, Mail | Aligned | Five tool entries are present in card and list modes and route to native tool pages. |
| Reminder | list / detail | Aligned | Real service data, loading, empty, error, refresh, pagination, complete/cancel/delete paths. |
| Accounting | list / detail | Aligned with boundary | Real service data, confirm/edit/delete paths. Manual bill creation remains hidden. |
| Outfit | list / detail | Aligned | Real service data, empty/error/refresh states, detail links. |
| News | list / detail | iOS-native equivalent | Real service data and detail path. Thumbnail-heavy Web presentation is not copied. |
| Mail | list / detail / mail-settings | iOS-native equivalent | Accounts and operations are merged in one native page instead of a separate settings route. |
| Chat | chat / chat-history | iOS-native equivalent | Root page now shows companion status, latest session summary, message bubbles, and history list entries using existing `ChatStore`. |
| Device dashboard | device | Aligned | Dashboard, add sheet, device metrics, list/detail entry, agent language preference. |
| Device list / detail | device-list / device-detail | Aligned | Device list, detail hero, identity/firmware, rename, auto update, refresh status, re-provision, unbind. |
| Provisioning / pairing | device-provisioning2 / device-pairing2 / device-scan | Aligned | Native guide, AVFoundation QR scanning, and manual six-digit fallback binding are present. |
| Profile | profile | Aligned with boundary | Account, assets, subscription/order placeholders, device/outfit/settings/about/sign out. Subscription and orders are visual entry points, but payment/order business remains TODO. |
| Settings | settings / settings-language | iOS-native equivalent | Account summary, app language, agent language, about/API/version, and native TODO rows for non-closed privacy/help/security routes. |
| Realtime sync | notify-client / sync store | Partially aligned | Tool pages use dirty refresh. Device pages now refresh through bootstrap for future device notify modules; backend currently publishes tool modules only. Chat and Profile remain bootstrap/manual refresh. |
| Business boundary | subscription / order / SM2 / multi-agent / manual bill | Deferred | Subscription and order pages are placeholder entry points only. No payment/order backend or App Store purchase flow is treated as complete. |
