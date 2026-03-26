# 顽爪爪同步 / WanSync

<img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" alt="顽爪爪同步图标">

一款可以同步顽鹿 FIT 文件到 Strava 的小工具。

*A lightweight Android app to sync OneLap (顽鹿) FIT activity files to Strava.*

---

## 功能 / Features

- 自动从 OneLap 下载 FIT 活动文件 / Auto-download FIT files from OneLap
- 上传到 Strava，自动去重避免重复 / Upload to Strava with deduplication
- 设置同步天数（默认 3 天）/ Configurable lookback days (default 3)
- 内置 Strava OAuth 授权，无需手动填写 Token / Built-in Strava OAuth flow
- 凭证仅保存在设备本地 / Credentials stored locally on device only

---

## 使用前提 / Prerequisites

1. OneLap（顽鹿）账号 / An OneLap account
2. 自己的 Strava API 应用（Client ID + Client Secret）/ Your own Strava API app

> Strava 对个人开发者 API 有配额限制（每 15 分钟 200 次、每天 2000 次），因此需要你使用自己的 Strava API 凭证，详见 App 内设置说明。
>
> *Strava enforces API rate limits (200 req/15 min, 2000 req/day), so each user must use their own Strava API credentials. See in-app instructions for details.*

---

## 注册 Strava API / Setting Up Strava API

1. 登录 https://www.strava.com/settings/api / Log in at https://www.strava.com/settings/api
2. 创建应用，Authorization Callback Domain 填 `localhost` / Create an app, set Authorization Callback Domain to `localhost`
3. 复制 Client ID 和 Client Secret 填入 App 设置 / Copy Client ID and Client Secret into the app settings
4. 点击「授权 Strava」完成 OAuth 授权，Access Token、Refresh Token 和 Expires At 将自动填入 / Tap "授权 Strava" to complete OAuth — Access Token, Refresh Token and Expires At will be filled in automatically

---

## 构建 / Build

```bash
flutter pub get
flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false
```

---

## 免责声明 / Disclaimer

本应用为个人开源项目，与 OneLap 及 Strava 官方无任何关联。使用本应用所产生的一切后果由用户自行承担，作者不承担任何责任。本应用不收集、不存储、不上传任何用户数据，所有凭证仅保存在设备本地。

*This is a personal open-source project with no affiliation to OneLap or Strava. Use at your own risk. The author accepts no liability. No user data is collected, stored, or uploaded — all credentials are kept locally on your device.*

---

## 联系作者 / Contact

- GitHub: https://github.com/Tyan66666/Onelap-Strava-GoGoGo
- 小红书 / Xiaohongshu: https://xhslink.com/m/2SMVhuDAzdq
