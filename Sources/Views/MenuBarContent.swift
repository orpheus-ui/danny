import AppKit
import SwiftUI

/// What the popover's buttons ask of the app beyond the queue: bring Danny forward,
/// with a card in view or the capture browser, open Settings.
struct MenuBarActions {
    var openDanny: () -> Void
    var show: (UUID) -> Void
    var browserCapture: () -> Void
    var openSettings: () -> Void
}

/// The menu-bar popover on the system's glass: a headline, the add row, the downloads
/// running now, the last finished files, and two quick settings. It exists only while open.
struct MenuBarContent: View {
    let model: MenuBarPopoverModel
    let manager: DownloadManager
    @Bindable var settings: AppSettings
    let actions: MenuBarActions
    @State private var typedLink = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            addRow
            if !model.list.active.isEmpty { activeSection }
            if !model.list.finished.isEmpty { finishedSection }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image("menu-bar-mark")
                .resizable()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(model.list.headline)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
            Spacer(minLength: 8)
            if !model.list.active.isEmpty {
                Button("Pause All", action: manager.pauseAll)
            } else if model.list.paused > 0 {
                Button("Resume All", action: manager.resumeAll)
            }
            Menu {
                Button("Open Danny", action: actions.openDanny)
                Button("Settings…", action: actions.openSettings)
                Divider()
                Button("Quit Danny") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More")
        }
    }

    // MARK: Add

    @ViewBuilder private var addRow: some View {
        if let link = model.clipboardLink {
            Button { manager.add(url: link) } label: {
                HStack(spacing: 8) {
                    SiteIcon(host: link.host() ?? "")
                    Text("Download \(ClipboardToast.shortLink(link))")
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Image(systemName: "return").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .background {
                // ⌘V adds the link too.
                Button("Paste and Download") { manager.add(url: link) }
                    .keyboardShortcut("v")
                    .opacity(0)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Download \(ClipboardToast.shortLink(link)) from the clipboard")
        } else {
            HStack(spacing: 8) {
                TextField("Paste or type a link", text: $typedLink)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTypedLink)
                Button(action: actions.browserCapture) {
                    Image(systemName: "globe")
                }
                .help("Browser Capture")
                .accessibilityLabel("Browser Capture")
            }
        }
    }

    private func addTypedLink() {
        guard let url = LinkIntake.link(from: typedLink) else { return }
        manager.add(url: url)
        typedLink = ""
    }

    // MARK: Lists

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(model.list.active) { item in
                ActiveRow(
                    item: item,
                    onShow: { actions.show(item.id) },
                    onPause: { manager.pause(id: item.id) },
                    onCancel: { manager.cancel(id: item.id) },
                )
            }
            if model.list.more > 0 {
                Button("+\(model.list.more) more…", action: actions.openDanny)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var finishedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently finished")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(model.list.finished) { item in
                FinishedRow(
                    item: item, age: MenuBarList.age(of: item.finishedAt, now: model.now),
                    onOpen: { manager.open(id: item.id) },
                    onReveal: { manager.revealInFinder(id: item.id) },
                )
            }
        }
    }

    // MARK: Footer

    private static let speedLimits = [0, 1_000_000, 5_000_000, 10_000_000]

    private var footer: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Speed limit", selection: $settings.speedLimit) {
                    ForEach(Self.speedLimits, id: \.self) { limit in
                        Text(Format.speed(Double(limit)) ?? "Unlimited").tag(limit)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Limit: \(Format.speed(Double(settings.speedLimit)) ?? "Unlimited")", systemImage: "speedometer")
            }
            .menuStyle(.button)
            .fixedSize()
            Toggle(isOn: $settings.downloadsOnlyOnWiFi) {
                Label("Wi-Fi only", systemImage: "wifi")
            }
            .toggleStyle(.button)
            Spacer(minLength: 0)
        }
        .controlSize(.small)
    }
}

// MARK: - Rows

/// The site's icon from the cache, a globe until it arrives or when it has none.
private struct SiteIcon: View {
    let host: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(systemName: "globe").foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
        .task(id: host) { icon = await Favicons.shared.image(for: host) }
    }
}

private struct Thumbnail: View {
    let url: URL?

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay {
                if let url {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                }
            }
            .frame(width: 40, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}

private struct ActiveRow: View {
    let item: MenuBarList.Active
    let onShow: () -> Void
    let onPause: () -> Void
    let onCancel: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onShow) {
                HStack(spacing: 10) {
                    Thumbnail(url: item.thumbnailURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Capsule()
                            .fill(.quaternary)
                            .frame(height: 4)
                            .overlay(alignment: .leading) {
                                GeometryReader { bar in
                                    Capsule().fill(D.progressFill).frame(width: bar.size.width * (item.fraction ?? 0))
                                }
                            }
                        Text(item.detail)
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.spokenLabel)
            .accessibilityHint("Shows it in Danny")
            Button(action: onPause) {
                Image(systemName: "pause.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .accessibilityLabel("Pause \(item.title)")
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .accessibilityLabel("Cancel \(item.title)")
        }
        .onHover { hovering = $0 }
    }
}

private struct FinishedRow: View {
    let item: MenuBarList.Finished
    let age: String
    let onOpen: () -> Void
    let onReveal: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Thumbnail(url: item.thumbnailURL)
                    Text(item.title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(age)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.title), \(age)")
            .accessibilityHint("Opens the file")
            // The file itself, to drop into Finder or Messages; Show in Finder is the alternative.
            .onDrag { NSItemProvider(contentsOf: item.fileURL) ?? NSItemProvider() }
            Button(action: onReveal) {
                Image(systemName: "magnifyingglass.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .accessibilityLabel("Show \(item.title) in Finder")
        }
        .onHover { hovering = $0 }
    }
}
