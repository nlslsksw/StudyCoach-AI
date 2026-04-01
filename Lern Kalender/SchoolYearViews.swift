import SwiftUI

// MARK: - Manage School Years View

struct ManageSchoolYearsView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore
    @State private var showingAddSchoolYear = false

    var body: some View {
        NavigationStack {
            List {
                if store.schoolYears.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Noch keine Schuljahre")
                            .foregroundStyle(.secondary)
                        Text("Erstelle ein Schuljahr, um deine Fächer zu organisieren.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                } else {
                    let active = store.schoolYears.filter { !$0.isArchived }.sorted { $0.startDate > $1.startDate }
                    let archived = store.schoolYears.filter { $0.isArchived }.sorted { $0.startDate > $1.startDate }

                    if !active.isEmpty {
                        Section("Aktiv") {
                            ForEach(active) { sy in
                                SchoolYearRow(store: store, schoolYear: sy)
                            }
                        }
                    }

                    if !archived.isEmpty {
                        Section("Archiviert") {
                            ForEach(archived) { sy in
                                SchoolYearRow(store: store, schoolYear: sy)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schuljahre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSchoolYear = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSchoolYear) {
                AddSchoolYearView(store: store)
            }
        }
    }
}

// MARK: - School Year Row

struct SchoolYearRow: View {
    var store: DataStore
    let schoolYear: SchoolYear

    private var subjectCount: Int {
        store.subjectsFor(schoolYear: schoolYear).count
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schoolYear.name)
                .font(.headline)
            HStack(spacing: 8) {
                Text("\(subjectCount) Fächer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(dateFormatter.string(from: schoolYear.startDate)) – \(dateFormatter.string(from: schoolYear.endDate))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation {
                    store.deleteSchoolYear(schoolYear)
                }
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation {
                    store.toggleArchiveSchoolYear(schoolYear)
                }
            } label: {
                Label(
                    schoolYear.isArchived ? "Aktivieren" : "Archivieren",
                    systemImage: schoolYear.isArchived ? "arrow.uturn.backward" : "archivebox"
                )
            }
            .tint(schoolYear.isArchived ? .blue : .orange)
        }
    }
}

// MARK: - Add School Year View

struct AddSchoolYearView: View {
    @Environment(\.dismiss) private var dismiss
    var store: DataStore

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private var autoName: String {
        let cal = Calendar.current
        let startYear = cal.component(.year, from: startDate)
        let endYear = cal.component(.year, from: endDate)
        return "\(startYear)/\(endYear)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. 2025/2026", text: $name)
                    if name.isEmpty {
                        Text("Vorschlag: \(autoName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Zeitraum") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                    DatePicker("Ende", selection: $endDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }
            }
            .navigationTitle("Schuljahr hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? autoName : name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let schoolYear = SchoolYear(
                            name: finalName,
                            startDate: startDate,
                            endDate: endDate
                        )
                        store.addSchoolYear(schoolYear)
                        dismiss()
                    }
                }
            }
        }
    }
}
