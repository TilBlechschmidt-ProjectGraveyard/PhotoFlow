//
//  AppDelegate.swift
//  PhotoFlow
//
//  Created by Til Blechschmidt on 19.05.19.
//  Copyright © 2019 Til Blechschmidt. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func loadDefaultSettings() {
        let defaultSettings = GenericSettings.defaults
            + ProjectGridSettings.defaults
            + ImageViewerSettings.defaults

        UserDefaults.standard.register(defaults: defaultSettings)

        let versionString = "\(Bundle.main.releaseVersionNumber ?? "0") (\(Bundle.main.buildVersionNumber ?? "0"))"
        GenericSettings.set(setting: .appVersion, versionString)
    }

    func loadDefaultWindow() {
        let window = UIWindow()
        window.rootViewController = DocumentBrowserViewController(forOpeningFilesWithContentTypes: nil)
        self.window = window
        window.makeKeyAndVisible()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        loadDefaultSettings()
        UIApplication.clearCaches()

        loadDefaultWindow()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open inputURL: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        guard let documentBrowserViewController = window?.rootViewController as? DocumentBrowserViewController else { return false }

        if let sourceApplication = options[.sourceApplication] as? String, sourceApplication == "de.blechschmidt.PhotoFlow.PhotoFlow-ShareExtension" {
            // If inputURL.host == "continueWorkflow", attempt to import image in inputURL.lastPathComponent

            ShareManager().processIncomingImage(withName: inputURL.lastPathComponent, documentBrowserViewController: documentBrowserViewController)

            return true
        }

        // Ensure the URL is a file URL
        guard inputURL.isFileURL else { return false }

        // Reveal / import the document at the URL
        documentBrowserViewController.revealDocument(at: inputURL, importIfNeeded: true) { (revealedDocumentURL, error) in
            if let error = error {
                // Handle the error appropriately
                print("Failed to reveal the document at URL \(inputURL) with error: '\(error)'")
                return
            }
            
            // Present the Document View Controller for the revealed URL
            documentBrowserViewController.presentDocument(at: revealedDocumentURL!)
        }

        return true
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
