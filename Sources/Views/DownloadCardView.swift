import SwiftUI

struct DownloadCardView: View {
    let item: DownloadItem
    let onRemove: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onReveal: () -> Void
    let onBrowserCapture: () -> Void
    var onSignIn: (() -> Void)?
    var onChoose: ((QualityChoice) -> Void)?
    var onResolveExisting: ((ExistingFilePolicy) -> Void)?
    var onKeepExisting: (() -> Void)?

    @State private var hovering = false
    @State private var showingSource = false
    @State private var showingError = false

    var body: some View {
        content
            .padding(D.Spacing.cardPadding)
            .frame(maxWidth: .infinity, minHeight: D.Size.cardHeight, maxHeight: D.Size.cardHeight, alignment: .top)
            .background { D.cardScrim.allowsHitTesting(false) }
            .background { thumbnailLayer }
            .clipShape(RoundedRectangle(cornerRadius: D.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: D.Radius.card, style: .continuous)
                    .strokeBorder(D.cardStroke, lineWidth: D.Stroke.card)
            }
            .onHover { hovering in
                self.hovering = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: hovering)
    }

    private var thumbnailLayer: some View {
        ZStack {
            D.cardBackdrop
            if let url = item.thumbnailURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            Spacer(minLength: 0)
            if item.status == .choosing, let options = item.qualityOptions, let onChoose {
                QualityChips(options: options, deadline: item.choiceDeadline, onChoose: onChoose)
            } else if item.status == .existing, let existing = item.existingFile,
                      let onResolveExisting, let onKeepExisting
            {
                ExistingFileChoices(existing: existing, onResolve: onResolveExisting, onKeep: onKeepExisting)
            } else {
                ProgressBarView(
                    item: item,
                    onRetry: onRetry,
                    onBrowserCapture: onBrowserCapture,
                    onSignIn: onSignIn,
                )
                .help(item.status == .failed ? item.errorMessage ?? "" : "")
                .popover(isPresented: $showingError, arrowEdge: .top) { errorPopover }
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(D.Font.cardTitle)
                        .foregroundStyle(D.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if hovering {
                        Button {
                            showingSource.toggle()
                        } label: {
                            Image("icon-search")
                                .resizable()
                                .frame(width: D.Size.cardIcon, height: D.Size.cardIcon)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                        .help(item.sourceURL.absoluteString)
                        .popover(isPresented: $showingSource, arrowEdge: .bottom) { sourcePopover }
                    }
                }
                metaRow
            }
            Spacer(minLength: 8)
            actionPills
        }
    }

    private var sourcePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(item.sourceURL.absoluteString)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
            HStack {
                Button("Open") {
                    NSWorkspace.shared.open(item.sourceURL)
                }
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.sourceURL.absoluteString, forType: .string)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 320)
    }

    /// yt-dlp's own output, for bug reports.
    private var errorPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Error Details")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(item.errorMessage ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.errorMessage ?? "", forType: .string)
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 360)
    }

    private var metaRow: some View {
        HStack(spacing: 5) {
            Text(item.host.replacingOccurrences(of: "www.", with: ""))
            if let resolution = item.resolution {
                separatorDot
                Text(resolution)
            }
            if let size = Format.size(item.totalBytes) {
                separatorDot
                Text(size)
            }
        }
        .font(D.Font.cardMeta)
        .foregroundStyle(D.textSecondary)
        .lineLimit(1)
    }

    private var separatorDot: some View {
        Circle().frame(width: 3, height: 3).foregroundStyle(D.textSecondary)
    }

    private var actionPills: some View {
        HStack(spacing: D.Spacing.cardActions) {
            PillMenu(icon: "icon-dots") {
                if item.status.isActive {
                    Button("Cancel", action: onCancel)
                } else {
                    Button("Retry", action: onRetry)
                }
                if item.status == .failed {
                    Button("Show Error Details") { showingError = true }
                }
                if item.filePath != nil {
                    Button("Show in Finder", action: onReveal)
                    Button("Copy File Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.filePath ?? "", forType: .string)
                    }
                }
                Divider()
                Button("Copy Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.sourceURL.absoluteString, forType: .string)
                }
                Divider()
                Button("Remove", role: .destructive, action: onRemove)
            }
            PillButton(icon: "icon-trash") {
                onRemove()
            }
            .help("Remove")
        }
    }
}
