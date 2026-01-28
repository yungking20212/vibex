# AASA & Entitlements — VibeX quick guide

This file documents the exact steps to validate Associated Domains (AASA) and URL scheme setup for VibeX.

## Files changed by automation
- `vibex/Info.plist` — added `CFBundleURLTypes` with URL scheme `vibex`.
- `vibex/vibex.entitlements` — contains `com.apple.developer.associated-domains` pointing to `applinks:vibex-omik4v3ki-prnhubstudio.vercel.app`.
- `public/.well-known/apple-app-site-association` — AASA JSON deployed to site.

## 1) Verify AASA is publicly accessible
From any machine (no auth), run:

```bash
# primary (production) domain
curl -v https://vibex-omik4v3ki-prnhubstudio.vercel.app/.well-known/apple-app-site-association

# alias domain
curl -v https://vibex-tau.vercel.app/.well-known/apple-app-site-association
```

Expected: HTTP 200 and raw JSON content (no redirects to login pages). If you see a redirect to a login/SSO page, make the Vercel project publicly accessible or deploy the AASA to a public route.

## 2) Xcode — ensure entitlements are linked
1. Open the Xcode project `vibex.xcodeproj`.
2. Select the `vibex` target → `Signing & Capabilities`.
3. Verify `Associated Domains` is present. If not, click `+ Capability` → `Associated Domains`.
4. In the `Domains` list, ensure the value `applinks:vibex-omik4v3ki-prnhubstudio.vercel.app` is present.
   - Xcode will write this into the entitlements file (or you can point to `vibex/vibex.entitlements`).
5. Confirm `vibex/Info.plist` contains the `CFBundleURLTypes` entry with the scheme `vibex`.

## 3) Build & install on a physical device (recommended)
- Universal Links require a physical device to fully test (AASA fetched by the OS), but you can simulate openURL on simulator for custom scheme.

### Device steps
1. Build and run on your device (or upload to TestFlight and install).
2. On the device open Safari and visit a test URL matching AASA (example):
   - `https://vibex-omik4v3ki-prnhubstudio.vercel.app/u/test`
3. Expected: the app opens and the route is handled by `ProfileDeepLinkRouter`.

If it does not open immediately, try:
- Reinstall the app to force iOS to fetch the AASA again.
- Reboot device (rarely needed).

## 4) Simulator tests (quick)
- Test custom URL scheme (works in simulator):

```bash
# opens in the booted simulator
xcrun simctl openurl booted "vibex://profile?u=vibex&tab=ai&action=follow"

# opens the http URL (simulator may not process AASA like device)
xcrun simctl openurl booted "https://vibex-omik4v3ki-prnhubstudio.vercel.app/profile/vibex?tab=ai&action=follow"
```

## 5) Troubleshooting
- AASA returns a 302/SSO page: project or route is not public. Make the Vercel project or route publicly accessible.
- Entitlements not applied: ensure the entitlements file is listed in the target's build settings under `Code Signing Entitlements`.
- Link opens but router does nothing: enable logging in `ProfileDeepLinkRouter` or add temporary debug return of `current_setting('jwt.claims.role', true)` (server-side) — not necessary for app routing.

## 6) Notes
- Apple requires the AASA to be served over HTTPS on the exact domain listed and without redirects to an auth page.
- It may take iOS some time to pick up a new AASA; reinstalling the app usually forces a refresh.

---
If you want, I can produce a short shell script to validate the AASA and demonstrate the `simctl` commands.
