//
//  CloudKitEnums.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/12/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import UIKit
import CloudKit

enum CloudKitZone: String {
    case CarZone = "CarZone"
    case TruckZone = "TruckZone"
    case BusZone = "BusZone"
    
    init?(recordType: String) {
        switch recordType {
        case ModelObjectType.Car.rawValue : self = .CarZone
        case ModelObjectType.Truck.rawValue : self = .TruckZone
        case ModelObjectType.Bus.rawValue : self = .BusZone
        default : return nil
        }
    }
    
    func serverTokenDefaultsKey() -> String {
        return rawValue + "ServerChangeTokenKey"
    }
    
    func recordZoneID() -> CKRecordZoneID {
        return CKRecordZoneID(zoneName: rawValue, ownerName: CKOwnerDefaultName)
    }
    
    func recordType() -> String {
        switch self {
        case .CarZone : return ModelObjectType.Car.rawValue
        case .TruckZone : return ModelObjectType.Truck.rawValue
        case .BusZone : return ModelObjectType.Bus.rawValue
        }
    }
    
    func cloudKitSubscription() -> CKSubscription {
        
        // options must be set to 0 per current documentation
        // https://developer.apple.com/library/ios/documentation/CloudKit/Reference/CKSubscription_class/index.html#//apple_ref/occ/instm/CKSubscription/initWithZoneID:options:
        let subscription = CKSubscription(zoneID: recordZoneID(), options: CKSubscriptionOptions(rawValue: 0))
        subscription.notificationInfo = notificationInfo()
        return subscription
    }
    
    func notificationInfo() -> CKNotificationInfo {
        
        let notificationInfo = CKNotificationInfo()
        notificationInfo.alertBody = "Subscription notification for \(rawValue)"
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        return notificationInfo
    }
    
    static let allCloudKitZoneNames = [
        CloudKitZone.CarZone.rawValue,
        CloudKitZone.TruckZone.rawValue,
        CloudKitZone.BusZone.rawValue
    ]
}

enum CloudKitUserDefaultKeys: String {
    
    case CloudKitEnabledKey = "CloudKitEnabledKey"
    case SuppressCloudKitErrorKey = "SuppressCloudKitErrorKey"
    case LastCloudKitSyncTimestamp = "LastCloudKitSyncTimestamp"
}

enum CloudKitPromptButtonType: String {
    
    case OK = "OK"
    case DontShowAgain = "Don't Show Again"
    
    func performAction() {
        switch self {
        case .OK:
            break
        case .DontShowAgain:
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: CloudKitUserDefaultKeys.SuppressCloudKitErrorKey.rawValue)
        }
    }
    
    func actionStyle() -> UIAlertActionStyle {
        switch self {
        case .DontShowAgain: return .Destructive
        default: return .Default
        }
    }
}