import SwiftUI

/// What the list shows with no cards: an outline where the first card will go, saying how
/// to add one, or why a search found nothing. Not in Figma: designed in M1 from the card.
struct EmptyListView: View {
    let filter: DownloadFilter
    let items: [DownloadItem]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: D.Radius.card, style: .continuous)
        VStack(spacing: 8) {
            Image(filter.isEmpty ? "icon-plus" : "icon-search")
                .resizable()
                .frame(width: D.Size.cardIcon, height: D.Size.cardIcon)
                .padding(D.Size.cardIconPadding)
                .background(Circle().fill(D.pillFill))
                .overlay { Circle().strokeBorder(D.pillStroke, lineWidth: 1) }
            Text(title)
                .font(D.Font.cardTitle)
                .foregroundStyle(D.textPrimary)
            if let hint {
                Text(hint)
                    .font(D.Font.cardMeta)
                    .foregroundStyle(D.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: D.Size.cardHeight)
        .background(shape.fill(D.emptyCardFill))
        .overlay(shape.strokeBorder(D.pillStroke, style: StrokeStyle(lineWidth: D.Stroke.card, dash: [6, 5])))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if filter.link != nil {
            return filter.linkIsListed(in: items) ? "No downloads match these filters" : "Not in your downloads yet"
        }
        if filter.isEmpty { return "Paste a link to download it" }
        let text = filter.text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "Nothing here" : "No downloads match “\(text)”"
    }

    private var hint: String? {
        if filter.link != nil, !filter.linkIsListed(in: items) { return "Press Return to download it" }
        if filter.isEmpty { return "Press ⌘V or drop it here. A tricky site? Try Browser Capture." }
        return nil
    }
}

#if DEBUG
    #Preview("Empty list") {
        EmptyListView(filter: DownloadFilter(), items: [])
            .padding()
            .frame(width: 640)
            .background(D.ink)
    }

    #Preview("No search results") {
        EmptyListView(filter: DownloadFilter(text: "cats"), items: [])
            .padding()
            .frame(width: 640)
            .background(D.ink)
    }
#endif
