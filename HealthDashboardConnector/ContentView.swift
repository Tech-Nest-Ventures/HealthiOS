//
//  ContentView.swift
//  HealthDashboardConnector
//
//  Created by Timeo on 3/15/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    let healthKitManager = HealthKitManager()
    @State private var isAuthorized = false
    @State private var message = "Tap to request HealthKit access"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Health Dashboard Connector")
                .font(.title)
                .padding()
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                requestHealthKitPermissions()
            }) {
                Text(isAuthorized ? "Permissions Granted!" : "Request Permissions")
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
                    self.message = "HealthKit access granted! You can now close this app."
                } else {
                    self.message = "Failed to get permissions: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
