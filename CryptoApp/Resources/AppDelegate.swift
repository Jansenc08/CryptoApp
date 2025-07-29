//
//  AppDelegate.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 25/6/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // 🏗️ INITIALIZE DEPENDENCY CONTAINER: Set up dependency injection first
        Dependencies.initialize()
        print("🏗️ AppDelegate: Dependency container initialized")
        
        // Initialize Core Data through DI container
        _ = Dependencies.container.coreDataManager()
        
        // 🌐 START SHARED DATA MANAGER: Ensure background price updates start immediately
        _ = Dependencies.container.sharedCoinDataManager()
        print("🌐 AppDelegate: SharedCoinDataManager started at app launch")
        
        #if DEBUG
        AppLogger.ui("CryptoApp launched in DEBUG mode with Dependency Injection")
        #endif
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

