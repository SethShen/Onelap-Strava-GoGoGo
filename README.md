# 顽鹿 Strava 同步

一个 Android Flutter App，将 OneLap（顽鹿）平台的骑行活动自动同步到 Strava。

**开源地址：** https://github.com/Tyan66666/Onelap-Strava-GoGoGo

## 功能

- 自动从 OneLap 下载 FIT 活动文件
- 上传到 Strava，自动去重避免重复
- 设置同步天数（默认 3 天）
- 内置 Strava OAuth 授权，无需手动填写 Token
- 凭证加密存储在设备本地（Android Keystore）

## 使用前提

1. OneLap 账号
2. 自己的 Strava API 应用（Client ID + Client Secret）

> Strava 对个人开发者 API 有配额限制，每个应用每 15 分钟 200 次、每天 2000 次。因此需要你使用自己的 Strava API 凭证，详见 App 内设置说明。

## 注册 Strava API 步骤

1. 登录 https://www.strava.com/settings/api
2. 创建应用，Authorization Callback Domain 填 `localhost`
3. 复制 Client ID 和 Client Secret 填入 App 设置
4. 点击"授权 Strava"完成 OAuth 授权

## 构建

```bash
flutter pub get
flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false
```

## 免责声明

本应用为个人开源项目，与 OneLap 及 Strava 官方无任何关联。使用本应用所产生的一切后果由用户自行承担，作者不承担任何责任。本应用不收集、不存储、不上传任何用户数据，所有凭证仅保存在设备本地。
