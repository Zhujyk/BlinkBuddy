# 👁️ BlinkBuddy

**BlinkBuddy** is a minimalist macOS "Agent" app (menu-bar only) designed to combat digital eye strain. It tracks your active screen time and gently reminds you to look away, helping you follow the 20-20-20 rule (every 20 minutes, look at something 20 feet away for 20 seconds).

## ✨ Features
- **Zero Dock Clutter:** Runs entirely in the menu bar.
- **Lightweight:** Built natively in Swift and SwiftUI for minimal CPU/RAM usage.
- **Smart Tracking:** Uses system idle timers to know when you're actually at your desk.
- **Non-Intrusive:** Designed to stay out of your way until it's time for a break.

## 🛠️ Architecture
The project follows the **MVVM** (Model-View-ViewModel) pattern to keep logic and UI separate:
- **App Layer:** Handles the menu bar lifecycle and background "Agent" status.
- **Logic Layer (`TimerManager`):** Manages the countdowns using `Foundation.Timer` and `CoreGraphics` to monitor user activity.
- **View Layer:** SwiftUI-based components for the menu dropdown and the "Look Away" overlay.

## 🚀 Getting Started

### Prerequisites
- macOS 13.0+
- Xcode 15.0+

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/Zhujyk/BlinkBuddy.git
