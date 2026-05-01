<div align="center">

# 📱 Vibetype iOS

**The native iOS wrapper for Vibetype's Progressive Web App**

[![CI Status][ci-image]][ci-url]

[ci-image]: https://img.shields.io/github/actions/workflow/status/maevsi/ios/ci.yml
[ci-url]: https://github.com/maevsi/ios/actions/workflows/ci.yml

</div>

---

## 📋 Table of Contents

- [Overview](#🎯-overview)
- [Quick Start](#⚡-quick-start)
- [Full Setup](#🔧-full-setup)

---

## 🎯 Overview

Vibetype iOS provides a native wrapper around Vibetype's Progressive Web App, running in a `WKWebView`. This approach gives you:

- ✅ **Native feel** with full-screen WebView experience
- 🔔 **Push notifications** via Firebase Cloud Messaging (APNs-backed)
- 📦 **Zero setup** – dependencies managed via Swift Package Manager
- 🚀 **Fast iteration** – update web content without app store releases

### 🔗 Related Projects

- 🌐 **Web App:** [maevsi/vibetype](https://github.com/maevsi/vibetype) – Progressive Web App (PWA)
- 🤖 **Android App:** [maevsi/android](https://github.com/maevsi/android) – Trusted Web Activity (TWA)

---

## ⚡ Quick Start

**Already have Xcode?** You can start immediately:

```sh
open vibetype.xcodeproj
```

That's it! SPM handles all dependencies automatically. Press `Cmd+R` to build and run.

---

## 🔧 Full Setup

### Prerequisites

- macOS with Xcode installed
- Apple Developer account for signing & push notifications (optional)
- Homebrew for managing Ruby (optional)

### Managing Dependencies

Dependencies are managed through Swift Package Manager (SPM), which is integrated into Xcode. No additional tools need to be installed.

**To update dependencies:**

1. Open `vibetype.xcodeproj` in Xcode
2. Go to **File** → **Packages** → **Update to Latest Package Versions**
3. Or select the project, then **Package Dependencies** tab to manage individual packages
