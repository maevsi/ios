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
- 📦 **Zero setup** – dependencies included via CocoaPods
- 🚀 **Fast iteration** – update web content without app store releases

### 🔗 Related Projects

- 🌐 **Web App:** [maevsi/vibetype](https://github.com/maevsi/vibetype) – Progressive Web App (PWA)
- 🤖 **Android App:** [maevsi/android](https://github.com/maevsi/android) – Trusted Web Activity (TWA)

---

## ⚡ Quick Start

**Already have Xcode?** You can start immediately:

```sh
open vibetype.xcworkspace
```

That's it! All dependencies are pre-installed. Press `Cmd+R` to build and run.

> ℹ️ **Note:** Always open `vibetype.xcworkspace`, never `vibetype.xcodeproj`

---

## 🔧 Full Setup

### Prerequisites

- macOS with Xcode installed
- Apple Developer account for signing & push notifications (optional)
- Homebrew for managing Ruby (optional)

### Installing Dependencies

Dependencies are already included, but if you need to update or modify them:

<details>
<summary><strong>🍺 Step 1: Install Homebrew & Ruby</strong></summary>

```sh
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Ruby via Homebrew
brew install ruby
```

**Configure PATH** (choose based on your Mac architecture):

<details>
<summary>Apple Silicon (M1/M2/M3)</summary>

```sh
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
echo 'export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"' >> ~/.zshrc
echo 'export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"' >> ~/.zshrc
exec zsh
```
</details>

<details>
<summary>Intel Mac</summary>

```sh
echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >> ~/.zshrc
echo 'export LDFLAGS="-L/usr/local/opt/ruby/lib"' >> ~/.zshrc
echo 'export CPPFLAGS="-I/usr/local/opt/ruby/include"' >> ~/.zshrc
exec zsh
```
</details>

Verify installation:
```sh
ruby -v
# Should show Ruby 3.x
```

</details>

<details>
<summary><strong>💎 Step 2: Install CocoaPods</strong></summary>

```sh
gem install cocoapods
```

Verify:
```sh
pod --version
```

Common CocoaPods Commands:
```sh
# 📦 Install dependencies (after Podfile changes)
pod install

# ⬆️ Update pods to latest compatible versions
pod update

# 🔄 Refresh CocoaPods spec repository
pod install --repo-update

# 🧹 Remove CocoaPods integration completely
pod deintegrate

# 🗑️ Clear local cache (when troubleshooting)
pod cache clean --all
```

</details>
