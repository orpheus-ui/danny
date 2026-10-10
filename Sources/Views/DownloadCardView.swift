import SwiftUI

struct DownloadCardView: View {
    let item: DownloadItem
    let onRemove: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onReveal: () -> Void
    let onBrowserCapture: () -> Void

    @State private var hovering = false
    @State private var showingSource = false

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .top)
            .background { D.cardShade.allowsHitTesting(false) }
            .background { thumbnailLayer }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(hovering ? 0.16 : 0.09), lineWidth: 1)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .dannyGlass(tint: Color.black.opacity(0.30), in: .rect(cornerRadius: 12))
            }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .onHover { hovering in
                self.hovering = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: hovering)
    }

    private var thumbnailLayer: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.09)
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
        .opacity(0.9)
        .allowsHitTesting(false)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            Spacer(minLength: 0)
            ProgressBarView(
                item: item,
                onRetry: onRetry,
                onBrowserCapture: onBrowserCapture,
            )
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if hovering {
                        Button {
                            showingSource.toggle()
                        } label: {
                            Image("icon-search")
                                .resizable()
                                .frame(width: 16, height: 16)
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
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.white.opacity(0.55))
        .lineLimit(1)
    }

    private var separatorDot: some View {
        Circle().frame(width: 3, height: 3).foregroundStyle(Color.white.opacity(0.4))
    }

    private var actionPills: some View {
        HStack(spacing: 8) {
            PillMenu(icon: "icon-dots") {
                if item.status.isActive {
                    Button("Cancel", action: onCancel)
                } else {
                    Button("Retry", action: onRetry)
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
