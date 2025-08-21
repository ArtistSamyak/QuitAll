# QuitAll 🚀  

**QuitAll** is a lightweight macOS utility that instantly closes all running applications — leaving only the essential system processes alive.  
Think of it as a "panic button" or "clean slate" switch when your Mac is overloaded with apps, or you just want a fresh start. 

<img src="https://github.com/user-attachments/assets/c6f27343-d0c8-4e93-b463-960308b8822e" alt="QuitAll screenshot" width="240"/> 

## ✨ Features
- **One-Click Quit**: Shut down every running app with a single press.  
- **Safe Defaults**: Protects critical macOS processes (Finder, Dock, SystemUIServer, etc.) so your system stays stable.  
- **Brute-Force Mode**: Handles stubborn apps with multiple passes (`terminate → SIGTERM → SIGKILL → pkill`).  
- **Minimal & Fast**: No menus, no clutter. Launch → Press → Done.  
- **Notarized & Signed**: Distributed outside the App Store, but Apple-notarized for security.  

## 📥 Installation
1. Extract the archive — you’ll see `QuitAll.app`.  
2. Drag `QuitAll.app` into your **Applications** folder.

## 🖥️ Usage
- Open **QuitAll**.  
- Hit the big **QUIT ALL** button.  
- All non-essential applications will close immediately.  

> ⚠️ Note: This includes apps that auto-launch in the background (VPNs, messengers, etc.).  

## 🔧 Technical Details
- Written in **SwiftUI**.  
- Uses **NSWorkspace** to query running apps.  
- Multi-stage shutdown pipeline:  
  - `.terminate()` (polite quit)  
  - `SIGTERM` (soft kill)  
  - `SIGKILL` (hard kill)  
  - `pkill` sweeps for stubborn multiprocess apps (browsers, Slack, etc.).  
- Leaves critical system daemons untouched for safety.  


## 🛡️ Security & Signing
QuitAll is **signed** with a Developer ID and **notarized by Apple**, ensuring it runs cleanly on macOS without Gatekeeper warnings.  

---

## 📦 Version
- **Current version**: `1.0.1`  
