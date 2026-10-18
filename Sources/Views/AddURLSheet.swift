import SwiftUI

struct AddURLSheet: View {
    @Binding var url: String
    let onAdd: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Download from URL")
                .font(.system(size: 15, weight: .bold))
            TextField("https://…", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .tint(.purple)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private func submit() {
        guard let trimmed = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = trimmed.scheme?.lowercased(), ["http", "https"].contains(scheme)
        else { return }
        onAdd(trimmed)
        dismiss()
    }
}
