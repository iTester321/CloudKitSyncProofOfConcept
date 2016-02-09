//
//  AppDelegate.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var coreDataManager: CoreDataManager?
    var cloudKitManager: CloudKitManager?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        coreDataManager = CoreDataManager() {
            [unowned self] in
            
            self.setCoreDataManagerInViews()
            
            self.cloudKitManager = self.coreDataManager?.cloudKitManager
            
        }
        
        let notificationOptions = UIUserNotificationSettings(forTypes: [.Alert], categories: nil)
        application.registerUserNotificationSettings(notificationOptions)
        
        application.registerForRemoteNotifications()
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    // MARK: remote notifications
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        print("application.didReceiveRemoteNotification")
        
        if let stringObjectUserInfo = userInfo as? [String : NSObject] {
            let cloudKitZoneNotificationUserInfo = CKRecordZoneNotification(fromRemoteNotificationDictionary: stringObjectUserInfo)
            
            if let recordZoneID = cloudKitZoneNotificationUserInfo.recordZoneID {
                
                let completionBlockOperation = NSBlockOperation {
                    completionHandler(UIBackgroundFetchResult.NewData)
                }
                
                cloudKitManager?.syncZone(recordZoneID.zoneName, completionBlockOperation: completionBlockOperation)
            }
        }
        else {
            completionHandler(UIBackgroundFetchResult.NoData)
        }
    }

    // MARK: Core Data Helper Methods
    func setCoreDataManagerInViews() {
        
        guard let safeCoreDataManager = coreDataManager else {
            fatalError("CoreDataManager expected to be set")
        }
        
        let tabBarController = window?.rootViewController as! UITabBarController
        let tabBarViewControllers = tabBarController.viewControllers!
        
        for viewController in tabBarViewControllers {
            
            switch viewController {
                
            case let navigationController as UINavigationController:
                if var rootViewController: CoreDataManagerViewController = navigationController.viewControllers[0] as? CoreDataManagerViewController {
                    rootViewController.coreDataManager = safeCoreDataManager
                }
            default: ()
            }
        }
    }
}

