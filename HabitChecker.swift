//
//  HabitChecker.swift
//  A simple habit checker for iPhone (SwiftUI)
//
//  HOW TO USE:
//  1. Open Xcode → File → New → Project → iOS → App
//  2. Product Name: "HabitChecker", Interface: SwiftUI, Language: Swift
//  3. Delete the auto-generated ContentView.swift and HabitCheckerApp.swift
//  4. Drag this file into the project (make sure "Copy items if needed" is checked)
//  5. Build & Run (⌘R) on an iPhone simulator or device
//

import SwiftUI

// MARK: - Model

struct Habit: Identifiable, Codable {
    let id: UUID
    var name: String
    var completedDates: Set<DateComponents> // stores year/month/day only

    init(id: UUID = UUID(), name: String, completedDates: Set<DateComponents> = []) {
        self.id = id
        self.name = name
        self.completedDates = completedDates
    }
}

// MARK: - Store (persistence via UserDefaults + Codable)

@MainActor
final class HabitStore: ObservableObject {
    @Published var habits: [Habit] = [] {
        didSet { save() }
    }

    private let storageKey = "habit_checker_habits"
    private let calendar = Calendar.current

    init() {
        load()
    }

    // MARK: Public actions

    func addHabit(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        habits.append(Habit(name: trimmed))
    }

    func deleteHabit(at offsets: IndexSet) {
        habits.remove(atOffsets: offsets)
    }

    func toggleToday(for habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let todayComponents = dayComponents(for: Date())

        if habits[index].completedDates.contains(todayComponents) {
            habits[index].completedDates.remove(todayComponents)
        } else {
            habits[index].completedDates.insert(todayComponents)
        }
    }

    func isCompletedToday(_ habit: Habit) -> Bool {
        habit.completedDates.contains(dayComponents(for: Date()))
    }

    /// Current consecutive-day streak, counting back from today (or yesterday
    /// if today isn't done yet, so a streak isn't lost until the day is over).
    func currentStreak(for habit: Habit) -> Int {
        var streak = 0
        var day = Date()

        if !habit.completedDates.contains(dayComponents(for: day)) {
            // Today not done yet — check if yesterday keeps the streak alive.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        while habit.completedDates.contains(dayComponents(for: day)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: Helpers

    private func dayComponents(for date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: date)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Habit].self, from: data) else { return }
        habits = decoded
    }
}

// MARK: - Main list screen

struct ContentView: View {
    @StateObject private var store = HabitStore()
    @State private var isShowingAddSheet = false
    @State private var newHabitName = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + to add your first habit.")
                    )
                } else {
                    List {
                        ForEach(store.habits) { habit in
                            HabitRow(habit: habit, store: store)
                        }
                        .onDelete(perform: store.deleteHabit)
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddHabitSheet(store: store, isPresented: $isShowingAddSheet)
            }
        }
    }
}

// MARK: - Row

struct HabitRow: View {
    let habit: Habit
    @ObservedObject var store: HabitStore

    var body: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    store.toggleToday(for: habit)
                }
            } label: {
                Image(systemName: store.isCompletedToday(habit) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(store.isCompletedToday(habit) ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.body)
                    .strikethrough(store.isCompletedToday(habit), color: .secondary)

                let streak = store.currentStreak(for: habit)
                if streak > 0 {
                    Label("\(streak) day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add habit sheet

struct AddHabitSheet: View {
    @ObservedObject var store: HabitStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Habit name (e.g. Drink water)", text: $name)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(addAndClose)
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: addAndClose)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private func addAndClose() {
        store.addHabit(named: name)
        isPresented = false
    }
}

// MARK: - App entry point

@main
struct HabitCheckerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
