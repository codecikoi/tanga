import SwiftUI

/// Порядок и состав валют на главном экране.
struct EditListView: View {
    @Environment(ConverterStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.codes, id: \.self) { code in
                    HStack(spacing: 12) {
                        CurrencyBadge(code: code, currency: store.currency(code))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(code).font(.headline)
                            Text(store.currency(code)?.name ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { store.remove(atOffsets: $0) }
                .deleteDisabled(store.codes.count <= 1)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Мои валюты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Добавить", systemImage: "plus") { showPicker = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(isPresented: $showPicker) {
                CurrencyPickerView(mode: .add)
            }
        }
    }
}
