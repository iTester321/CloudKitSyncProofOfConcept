//
//  FetchRecordChangesForCloudKitZoneOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/17/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit
import CoreData

class FetchRecordChangesForCloudKitZoneOperation: CKFetchRecordChangesOperation {
    
    var changedRecords: [CKRecord]
    var deletedRecordIDs: [CKRecordID]
    var operationError: NSError?
    private let cloudKitZone: CloudKitZone
    
    init(cloudKitZone: CloudKitZone) {
        
        self.cloudKitZone = cloudKitZone
        
        self.changedRecords = []
        self.deletedRecordIDs = []
        
        super.init()
        self.recordZoneID = cloudKitZone.recordZoneID()
        self.previousServerChangeToken = getServerChangeToken(cloudKitZone)
    }
    
    override func main() {
        
        print("FetchCKRecordChangesForCloudKitZoneOperation.main() - \(previousServerChangeToken)")
        
        setOperationBlocks()
        super.main()
    }
    
    // MARK: Set operation blocks
    func setOperationBlocks() {
        
        recordChangedBlock = {
            [unowned self]
            (record: CKRecord) -> Void in
            
            print("Record changed: \(record)")
            self.changedRecords.append(record)
        }
        
        recordWithIDWasDeletedBlock = {
            [unowned self]
            (recordID: CKRecordID) -> Void in
            
            print("Record deleted: \(recordID)")
            self.deletedRecordIDs.append(recordID)
        }
        
        fetchRecordChangesCompletionBlock = {
            [unowned self]
            (serverChangeToken: CKServerChangeToken?, clientChangeToken: NSData?, error: NSError?) -> Void in
            
            if let operationError = error {
                print("SyncRecordChangesToCoreDataOperation resulted in an error: \(error)")
                self.operationError = operationError
            }
            else {
                self.setServerChangeToken(self.cloudKitZone, serverChangeToken: serverChangeToken)
            }
        }
    }

    // MARK: Change token user default methods
    func getServerChangeToken(cloudKitZone: CloudKitZone) -> CKServerChangeToken? {
        
        let encodedObjectData = NSUserDefaults.standardUserDefaults().objectForKey(cloudKitZone.serverTokenDefaultsKey()) as? NSData
        
        if let encodedObjectData = encodedObjectData {
            return NSKeyedUnarchiver.unarchiveObjectWithData(encodedObjectData) as? CKServerChangeToken
        }
        else {
            return nil
        }
    }
    
    func setServerChangeToken(cloudKitZone: CloudKitZone, serverChangeToken: CKServerChangeToken?) {
        
        if let serverChangeToken = serverChangeToken {
            NSUserDefaults.standardUserDefaults().setObject(NSKeyedArchiver.archivedDataWithRootObject(serverChangeToken), forKey:cloudKitZone.serverTokenDefaultsKey())
        }
        else {
            NSUserDefaults.standardUserDefaults().setObject(nil, forKey:cloudKitZone.serverTokenDefaultsKey())
        }
    }
}
