import SwiftUI
import SwiftData

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationScheduler.self) private var scheduler

    let category: Category?
    var onSave: (Category) -> Void

    @State private var name: String
    @State private var colorHex: String?
    @State private var showingDeleteConfirm = false

    init(category: Category?, onSave: @escaping (Category) -> Void) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _colorHex = State(initialValue: CategoryPolicy.normalizedColorHex(category?.colorHex))
    }

    private var canSave: Bool {
        CategoryPolicy.normalizedName(name) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .font(.caption.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(LunaTheme.secondary)
                        TextField("Work, home, health…", text: $name)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(LunaTheme.highlight)
                            .tint(LunaTheme.highlight)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("COLOR")
                            .font(.caption.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(LunaTheme.secondary)

                        Text("Optional. Leave unset if you just want a name.")
                            .font(.footnote)
                            .foregroundStyle(LunaTheme.secondary)

                        HStack(spacing: 12) {
                            Button {
                                colorHex = nil
                            } label: {
                                Image(systemName: "circle.slash")
                                    .font(.title3)
                                    .foregroundStyle(colorHex == nil ? LunaTheme.background : LunaTheme.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(colorHex == nil ? LunaTheme.highlight : LunaTheme.background.opacity(0.4), in: Circle())
                            }
                            .accessibilityLabel("No color")
                            .accessibilityAddTraits(colorHex == nil ? .isSelected : [])

                            ForEach(CategoryPolicy.suggestedColorHexes, id: \.self) { hex in
                                let selected = colorHex == hex
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(CategoryColorDot.color(from: hex) ?? LunaTheme.border)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            Circle().stroke(selected ? LunaTheme.highlight : Color.clear, lineWidth: 2)
                                        }
                                }
                                .accessibilityLabel("Color \(hex)")
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
                    }

                    if category != nil {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Text("Delete category")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(LunaTheme.highlight)
                                .background(LunaTheme.surface, in: Capsule())
                                .overlay {
                                    Capsule().stroke(LunaTheme.border, lineWidth: 1)
                                }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .lunaScreen()
            .navigationTitle(category == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LunaTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? LunaTheme.highlight : LunaTheme.border)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(LunaTheme.background, for: .navigationBar)
            .confirmationDialog("Delete this category?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteCategory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Tasks stay on the day. They become uncategorized.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let saved = TaskService(context: modelContext, scheduler: scheduler).saveCategory(
            existing: category,
            name: name,
            colorHex: colorHex
        ) else {
            return
        }
        onSave(saved)
        dismiss()
    }

    private func deleteCategory() {
        guard let category else { return }
        TaskService(context: modelContext, scheduler: scheduler).deleteCategory(category)
        dismiss()
    }
}

struct CategoryColorDot: View {
    var hex: String?
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(Self.color(from: hex) ?? LunaTheme.border)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    static func color(from hex: String?) -> Color? {
        guard let value = CategoryPolicy.parseColorHex(hex) else { return nil }
        return Color(hex: value)
    }
}
