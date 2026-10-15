import SwiftUI

/// Settings › Accounts: sign in to sites so downloads work as the signed-in user.
struct AccountsSection: View {
    @Environment(SiteSessions.self) private var sessions
    @Environment(\.openWindow) private var openWindow
    @State private var newSite = ""
    @State private var addingSite = false

    var body: some View {
        Section {
            ForEach(sessions.sites) { site in
                row(site)
            }
            if addingSite {
                HStack(spacing: 8) {
                    TextField("Site address, like vimeo.com", text: $newSite)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addSite)
                    Button("Add", action: addSite)
                        .disabled(SignInSite.custom(from: newSite) == nil)
                    Button("Cancel") {
                        addingSite = false
                        newSite = ""
                    }
                }
            } else {
                Button("Add Site…") { addingSite = true }
            }
        } header: {
            Text("Accounts")
        } footer: {
            Text("""
            Sign in once and downloads from that site work as you, including videos that \
            need an account. Sessions stay in Danny's browser on this Mac and reach the \
            download engine only for that site's links, only while they download.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func row(_ site: SignInSite) -> some View {
        let signedIn = sessions.isSignedIn(site)
        return HStack(spacing: 10) {
            SiteBadge(site: site, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(site.name)
                Text(signedIn ? "Signed in" : "Not signed in")
                    .font(.caption)
                    .foregroundStyle(signedIn ? D.doneEnd : .secondary)
            }
            Spacer()
            if signedIn {
                Button("Sign Out") { Task { await sessions.signOut(site) } }
            } else {
                Button("Sign In…") { openWindow(id: SignInView.windowID, value: site) }
            }
            if site.isCustom {
                Button {
                    Task { await sessions.removeSite(site) }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove \(site.name)")
            }
        }
    }

    private func addSite() {
        guard let site = sessions.addSite(newSite) else { return }
        newSite = ""
        addingSite = false
        openWindow(id: SignInView.windowID, value: site)
    }
}
