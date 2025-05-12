import Foundation
import HealthKit
import BackgroundTasks
import UIKit

class HealthKitManager: ObservableObject {
    private let tokenKey = "authToken"
    private let healthStore = HKHealthStore()
    
    // Login function
    func login(username: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://backend-production-5eec.up.railway.app/api/v1/auth/login") else {
            print("Invalid login URL")
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid login URL"])))
            return
        }

        let body = ["username": username, "password": password]
        guard let jsonData = try? JSONEncoder().encode(body) else {
            print("Failed to encode login data")
            completion(.failure(NSError(domain: "HealthKitManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode login data"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        print("Sending login request with email:", username)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Login request failed with error:", error.localizedDescription)
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("No HTTP response received")
                completion(.failure(NSError(domain: "HealthKitManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])))
                return
            }

            print("Login response status code:", httpResponse.statusCode)
            guard (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                    print("Login failed with response:", responseString)
                }
                completion(.failure(NSError(domain: "HealthKitManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Login failed with status \(httpResponse.statusCode)"])))
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let token = json["token"] as? String else {
                print("Failed to parse token from response:", String(data: data, encoding: .utf8) ?? "No data")
                completion(.failure(NSError(domain: "HealthKitManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid login response"])))
                return
            }

            print("Received JWT from server:", token)
            UserDefaults.standard.set(token, forKey: self.tokenKey)
            print("Saved token to UserDefaults:", UserDefaults.standard.string(forKey: self.tokenKey) ?? "None")
            completion(.success(token))
        }.resume()
    }

    // Retrieve token
    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .waistCircumference)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!
        ]
     
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if !success {
                print("Permission denied: \(error?.localizedDescription ?? "Unknown")")
            }
            completion(success, error)
        }
    }

    // MARK: - Data Fetching

    func fetchStepCount(completion: @escaping (Double?, Error?) -> Void) {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(0.0, nil) // Changed to return 0 instead of error
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Step fetch error: \(error.localizedDescription)")
                completion(0.0, nil) // Changed to return 0 instead of error
                return
            }
            let todaySteps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
            print("Fetched steps for today: \(todaySteps)")
            completion(todaySteps, nil)
        }
        healthStore.execute(query)
    }

    func fetchActiveEnergyBurned(completion: @escaping (Double?, Error?) -> Void) {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0.0, nil)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Energy fetch error: \(error.localizedDescription)")
                completion(0.0, nil)
                return
            }
            let energy = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
            print("Fetched energy: \(energy) kcal")
            completion(energy, nil)
        }
        healthStore.execute(query)
    }

    func fetchDietaryWater(completion: @escaping (Double?, Error?) -> Void) {
        guard let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else {
            completion(0.0, nil)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Water fetch error: \(error.localizedDescription)")
                completion(0.0, nil)
                return
            }
            let waterLiters = result?.sumQuantity()?.doubleValue(for: HKUnit.liter()) ?? 0.0
            print("Fetched water: \(waterLiters) liters")
            completion(waterLiters, nil)
        }
        healthStore.execute(query)
    }

    func fetchSleepAnalysis(completion: @escaping (Double?, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0.0, nil)
            return
        }

        let now = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("Sleep fetch error: \(error.localizedDescription)")
                completion(0.0, nil)
                return
            }

            let sleepSamples = samples as? [HKCategorySample] ?? []
            let totalSleepHours = sleepSamples.filter {
                [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ].contains($0.value)
            }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }
            print("Fetched sleep: \(totalSleepHours) hours")
            completion(totalSleepHours, nil)
        }
        healthStore.execute(query)
    }
    
    func fetchWeight(completion: @escaping (Double?, Date?, Error?) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            completion(0.0, nil, nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Weight fetch error: \(error.localizedDescription)")
                completion(0.0, nil, nil)
                return
            }
            if let sample = samples?.first as? HKQuantitySample {
                let weight = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                let date = sample.endDate
                print("Fetched weight: \(weight) kg on \(date)")
                completion(weight, date, nil)
            } else {
                print("No weight data available")
                completion(0.0, nil, nil)
            }
        }
        healthStore.execute(query)
    }

    func fetchBodyFatPercentage(completion: @escaping (Double?, Date?, Error?) -> Void) {
        guard let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) else {
            completion(0.0, nil, nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: bodyFatType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Body fat fetch error: \(error.localizedDescription)")
                completion(0.0, nil, nil)
                return
            }
            if let sample = samples?.first as? HKQuantitySample {
                let bodyFat = sample.quantity.doubleValue(for: HKUnit.percent()) * 100
                let date = sample.endDate
                print("Fetched body fat: \(bodyFat)% on \(date)")
                completion(bodyFat, date, nil)
            } else {
                print("No body fat data available")
                completion(0.0, nil, nil)
            }
        }
        healthStore.execute(query)
    }

    func fetchWaistCircumference(completion: @escaping (Double?, Date?, Error?) -> Void) {
        guard let waistType = HKObjectType.quantityType(forIdentifier: .waistCircumference) else {
            completion(0.0, nil, nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: waistType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Waist fetch error: \(error.localizedDescription)")
                completion(0.0, nil, nil)
                return
            }
            if let sample = samples?.first as? HKQuantitySample {
                let waist = sample.quantity.doubleValue(for: HKUnit.inch())
                let date = sample.endDate
                print("Fetched waist circumference: \(waist) inches on \(date)")
                completion(waist, date, nil)
            } else {
                print("No waist circumference data available")
                completion(0.0, nil, nil)
            }
        }
        healthStore.execute(query)
    }

    func fetchDietaryCalories(completion: @escaping (Double?, Error?) -> Void) {
        guard let calorieType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(0.0, nil)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Calories fetch error: \(error.localizedDescription)")
                completion(0.0, nil)
                return
            }
            let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
            print("Fetched calories: \(calories) kcal")
            completion(calories, nil)
        }
        healthStore.execute(query)
    }

    func fetchDietaryCarbs(completion: @escaping (Double?, Error?) -> Void) {
        guard let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            completion(0.0, nil)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: carbsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Carbs fetch error: \(error.localizedDescription)")
                completion(0.0, nil)
                return
            }
            let carbs = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
            print("Fetched carbs: \(carbs) g")
            completion(carbs, nil)
        }
        healthStore.execute(query)
    }

    func fetchDietaryFat(completion: @escaping (Double?, Error?) -> Void) {
        guard let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) else {
            completion(0.0, nil)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: fatType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Fat fetch error: \(error.localizedDescription)")
                completion(0.0, nil)
                return
            }
            let fat = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
            print("Fetched fat: \(fat) g")
            completion(fat, nil)
        }
        healthStore.execute(query)
    }

    func fetchDietaryProtein(completion: @escaping (Double?, Error?) -> Void) {
        guard let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) else {
            completion(0.0, nil)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: proteinType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Protein fetch error: \(error.localizedDescription)")
                completion(0.0, nil)
                return
            }
            let protein = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
            print("Fetched protein: \(protein) g")
            completion(protein, nil)
        }
        healthStore.execute(query)
    }

    // MARK: - Data Sending

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

    func sendHealthDataToServer(
        steps: Double?,
        energy: Double?,
        water: Double?,
        sleep: Double?,
        weight: Double?,
        weightDate: Date?,
        bodyFat: Double?,
        bodyFatDate: Date?,
        waistCircumference: Double?,
        waistDate: Date?,
        calories: Double?,
        carbs: Double?,
        fat: Double?,
        protein: Double?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "https://backend-production-5eec.up.railway.app/api/v1/health/persist") else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        guard let token = getToken() else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "No auth token available. Please log in."])))
            return
        }
        print("Sending token in request:", token)
        let dateFormatter = ISO8601DateFormatter()
        let healthData = HealthData(
            timestamp: Date().ISO8601Format(),
            steps: steps ?? 0.0,
            sleep: sleep ?? 0.0,
            activity: energy ?? 0.0,
            water: water ?? 0.0,
            weight: weight ?? 0.0,
            weightDate: weightDate.map { dateFormatter.string(from: $0) },
            bodyFat: bodyFat ?? 0.0,
            bodyFatDate: bodyFatDate.map { dateFormatter.string(from: $0) },
            waistCircumference: waistCircumference ?? 0.0,
            waistDate: waistDate.map { dateFormatter.string(from: $0) },
            calories: calories ?? 0.0,
            carbs: carbs ?? 0.0,
            fat: fat ?? 0.0,
            protein: protein ?? 0.0
        )

        print("Health data to send: \(healthData)")
        guard let jsonData = try? JSONEncoder().encode(healthData) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode health data"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // Add JWT
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending data: \(error)")
                completion(.failure(error))
                return
            }
            print("Sending health data request with headers:", request.allHTTPHeaderFields ?? [:])
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP response status code: \(httpResponse.statusCode)")
                if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                    print("HTTP response data: \(responseString)")
                }
                if !(200...299).contains(httpResponse.statusCode) {
                    completion(.failure(NSError(domain: "HealthKitManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                    return
                }
            }
            print("Health data sent successfully")
            completion(.success(()))
        }.resume()
    }

    // MARK: - Background Fetch

    func fetchAndSendHealthDataInBackground(completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var steps: Double?
        var energy: Double?
        var water: Double?
        var sleep: Double?
        var weight: Double?
        var weightDate: Date?
        var bodyFat: Double?
        var bodyFatDate: Date?
        var waist: Double?
        var waistDate: Date?
        var calories: Double?
        var carbs: Double?
        var fat: Double?
        var protein: Double?

        group.enter()
        fetchStepCount { fetchedSteps, _ in
            steps = fetchedSteps
            group.leave()
        }

        group.enter()
        fetchActiveEnergyBurned { fetchedEnergy, _ in
            energy = fetchedEnergy
            group.leave()
        }

        group.enter()
        fetchDietaryWater { fetchedWater, _ in
            water = fetchedWater
            group.leave()
        }

        group.enter()
        fetchSleepAnalysis { fetchedSleep, _ in
            sleep = fetchedSleep
            group.leave()
        }

        group.enter()
        fetchWeight { fetchedWeight, date, _ in
            weight = fetchedWeight
            weightDate = date
            group.leave()
        }

        group.enter()
        fetchBodyFatPercentage { fetchedBodyFat, date, _ in
            bodyFat = fetchedBodyFat
            bodyFatDate = date
            group.leave()
        }

        group.enter()
        fetchWaistCircumference { fetchedWaist, date, _ in
            waist = fetchedWaist
            waistDate = date
            group.leave()
        }

        group.enter()
        fetchDietaryCalories { fetchedCalories, _ in
            calories = fetchedCalories
            group.leave()
        }

        group.enter()
        fetchDietaryCarbs { fetchedCarbs, _ in
            carbs = fetchedCarbs
            group.leave()
        }

        group.enter()
        fetchDietaryFat { fetchedFat, _ in
            fat = fetchedFat
            group.leave()
        }

        group.enter()
        fetchDietaryProtein { fetchedProtein, _ in
            protein = fetchedProtein
            group.leave()
        }

        group.notify(queue: .main) {
            self.sendHealthDataToServer(
                steps: steps,
                energy: energy,
                water: water,
                sleep: sleep,
                weight: weight,
                weightDate: weightDate,
                bodyFat: bodyFat,
                bodyFatDate: bodyFatDate,
                waistCircumference: waist,
                waistDate: waistDate,
                calories: calories,
                carbs: carbs,
                fat: fat,
                protein: protein,
                completion: completion
            )
        }
    }

    // MARK: - Background Tasks (iOS 13+)

    func scheduleHealthDataFetch() {
        let identifier = "com.example.healthdatafetch" // Replace with your app's identifier
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // Schedule for tomorrow
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    func handleHealthDataFetch(task: BGAppRefreshTask) {
        scheduleHealthDataFetch() // Reschedule the task

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        fetchAndSendHealthDataInBackground { result in
            switch result {
            case .success:
                task.setTaskCompleted(success: true)
            case .failure:
                task.setTaskCompleted(success: false)
            }
        }
    }
}

extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
