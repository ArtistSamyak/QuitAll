//
//  ContentView.swift
//  KillSwitch
//
//  Created by Samyak Pawar on 21/08/2025.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var isKilling = false
    @State private var lastResult = ""
    @State private var isPressedVisual = false // purely for animation timing

    var body: some View {
        ZStack {
            // Subtle vignette background
            RadialGradient(colors: [Color.black.opacity(0.95), Color.black], center: .center, startRadius: 10, endRadius: 380)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                // The button
                Button {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { isPressedVisual = true }
                    Task {
                        await KillSwitch.killAllFast(result: $lastResult, flag: $isKilling)
                        // if your app terminates at the end, this won't run anyway; harmless
                    }
                } label: {
                    Text(isKilling ? "..." : "QUIT ALL")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(2)
                        .accessibilityLabel("Kill Switch")
                }
                .buttonStyle(KillButtonStyle(isBusy: isKilling, pressedFlag: $isPressedVisual))

                // Status (tiny)
                Text(lastResult.isEmpty ? " " : lastResult)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(height: 20)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(18)
        }
        .onChange(of: isKilling) { _, busy in
            if !busy {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { isPressedVisual = false }
            }
        }
    }
}


enum KillSwitch {
    private static let protectedNames: Set<String> = [
        "Finder", "Dock", "loginwindow", "SystemUIServer", "WindowServer"
    ]

    private static let protectedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.SystemUIServer",
        "com.apple.WindowServer"
    ]

    /// Main entry
    static func killAllFast(result: Binding<String>, flag: Binding<Bool>) async {
        await MainActor.run { flag.wrappedValue = true; result.wrappedValue = "Working...\n" }

        // 1) Snapshot NSWorkspace apps (fast path: GUI/Accessory)
        let selfBID = Bundle.main.bundleIdentifier
        let wsTargets = NSWorkspace.shared.runningApplications.filter { app in
            guard app.processIdentifier > 0, !app.isTerminated else { return false }
            if let bid = app.bundleIdentifier, bid == selfBID || protectedBundleIDs.contains(bid) { return false }
            if let name = app.localizedName, protectedNames.contains(name) { return false }
            return true
        }

        // Polite → TERM → KILL for app layer
        for a in wsTargets { _ = a.terminate() }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        for a in wsTargets where !a.isTerminated { _ = Darwin.kill(a.processIdentifier, SIGTERM) }
        usleep(200_000)
        for a in wsTargets where !a.isTerminated { _ = Darwin.kill(a.processIdentifier, SIGKILL) }

        // 2) Generic sweep of *all* user processes (name-agnostic), excluding system paths & protected names
        wipeAllUserProcesses(suppressionSeconds: 3.0)

        // 3) Final quick peek (anything left that’s ours and not protected? kill)
        let leftovers = NSWorkspace.shared.runningApplications.filter { a in
            guard a.processIdentifier > 0, !a.isTerminated else { return false }
            if let bid = a.bundleIdentifier, bid == selfBID || protectedBundleIDs.contains(bid) { return false }
            if let name = a.localizedName, protectedNames.contains(name) { return false }
            return true
        }
        for a in leftovers { _ = Darwin.kill(a.processIdentifier, SIGKILL) }

        let log = """
        Targets (initial apps): \(wsTargets.count)
        Final leftovers: \(leftovers.count)
        Done.
        """
        await MainActor.run {
            result.wrappedValue = log
            flag.wrappedValue = false
            NSApp.terminate(nil)
        }
    }

    /// Kills every process owned by the current user except:
    /// - protected session services (by name)
    /// - our own process
    /// - anything whose executable path is in system locations (/System, /usr, /bin, /sbin, /Library/Apple)
    /// Runs a short "suppression window" to re-kill auto-relaunching login items.
    private static func wipeAllUserProcesses(suppressionSeconds: TimeInterval) {
        let uid = getuid()
        let selfPID = getpid()

        let deadline = Date().addingTimeInterval(suppressionSeconds)
        repeat {
            let entries = psList()
            for e in entries where e.uid == uid {
                let pid = e.pid
                if pid == 0 || pid == selfPID { continue }

                // Exclude protected by name
                if protectedNames.contains(e.name) { continue }

                // Exclude if the executable path is clearly system-owned
                if let path = procPath(pid) {
                    if path.hasPrefix("/System/") ||
                       path.hasPrefix("/usr/") ||
                       path.hasPrefix("/bin/") ||
                       path.hasPrefix("/sbin/") ||
                       path.hasPrefix("/Library/Apple/") {
                        continue
                    }
                }

                // Try TERM first (cheap), then KILL
                _ = Darwin.kill(pid, SIGTERM)
            }

            // Short grace
            usleep(150_000)

            // Hard kill anything still around that matches criteria
            let again = psList()
            for e in again where e.uid == uid {
                let pid = e.pid
                if pid == 0 || pid == selfPID { continue }
                if protectedNames.contains(e.name) { continue }
                if let path = procPath(pid) {
                    if path.hasPrefix("/System/") ||
                       path.hasPrefix("/usr/") ||
                       path.hasPrefix("/bin/") ||
                       path.hasPrefix("/sbin/") ||
                       path.hasPrefix("/Library/Apple/") {
                        continue
                    }
                }
                _ = Darwin.kill(pid, SIGKILL)
            }

            // Keep reaping respawns during the suppression window
            if Date() < deadline { usleep(180_000) }
        } while Date() < deadline
    }

    // MARK: - Process listing helpers

    /// Simple `ps` reader: returns pid, uid, and process name (basename of command)
    private static func psList() -> [(pid: pid_t, uid: uid_t, name: String)] {
        let p = Process()
        p.launchPath = "/bin/ps"
        // comm prints the *executable name*; ucomm also works. We’ll fetch full path via procPath when needed.
        p.arguments = ["-axo", "pid=,uid=,comm="]

        let pipe = Pipe()
        p.standardOutput = pipe
        do { try p.run() } catch { return [] }
        p.waitUntilExit()

        guard let data = try? pipe.fileHandleForReading.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return [] }

        var out: [(pid_t, uid_t, String)] = []
        for line in text.split(separator: "\n") {
            // pid uid comm
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = pid_t(parts[0]),
                  let uid = uid_t(parts[1]) else { continue }
            // name is last path component of comm
            let comm = String(parts[2])
            let name = URL(fileURLWithPath: comm).lastPathComponent
            out.append((pid, uid, name))
        }
        return out
    }

    /// Get the full executable path for a pid (if available) using proc_pidpath
    private static func procPath(_ pid: pid_t) -> String? {
        let bufSize = 4 * 256 // 1024
        var buf = [CChar](repeating: 0, count: bufSize)
        let ret = buf.withUnsafeMutableBufferPointer { bp in
            bp.baseAddress.map { proc_pidpath(pid, $0, UInt32(bufSize)) } ?? 0
        }
        if ret > 0 { return String(cString: buf) }
        return nil
    }
}
