import SwiftUI
import HealthKit

struct HealthData: Codable {
    let timestamp: String
    let steps: Double
    let sleep: Double
    let activity: Double
    let water: Double
    let weight: Double
    let weightDate: String?
    let bodyFat: Double
    let bodyFatDate: String?
    let waistCircumference: Double
    let waistDate: String?
    let calories: Double
    let carbs: Double
    let fat: Double
    let protein: Double
}

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var isLoggedIn = false
    @State private var username = ""
    @State private var password = ""
    @State private var loginError: String?

    var body: some View {
        if isLoggedIn || healthKitManager.getToken() != nil {
            HealthDashboardView(healthKitManager: healthKitManager)
                .onAppear {
                    // Check token on appear; if invalid, log out
                    if healthKitManager.getToken() != nil {
                        isLoggedIn = true
                    }
                }
        } else {
            LoginView(
                username: $username,
                password: $password,
                loginError: $loginError,
                onLogin: {
                    healthKitManager.login(username: username, password: password) { result in
                        switch result {
                        case .success:
                            isLoggedIn = true
                            loginError = nil
                        case .failure(let error):
                            loginError = "Login failed: \(error.localizedDescription)"
                        }
                    }
                }
            )
        }
    }
}

struct LoginView: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var loginError: String?
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Login to Health Dashboard")
                .font(.title2)
                .padding()

            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.username)
                .autocapitalization(.none)
                .padding(.horizontal)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.password)
                .padding(.horizontal)

            if let error = loginError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button(action: onLogin) {
                Text("Login")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct HealthDashboardView: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @State private var isAuthorized = UserDefaults.standard.bool(forKey: "HealthKitAuthorized")
    @State private var message = "Tap to request HealthKit access"
    @State private var steps: Double? = nil
    @State private var energy: Double? = nil
    @State private var water: Double? = nil
    @State private var sleep: Double? = nil
    @State private var weight: Double? = nil
    @State private var weightDate: Date? = nil
    @State private var bodyFat: Double? = nil
    @State private var bodyFatDate: Date? = nil
    @State private var waistCircumference: Double? = nil
    @State private var waistDate: Date? = nil
    @State private var calories: Double? = nil
    @State private var carbs: Double? = nil
    @State private var fat: Double? = nil
    @State private var protein: Double? = nil
    @State private var lastUpdated: Date? = UserDefaults.standard.object(forKey: "LastUpdated") as? Date
    @State private var isLoading = false
    @State private var showingAddWorkout = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Health Dashboard Connector")
                    .font(.title)
                    .padding()

                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()

                if isAuthorized {
                    VStack(spacing: 10) {
                        Text("Steps: \(steps ?? 0, specifier: "%.0f")")
                        Text("Energy Burned (kcal): \(energy ?? 0, specifier: "%.2f")")
                        Text("Water Intake (L): \(water ?? 0, specifier: "%.2f")")
                        Text("Sleep (hours): \(sleep ?? 0, specifier: "%.2f")")
                        
                        Text("Weight (kg): \(weight ?? 0, specifier: "%.1f")") +
                            (weightDate != nil ? Text(" (Last: \(weightDate!, formatter: dateFormatter))") : Text(""))
                        
                        Text("Body Fat (%): \(bodyFat ?? 0, specifier: "%.1f")") +
                            (bodyFatDate != nil ? Text(" (Last: \(dateFormatter.string(from: bodyFatDate!)))") : Text(""))
                        
                        Text("Waist (in): \(waistCircumference ?? 0, specifier: "%.1f")") +
                            (waistDate != nil ? Text(" (Last: \(dateFormatter.string(from: waistDate!)))") : Text(""))
                        
                        Text("Calories (kcal): \(calories ?? 0, specifier: "%.0f")")
                        Text("Carbs (g): \(carbs ?? 0, specifier: "%.1f")")
                        Text("Fat (g): \(fat ?? 0, specifier: "%.1f")")
                        Text("Protein (g): \(protein ?? 0, specifier: "%.1f")")
                        
                        if let lastUpdated = lastUpdated {
                            Text("Last Updated: \(lastUpdated, formatter: dateFormatter)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                }

                if isAuthorized {
                    Menu {
                        Button(action: {
                            fetchAndSendHealthData()
                        }) {
                            Label("Persist Data", systemImage: "arrow.up.to.line")
                        }
                        
                        Button(action: {
                            showingAddWorkout = true
                        }) {
                            Label("Add Workout", systemImage: "figure.run")
                        }
                        
                        Button(role: .destructive, action: {
                            logout()
                        }) {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                            .padding()
                    }
                    .disabled(isLoading)
                } else {
                    Button(action: {
                        if !isAuthorized {
                            requestHealthKitPermissions()
                        } else {
                            fetchAndSendHealthData()
                        }
                    }) {
                        Text(isLoading ? "Loading..." : (isAuthorized ? "Fetch and Send Data" : "Request Permissions"))
                            .padding()
                            .background(isAuthorized ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isLoading)
                }
            }
            .padding()
            .navigationTitle("Health Dashboard")
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView(healthKitManager: healthKitManager)
            }
        }
    }

    func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.message = "HealthKit is not available on this device."
            return
        }
        healthKitManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthorized = true
                    UserDefaults.standard.set(true, forKey: "HealthKitAuthorized")
                    self.message = "HealthKit access granted! Tap to fetch and send data."
                    fetchAndSendHealthData()
                } else {
                    self.message = "Failed to get permissions: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }

    func fetchAndSendHealthData() {
        isLoading = true
        let group = DispatchGroup()
        var errors: [String: Error] = [:]

        group.enter()
        healthKitManager.fetchStepCount { steps, error in
            if let error = error { errors["steps"] = error }
            self.steps = steps
            group.leave()
        }

        group.enter()
        healthKitManager.fetchActiveEnergyBurned { energy, error in
            if let error = error { errors["energy"] = error }
            self.energy = energy
            group.leave()
        }

        group.enter()
        healthKitManager.fetchDietaryWater { water, error in
            if let error = error { errors["water"] = error }
            self.water = water
            group.leave()
        }

        group.enter()
        healthKitManager.fetchSleepAnalysis { sleep, error in
            if let error = error { errors["sleep"] = error }
            self.sleep = sleep
            group.leave()
        }

        group.enter()
        healthKitManager.fetchWeight { weight, date, error in
            if let error = error { errors["weight"] = error }
            self.weight = weight
            self.weightDate = date
            group.leave()
        }

        group.enter()
        healthKitManager.fetchBodyFatPercentage { bodyFat, date, error in
            if let error = error { errors["bodyFat"] = error }
            self.bodyFat = bodyFat
            self.bodyFatDate = date
            group.leave()
        }

        group.enter()
        healthKitManager.fetchWaistCircumference { waist, date, error in
            if let error = error { errors["waist"] = error }
            self.waistCircumference = waist
            self.waistDate = date
            group.leave()
        }

        group.enter()
        healthKitManager.fetchDietaryCalories { calories, error in
            self.calories = calories ?? (error != nil ? 0 : nil)
            if let error = error, error.localizedDescription != "No data available for the specified predicate." {
                errors["calories"] = error
            }
            group.leave()
        }

        group.enter()
        healthKitManager.fetchDietaryCarbs { carbs, error in
            self.carbs = carbs ?? (error != nil ? 0 : nil)
            if let error = error, error.localizedDescription != "No data available for the specified predicate." {
                errors["carbs"] = error
            }
            group.leave()
        }

        group.enter()
        healthKitManager.fetchDietaryFat { fat, error in
            self.fat = fat ?? (error != nil ? 0 : nil)
            if let error = error, error.localizedDescription != "No data available for the specified predicate." {
                errors["fat"] = error
            }
            group.leave()
        }

        group.enter()
        healthKitManager.fetchDietaryProtein { protein, error in
            self.protein = protein ?? (error != nil ? 0 : nil)
            if let error = error, error.localizedDescription != "No data available for the specified predicate." {
                errors["protein"] = error
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if !errors.isEmpty {
                let errorMessage = errors.map { "\($0.key): \($0.value.localizedDescription)" }.joined(separator: "\n")
                self.message = "Some data failed to fetch:\n\(errorMessage)"
            } else {
                self.message = "All data fetched successfully!"
            }
            self.sendDataToServer()
            self.isLoading = false
        }
    }

    func sendDataToServer() {
        healthKitManager.sendHealthDataToServer(
            steps: steps,
            energy: energy,
            water: water,
            sleep: sleep,
            weight: weight,
            weightDate: weightDate,
            bodyFat: bodyFat,
            bodyFatDate: bodyFatDate,
            waistCircumference: waistCircumference,
            waistDate: waistDate,
            calories: calories,
            carbs: carbs,
            fat: fat,
            protein: protein
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.message = "Data sent to server successfully!"
                    self.lastUpdated = Date()
                    UserDefaults.standard.set(self.lastUpdated, forKey: "LastUpdated")
                case .failure(let error):
                    self.message = "Failed to send data: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func logout() {
        // Implement logout functionality
        print("Logging out")
    }
}

#Preview {
    ContentView()
}
