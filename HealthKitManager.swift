import Foundation
import HealthKit
import BackgroundTasks
import UIKit

class HealthKitManager: ObservableObject {
    private let tokenKey = "authToken"
    let healthStore = HKHealthStore()

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

    func getToken() -> String? {
           let token = UserDefaults.standard.string(forKey: tokenKey)
           print("getToken called, returned: \(token ?? "nil")")
           return token
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

    func fetchStepCount(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Step fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
                return
            }
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
            print("Fetched steps for \(date): \(steps)")
            completion(steps)
        }
        healthStore.execute(query)
    }

    func fetchActiveEnergyBurned(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Energy fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
                return
            }
            let energy = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
            print("Fetched energy for \(date): \(energy) kcal")
            completion(energy)
        }
        healthStore.execute(query)
    }

    func fetchDietaryWater(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Water fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
                return
            }
            let waterLiters = result?.sumQuantity()?.doubleValue(for: HKUnit.liter()) ?? 0.0
            print("Fetched water for \(date): \(waterLiters) liters")
            completion(waterLiters)
        }
        healthStore.execute(query)
    }

    func fetchSleepAnalysis(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("Sleep fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
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
            
            print("Fetched sleep for \(date): \(totalSleepHours) hours")
            completion(totalSleepHours)
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
    
    func logout() {
            // Clear the stored token (adjust based on how you store it)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        print("Token cleared from UserDefaults")
        }

    func fetchDietaryCalories(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let calorieType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Calories fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
                return
            }
            let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
            print("Fetched calories for \(date): \(calories) kcal")
            completion(calories)
        }
        healthStore.execute(query)
    }

    func fetchDietaryCarbs(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: carbsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Carbs fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
                return
            }
            let carbs = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
            print("Fetched carbs for \(date): \(carbs) g")
            completion(carbs)
        }
        healthStore.execute(query)
    }

    func fetchDietaryFat(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: fatType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Fat fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
                return
            }
            let fat = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
            print("Fetched fat for \(date): \(fat) g")
            completion(fat)
        }
        healthStore.execute(query)
    }

    func fetchDietaryProtein(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) else {
            completion(0.0)
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: proteinType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Protein fetch error for \(date): \(error.localizedDescription)")
                completion(0.0)
                return
            }
            let protein = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
            print("Fetched protein for \(date): \(protein) g")
            completion(protein)
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
        fetchStepCount(for: Date()) { fetchedSteps in
            steps = fetchedSteps
            group.leave()
        }

        group.enter()
        fetchActiveEnergyBurned(for: Date()) { fetchedEnergy in
            energy = fetchedEnergy
            group.leave()
        }

        group.enter()
        fetchDietaryWater(for: Date()) { fetchedWater in
            water = fetchedWater
            group.leave()
        }

        group.enter()
        fetchSleepAnalysis(for: Date()) { fetchedSleep in
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
        fetchDietaryCalories(for: Date()) { fetchedCalories in
            calories = fetchedCalories
            group.leave()
        }

        group.enter()
        fetchDietaryCarbs(for: Date()) { fetchedCarbs in
            carbs = fetchedCarbs
            group.leave()
        }

        group.enter()
        fetchDietaryFat(for: Date()) { fetchedFat in
            fat = fetchedFat
            group.leave()
        }

        group.enter()
        fetchDietaryProtein(for: Date()) { fetchedProtein in
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
    func saveWorkout(_ workout: WorkoutData, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "https://backend-production-5eec.up.railway.app/api/v1/workouts") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        guard let token = getToken() else {
            completion(.failure(NSError(domain: "", code: -4, userInfo: [NSLocalizedDescriptionKey: "No auth token available"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(workout)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
            }
        }.resume()
    }
    
    func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    func fetchExercises(completion: @escaping (Result<[Exercise], Error>) -> Void) {
        guard let url = URL(string: "https://backend-production-5eec.up.railway.app/api/v1/exercises") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        guard let token = getToken() else {
            completion(.failure(NSError(domain: "", code: -4, userInfo: [NSLocalizedDescriptionKey: "No auth token available"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let exercises = try JSONDecoder().decode([Exercise].self, from: data)
                completion(.success(exercises))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Add this new method to fetch health data for a specific date
    func fetchHealthDataForDate(_ date: Date, completion: @escaping (Result<HealthData, Error>) -> Void) {
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
        
        // Helper function to create date range for a specific day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch steps for the specific date
        group.enter()
        if let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Step fetch error for \(date): \(error.localizedDescription)")
                }
                steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        // Fetch active energy for the specific date
        group.enter()
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Energy fetch error for \(date): \(error.localizedDescription)")
                }
                energy = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        // Fetch water for the specific date
        group.enter()
        if let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Water fetch error for \(date): \(error.localizedDescription)")
                }
                water = result?.sumQuantity()?.doubleValue(for: HKUnit.liter()) ?? 0.0
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        // Fetch sleep for the specific date
        group.enter()
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Sleep fetch error for \(date): \(error.localizedDescription)")
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
                
                sleep = totalSleepHours
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        // Fetch calories for the specific date
        group.enter()
        if let calorieType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Calories fetch error for \(date): \(error.localizedDescription)")
                }
                calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        // Fetch carbs for the specific date
        group.enter()
        if let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: carbsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Carbs fetch error for \(date): \(error.localizedDescription)")
                }
                carbs = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        // Fetch fat for the specific date
        group.enter()
        if let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: fatType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Fat fetch error for \(date): \(error.localizedDescription)")
                }
                fat = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        // Fetch protein for the specific date
        group.enter()
        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: proteinType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Protein fetch error for \(date): \(error.localizedDescription)")
                }
                protein = result?.sumQuantity()?.doubleValue(for: HKUnit.gram()) ?? 0.0
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }
        
        group.notify(queue: .main) {
            let healthData = HealthData(
                timestamp: date.ISO8601Format(),
                steps: steps ?? 0.0,
                sleep: sleep ?? 0.0,
                activity: energy ?? 0.0,
                water: water ?? 0.0,
                weight: weight ?? 0.0,
                weightDate: weightDate.map { ISO8601DateFormatter().string(from: $0) },
                bodyFat: bodyFat ?? 0.0,
                bodyFatDate: bodyFatDate.map { ISO8601DateFormatter().string(from: $0) },
                waistCircumference: waist ?? 0.0,
                waistDate: waistDate.map { ISO8601DateFormatter().string(from: $0) },
                calories: calories ?? 0.0,
                carbs: carbs ?? 0.0,
                fat: fat ?? 0.0,
                protein: protein ?? 0.0
            )
            completion(.success(healthData))
        }
    }

    // Add this method to handle backfilling
    func backfillHealthData(from startDate: Date, to endDate: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        let calendar = Calendar.current
        var currentDate = startDate
        var errors: [Error] = []
        
        func processNextDate() {
            guard currentDate <= endDate else {
                if errors.isEmpty {
                    completion(.success(()))
                } else {
                    completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Some dates failed to process: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"])))
                }
                return
            }
            
            fetchHealthDataForDate(currentDate) { result in
                switch result {
                case .success(let healthData):
                    // Send the data to server
                    self.sendHealthDataToServer(
                        steps: healthData.steps,
                        energy: healthData.activity,
                        water: healthData.water,
                        sleep: healthData.sleep,
                        weight: healthData.weight,
                        weightDate: ISO8601DateFormatter().date(from: healthData.weightDate ?? ""),
                        bodyFat: healthData.bodyFat,
                        bodyFatDate: ISO8601DateFormatter().date(from: healthData.bodyFatDate ?? ""),
                        waistCircumference: healthData.waistCircumference,
                        waistDate: ISO8601DateFormatter().date(from: healthData.waistDate ?? ""),
                        calories: healthData.calories,
                        carbs: healthData.carbs,
                        fat: healthData.fat,
                        protein: healthData.protein
                    ) { sendResult in
                        switch sendResult {
                        case .success:
                            // Move to next date
                            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                            processNextDate()
                        case .failure(let error):
                            errors.append(error)
                            // Continue with next date even if this one failed
                            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                            processNextDate()
                        }
                    }
                case .failure(let error):
                    errors.append(error)
                    // Continue with next date even if this one failed
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    processNextDate()
                }
            }
        }
        
        // Start processing dates
        processNextDate()
    }

    // Updated backward-compatible methods
    func fetchStepCount(completion: @escaping (Double?, Error?) -> Void) {
        fetchStepCount(for: Date()) { steps in
            completion(steps, nil)
        }
    }
    func fetchActiveEnergyBurned(completion: @escaping (Double?, Error?) -> Void) {
        fetchActiveEnergyBurned(for: Date()) { energy in
            completion(energy, nil)
        }
    }
    func fetchDietaryWater(completion: @escaping (Double?, Error?) -> Void) {
        fetchDietaryWater(for: Date()) { water in
            completion(water, nil)
        }
    }
    func fetchSleepAnalysis(completion: @escaping (Double?, Error?) -> Void) {
        fetchSleepAnalysis(for: Date()) { sleep in
            completion(sleep, nil)
        }
    }
    func fetchDietaryCalories(completion: @escaping (Double?, Error?) -> Void) {
        fetchDietaryCalories(for: Date()) { calories in
            completion(calories, nil)
        }
    }
    func fetchDietaryCarbs(completion: @escaping (Double?, Error?) -> Void) {
        fetchDietaryCarbs(for: Date()) { carbs in
            completion(carbs, nil)
        }
    }
    func fetchDietaryFat(completion: @escaping (Double?, Error?) -> Void) {
        fetchDietaryFat(for: Date()) { fat in
            completion(fat, nil)
        }
    }
    func fetchDietaryProtein(completion: @escaping (Double?, Error?) -> Void) {
        fetchDietaryProtein(for: Date()) { protein in
            completion(protein, nil)
        }
    }
}

extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
