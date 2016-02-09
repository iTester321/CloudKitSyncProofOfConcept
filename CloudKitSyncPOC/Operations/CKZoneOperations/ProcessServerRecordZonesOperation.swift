//
//  ProcessServerRecordZonesOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/18/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit

class ProcessServerRecordZonesOperation: NSOperation {

    var preProcessRecordZoneIDs: [CKRecordZoneID]
    var postProcessRecordZonesToCreate: [CKRecordZone]?
    var postProcessRecordZoneIDsToDelete: [CKRecordZoneID]?
    
    override init() {
        
        preProcessRecordZoneIDs = []
        postProcessRecordZonesToCreate = nil
        postProcessRecordZoneIDsToDelete = nil
    }
    
    override func main() {
        
        print("ProcessServerRecordZonesOperation.main()")
        
        setZonesToCreate()
        setZonesToDelete()
    }
    
    private func setZonesToCreate() {
        
        let serverZoneNamesSet = Set(preProcessRecordZoneIDs.map { $0.zoneName })
        let expectedZoneNamesSet = Set(CloudKitZone.allCloudKitZoneNames)
        let missingZoneNamesSet = expectedZoneNamesSet.subtract(serverZoneNamesSet)
        
        if missingZoneNamesSet.count > 0 {
            postProcessRecordZonesToCreate = []
            for missingZoneName in missingZoneNamesSet {
                if let missingCloudKitZone = CloudKitZone(rawValue: missingZoneName) {
                    let missingRecordZone = CKRecordZone(zoneID: missingCloudKitZone.recordZoneID())
                    postProcessRecordZonesToCreate?.append(missingRecordZone)
                }
            }
        }
    }
    
    private func setZonesToDelete() {
        
        // its important to not inadvertently delete the default zone
        for recordZoneID in preProcessRecordZoneIDs {
            if (recordZoneID.zoneName != CKRecordZoneDefaultName) &&
                (CloudKitZone(rawValue: recordZoneID.zoneName) == nil) {
                if postProcessRecordZoneIDsToDelete == nil {
                    postProcessRecordZoneIDsToDelete = []
                }
                postProcessRecordZoneIDsToDelete?.append(recordZoneID)
            }
        }
    }
}
