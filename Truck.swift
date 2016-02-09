//
//  Truck.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class Truck: NSManagedObject, CTBRootManagedObject, CloudKitManagedObject {

    var recordType: String { return  ModelObjectType.Truck.rawValue }
    
    func managedObjectToRecord(record: CKRecord?) -> CKRecord {
        guard let name = name,
            let added = added,
            let lastUpdate = lastUpdate else {
                fatalError("Required properties for record not set")
        }
        let truckRecord = cloudKitRecord(record, parentRecordZoneID: nil)
        
        recordName = truckRecord.recordID.recordName
        recordID = NSKeyedArchiver.archivedDataWithRootObject(truckRecord.recordID)
        
        truckRecord["name"] = name
        truckRecord["added"] = added
        truckRecord["lastUpdate"] = lastUpdate
        
        return truckRecord
    }

    func updateWithRecord(record: CKRecord) {
        name = record["name"] as? String
        added = record["added"] as? NSDate
        lastUpdate = record["lastUpdate"] as? NSDate
        recordName = record.recordID.recordName
        recordID = NSKeyedArchiver.archivedDataWithRootObject(record.recordID)
    }
}
