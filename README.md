# SVPullToRefreshSwift

## Table of Contents
- [✨ Features](#-features)
- [🛠 Requirements](#-requirements)
- [📦 Installation](#-installation)
- [🚀 Usage](#-usage)
- [⚠️ Notes](#-notes)
- [📝 Version](#-version)
- [👤 Author](#-author)

---

## ✨ Features
- Pure Swift reimplementation of [SVPullToRefresh](https://github.com/samvermette/SVPullToRefresh).
- Pull-to-refresh support with customizable arrow, text, and activity indicator.
- Infinite scrolling support with loading state and "all loaded" state.
- Easy integration via `UIScrollView` extensions.
- No Objective-C code required, fully Swift 5.7+.

---

## 🛠 Requirements
- iOS 13.0+
- Swift 5.7+
- Xcode 14+

---

## 📦 Installation

### Swift Package Manager

Add the package in Xcode:

File → Add Packages → Enter URL: `https://github.com/vishalvaghasiya-ios/SVPullToRefreshSwift.git`

Or add it to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vishalvaghasiya-ios/SVPullToRefreshSwift.git", from: "1.0.0")
]
```

---

## 🚀 Usage

```swift
import SVPullToRefreshSwift

// Add Pull to Refresh
tableView.addPullToRefresh {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        tableView.stopPullToRefresh()
    }
}

// Add Infinite Scrolling
tableView.addInfiniteScrolling {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        tableView.stopInfiniteScrolling()
        // tableView.setInfiniteScrollingAllLoaded(true) // if no more data
    }
}
```

### API
- `scrollView.addPullToRefresh(height:action:)`
- `scrollView.triggerPullToRefresh()`
- `scrollView.stopPullToRefresh()`
- `scrollView.removePullToRefresh()`
- `scrollView.addInfiniteScrolling(action:)`
- `scrollView.triggerInfiniteScrolling()`
- `scrollView.stopInfiniteScrolling()`
- `scrollView.setInfiniteScrollingAllLoaded(_:)`
- `scrollView.removeInfiniteScrolling()`

---

## ⚠️ Notes
- Uses Swift `NSKeyValueObservation` to observe `contentOffset` and `contentSize`.
- Arrow is drawn with `CAShapeLayer` (replaceable with custom image).
- Customize labels for localization or branding.
- Works with any `UIScrollView` subclass (UITableView, UICollectionView, etc.).

---

## 📝 Version
Current Version: **1.0.0**

---

## 👤 Author
Developed by **Vishal Vaghasiya**  
🌐 GitHub: [vishalvaghasiya-ios](https://github.com/vishalvaghasiya-ios)
