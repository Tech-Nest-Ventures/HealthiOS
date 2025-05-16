import SwiftUI
import Foundation

// First, define the WorkoutData struct
struct WorkoutData: Codable {
    let exerciseId: String
    let date: String
    let startTime: String
    let endTime: String
    let sets: Int?
    let weight: Double?
    let distance: Double?
    let temperature: Double?
    let notes: String?
}

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let tags: [String]
    let supports: ExerciseSupport
    let defaultMET: Double?
    let appleHealthId: String?
    
    struct ExerciseSupport: Codable, Hashable {
        let sets: Bool
        let duration: Bool
        let distance: Bool
        let weight: Bool
        let temperature: Bool
    }
}

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var healthKitManager: HealthKitManager
    
    @State private var exercises: [Exercise] = []
    @State private var selectedExercise: Exercise?
    @State private var isLoadingExercises = false
    @State private var loadingError: String?
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var sets: String = ""
    @State private var weight: String = ""
    @State private var distance: String = ""
    @State private var temperature: String = ""
    @State private var notes: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            if isLoadingExercises {
                ProgressView("Loading exercises...")
            } else if let error = loadingError {
                VStack {
                    Text("Error loading exercises: \(error)")
                    Button("Retry") {
                        fetchExercises()
                    }
                }
            } else {
                Form {
                    Section(header: Text("Exercise Details")) {
                        Picker("Exercise", selection: $selectedExercise) {
                            Text("Select Exercise").tag(Exercise?.none)
                            ForEach(exercises, id: \.id) { exercise in
                                Text(exercise.name)
                                    .tag(exercise as Exercise?)
                            }
                        }
                        
                        if let exercise = selectedExercise {
                            if exercise.supports.sets {
                                TextField("Sets", text: $sets)
                                    .keyboardType(.numberPad)
                            }
                            
                            if exercise.supports.weight {
                                TextField("Weight (kg)", text: $weight)
                                    .keyboardType(.decimalPad)
                            }
                            
                            if exercise.supports.distance {
                                TextField("Distance (km)", text: $distance)
                                    .keyboardType(.decimalPad)
                            }
                            
                            if exercise.supports.temperature {
                                TextField("Temperature (°C)", text: $temperature)
                                    .keyboardType(.decimalPad)
                            }
                        }
                        
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                    
                    Section(header: Text("Additional Information")) {
                        TextEditor(text: $notes)
                            .frame(height: 100)
                    }
                }
            }
        }
        .navigationTitle("Add Workout")
        .navigationBarItems(
            leading: Button("Cancel") {
                dismiss()
            },
            trailing: Button("Save") {
                saveWorkout()
            }
            .disabled(selectedExercise == nil)
        )
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            fetchExercises()
        }
    }
    
    private func fetchExercises() {
        isLoadingExercises = true
        loadingError = nil
        
        healthKitManager.fetchExercises { result in
            DispatchQueue.main.async {
                isLoadingExercises = false
                switch result {
                case .success(let fetchedExercises):
                    self.exercises = fetchedExercises
                case .failure(let error):
                    self.loadingError = error.localizedDescription
                }
            }
        }
    }
    
    private func saveWorkout() {
        guard let exercise = selectedExercise else {
            showError("Please select an exercise")
            return
        }
        
        guard endTime > startTime else {
            showError("End time must be after start time")
            return
        }
        
        let workoutData = WorkoutData(
            exerciseId: exercise.id,
            date: date.ISO8601Format(),
            startTime: startTime.ISO8601Format(),
            endTime: endTime.ISO8601Format(),
            sets: exercise.supports.sets ? Int(sets) : nil,
            weight: exercise.supports.weight ? Double(weight) : nil,
            distance: exercise.supports.distance ? Double(distance) : nil,
            temperature: exercise.supports.temperature ? Double(temperature) : nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        healthKitManager.saveWorkout(workoutData) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
