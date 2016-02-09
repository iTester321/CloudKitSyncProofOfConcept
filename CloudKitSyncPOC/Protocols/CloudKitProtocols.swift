//
//  CloudKitProtocols.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/12/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

@objc protocol CloudKitRecordIDObject {
    var recordID: NSData? { get set }
}

extension CloudKitRecordIDObject {
    func cloudKitRecordID() -> CKRecordID? {
        guard let recordID = recordID else {
            return nil
        }
        
        return NSKeyedUnarchiver.unarchiveObjectWithData(recordID) as? CKRecordID
    }
}

@objc protocol CloudKitManagedObject: CloudKitRecordIDObject {
    var lastUpdate: NSDate? { get set }
    var recordName: String? { get set }
    var recordType: String { get }
    func managedObjectToRecord(record: CKRecord?) -> CKRecord
    func updateWithRecord(record: CKRecord)
}

extension CloudKitManagedObject {
    func cloudKitRecord(record: CKRecord?, parentRecordZoneID: CKRecordZoneID?) -> CKRecord {
        
        if let record = record {
            return record
        }

        var recordZoneID: CKRecordZoneID
        if parentRecordZoneID != .None {
            recordZoneID = parentRecordZoneID!
        }
        else {
            guard let cloudKitZone = CloudKitZone(recordType: recordType) else {
                fatalError("Attempted to create a CKRecord with an unknown zone")
            }
            
            recordZoneID = cloudKitZone.recordZoneID()
        }
        
        let uuid = NSUUID()
        let recordName = recordType + "." + uuid.UUIDString
        let recordID = CKRecordID(recordName: recordName, zoneID: recordZoneID)
        
        return CKRecord(recordType: recordType, recordID: recordID)
    }
    
    func addDeletedCloudKitObject() {
        
        if let managedObject = self as? NSManagedObject,
            let managedObjectContext = managedObject.managedObjectContext,
            let recordID = recordID,
            let deletedCloudKitObject = NSEntityDescription.insertNewObjectForEntityForName("DeletedCloudKitObject", inManagedObjectContext: managedObjectContext) as? DeletedCloudKitObject {
                deletedCloudKitObject.recordID = recordID
                deletedCloudKitObject.recordType = recordType
        }
    }
}