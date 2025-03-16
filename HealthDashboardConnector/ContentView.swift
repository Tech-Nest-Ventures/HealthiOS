import SwiftUI
import HealthKit

struct ContentView: View {
    let healthKitManager = HealthKitManager()
    @State private var isAuthorized = false
    @State private var message = "Tap to request HealthKit access"
    @State private var steps: Double? = nil
    @State private var energy: Double? = nil
    @State private var water: Double? = nil
    @State private var sleep: Double? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("Health Dashboard Connector")
                .font(.title)
                .padding()

            Text(message)
                .multilineTextAlignment(.center)
                .padding()

            if isAuthorized {
                VStack {
                    if let steps = steps {
                        Text("Steps: \(steps, specifier: "%.0f")")
                    }
                    if let energy = energy {
                        Text("Energy Burned (kcal): \(energy, specifier: "%.2f")")
                    }
                    if let water = water {
                        Text("Water Intake (L): \(water, specifier: "%.2f")")
                    }
                    if let sleep = sleep {
                        Text("Sleep (hours): \(sleep, specifier: "%.2f")")
                    }
                }
            }

            Button(action: {
                if !isAuthorized {
                    requestHealthKitPermissions()
                } else {
                    fetchAndSendHealthData()
                }
            }) {
                Text(isAuthorized ? "Fetch and Send Data" : "Request Permissions")
                    .padding()
                    .background(isAuthorized ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    func requestHealthKitPermissions() {
        healthKitManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthorized = true
                    self.message = "HealthKit access granted! Tap to fetch and send data."
                    fetchAndSendHealthData()
                } else {
                    self.message = "Failed to get permissions: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }

    func fetchAndSendHealthData() {
        let group = DispatchGroup()
        var fetchError: Error?

        // Fetch all data concurrently
        group.enter()
        healthKitManager.fetchStepCount { steps, error in
            if let error = error {
                fetchError = error
            }
            self.steps = steps
            group.leave()
        }

        group.enter()
        healthKitManager.fetchActiveEnergyBurned { energy, error in
            if let error = error {
                fetchError = error
            }
            self.energy = energy
            group.leave()
        }

        group.enter()
        healthKitManager.fetchDietaryWater { water, error in
            if let error = error {
                fetchError = error
            }
            self.water = water
            group.leave()
        }

        group.enter()
        healthKitManager.fetchSleepAnalysis { sleep, error in
            if let error = error {
                fetchError = error
            }
            self.sleep = sleep
            group.leave()
        }

        group.notify(queue: .main) {
            if let error = fetchError {
                self.message = "Failed to fetch data: \(error.localizedDescription)"
            } else {
                self.sendDataToServer()
            }
        }
    }

    func sendDataToServer() {
        healthKitManager.sendHealthDataToServer(steps: steps, energy: energy, water: water, sleep: sleep) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.message = "Data sent to server successfully!"
                case .failure(let error):
                    self.message = "Failed to send data: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
