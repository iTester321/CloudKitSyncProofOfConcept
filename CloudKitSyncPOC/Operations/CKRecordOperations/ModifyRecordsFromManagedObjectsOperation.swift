//
//  ModifyRecordsFromManagedObjectsOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/15/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit
import CoreData

class ModifyRecordsFromManagedObjectsOperation: CKModifyRecordsOperation {
    
    var fetchedRecordsToModify: [CKRecordID : CKRecord]?
    var preModifiedRecords: [CKRecord]?
    private let modifiedManagedObjectIDs: [NSManagedObjectID]?
    private let coreDataManager: CoreDataManager
    private let cloudKitManager: CloudKitManager
    
    init(coreDataManager: CoreDataManager, cloudKitManager: CloudKitManager) {
        
        self.coreDataManager = coreDataManager
        self.cloudKitManager = cloudKitManager
        self.modifiedManagedObjectIDs = nil
        self.fetchedRecordsToModify = nil
        self.preModifiedRecords = nil
        super.init()
    }
    
    init(coreDataManager: CoreDataManager, cloudKitManager: CloudKitManager, modifiedManagedObjectIDs: [NSManagedObjectID], deletedRecordIDs: [CKRecordID]) {
        
        // save off the modified objects and the fetch operation
        self.coreDataManager = coreDataManager
        self.cloudKitManager = cloudKitManager
        self.modifiedManagedObjectIDs = modifiedManagedObjectIDs
        self.fetchedRecordsToModify = nil
        
        super.init()
        
        // get the recordIDs for deleted objects
        recordIDsToDelete = deletedRecordIDs
    }
    
    override func main() {
        
        print("ModifyRecordsFromManagedObjectsOperation.main()")
        
        // setup the CKFetchRecordsOperation blocks
        setOperationBlocks()
        
        let managedObjectContext = coreDataManager.createBackgroundManagedContext()
        
        managedObjectContext.performBlockAndWait {
            // before we run we need to map the records we fetched in the dependent operation into our records to save
            let modifiedRecords: [CKRecord]
            if let modifiedManagedObjectIDs = self.modifiedManagedObjectIDs {
                modifiedRecords = self.modifyFetchedRecordsIDs(managedObjectContext, modifiedManagedObjectIDs: modifiedManagedObjectIDs)
            } else if let preModifiedRecords = self.preModifiedRecords {
                modifiedRecords = preModifiedRecords
            }
            else {
                modifiedRecords = []
            }
            
            if modifiedRecords.count > 0 {
                if self.recordsToSave == nil {
                    self.recordsToSave = modifiedRecords
                }
                else {
                    self.recordsToSave?.appendContentsOf(modifiedRecords)
                }
            }
            
            print("ModifyRecordsFromManagedObjectsOperation.recordsToSave: \(self.recordsToSave)")
            print("ModifyRecordsFromManagedObjectsOperation.recordIDsToDelete: \(self.recordIDsToDelete)")
            
            super.main()
        }
    }
    
    private func modifyFetchedRecordsIDs(managedObjectContext: NSManagedObjectContext, modifiedManagedObjectIDs: [NSManagedObjectID]) -> [CKRecord] {
        
        guard let fetchedRecords = fetchedRecordsToModify else {
            return []
        }
        
        var modifiedRecords: [CKRecord] = []
        
        let modifiedManagedObjects = coreDataManager.fetchCloudKitManagedObjects(managedObjectContext, managedObjectIDs: modifiedManagedObjectIDs)
        for cloudKitManagedObject in modifiedManagedObjects {
            if let recordID = cloudKitManagedObject.cloudKitRecordID(),
               let record = fetchedRecords[recordID] {
                modifiedRecords.append(cloudKitManagedObject.managedObjectToRecord(record))
            }
        }
        
        return modifiedRecords
    }

    private func setOperationBlocks() {
        
        perRecordCompletionBlock = {
            (record:CKRecord?, error:NSError?) -> Void in
            
            if let error = error {
                print("ModifyRecordsFromManagedObjectsOperation.perRecordCompletionBlock error: \(error)")
            }
            else {
                print("Record modification successful for recordID: \(record?.recordID)")
            }
        }
        
        modifyRecordsCompletionBlock = {
            [unowned self]
            (savedRecords: [CKRecord]?, deletedRecords: [CKRecordID]?, error:NSError?) -> Void in
            
            if let error = error {
                print("ModifyRecordsFromManagedObjectsOperation.modifyRecordsCompletionBlock error: \(error)")
            }
            else if let deletedRecords = deletedRecords {
                for recordID in deletedRecords {
                    print("DELETED: \(recordID)")
                }
            }
            self.cloudKitManager.lastCloudKitSyncTimestamp = NSDate()
            print("ModifyRecordsFromManagedObjectsOperation modifyRecordsCompletionBlock")
        }
    }
}
