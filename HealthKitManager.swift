import Foundation
import HealthKit

class HealthKitManager {
    let healthStore = HKHealthStore()
    
    // Request authorization for multiple HealthKit data types
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead, completion: completion)
    }
    
    // Fetch step count for the current day
    func fetchStepCount(completion: @escaping (Double?, Error?) -> Void) {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Step count type not available"]))
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                completion(nil, error)
                return
            }
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
            completion(steps, nil)
        }

        healthStore.execute(query)
    }
    
    // Fetch active energy burned for the current day (in kilocalories)
    func fetchActiveEnergyBurned(completion: @escaping (Double?, Error?) -> Void) {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Active energy type not available"]))
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                completion(nil, error)
                return
            }
            let energy = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
            completion(energy, nil)
        }

        healthStore.execute(query)
    }
    
    // Fetch dietary water for the current day (in liters)
    func fetchDietaryWater(completion: @escaping (Double?, Error?) -> Void) {
        guard let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else {
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dietary water type not available"]))
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                completion(nil, error)
                return
            }
            let water = result?.sumQuantity()?.doubleValue(for: HKUnit.liter()) ?? 0.0
            completion(water, nil)
        }

        healthStore.execute(query)
    }
    
    // Fetch sleep analysis for the current day (total time asleep in hours)
    func fetchSleepAnalysis(completion: @escaping (Double?, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sleep analysis type not available"]))
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let sleepSamples = samples as? [HKCategorySample] else {
                completion(0.0, nil)
                return
            }

            let totalSleepTime = sleepSamples.reduce(0.0) { total, sample in
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                return total
            }
            let hoursAsleep = totalSleepTime / 3600.0 // Convert seconds to hours
            completion(hoursAsleep, nil)
        }

        healthStore.execute(query)
    }
    
    // Send health data to a private server
    func sendHealthDataToServer(steps: Double?, energy: Double?, water: Double?, sleep: Double?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "https://yourserver.com/api/health") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "steps": steps ?? 0.0,
            "energyBurned": energy ?? 0.0,
            "waterIntake": water ?? 0.0,
            "sleepHours": sleep ?? 0.0,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }

            completion(.success(()))
        }.resume()
    }
}
