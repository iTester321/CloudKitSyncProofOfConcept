//
//  FetchOfflineChangesFromCoreDataOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit

class FetchOfflineChangesFromCoreDataOperation: NSOperation {
    
    var updatedManagedObjects: [NSManagedObjectID]
    var deletedRecordIDs: [CKRecordID]
    
    private let coreDataManager: CoreDataManager
    private let cloudKitManager: CloudKitManager
    private let entityNames: [String]
    
    init(coreDataManager: CoreDataManager, cloudKitManager: CloudKitManager, entityNames: [String]) {
        
        self.coreDataManager = coreDataManager
        self.cloudKitManager = cloudKitManager
        self.entityNames = entityNames
        
        self.updatedManagedObjects = []
        self.deletedRecordIDs = []
        
        super.init()
    }

    override func main() {
        
        print("FetchOfflineChangesFromCoreDataOperation.main()")
        
        let managedObjectContext = coreDataManager.createBackgroundManagedContext()
        
        managedObjectContext.performBlockAndWait {
            [unowned self] in
            
            let lastCloudKitSyncTimestamp = self.cloudKitManager.lastCloudKitSyncTimestamp
            
            for entityName in self.entityNames {
                self.fetchOfflineChangesForEntityName(entityName, lastCloudKitSyncTimestamp: lastCloudKitSyncTimestamp, managedObjectContext: managedObjectContext)
            }
            
            self.deletedRecordIDs = self.fetchDeletedRecordIDs(managedObjectContext)
        }
    }
    
    func fetchOfflineChangesForEntityName(entityName: String, lastCloudKitSyncTimestamp: NSDate, managedObjectContext: NSManagedObjectContext) {
        
        let fetchRequest = NSFetchRequest(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "lastUpdate > %@", lastCloudKitSyncTimestamp)
        
        do {
            let fetchResults = try managedObjectContext.executeFetchRequest(fetchRequest)
            let managedObjectIDs = fetchResults.flatMap() { ($0 as? NSManagedObject)?.objectID  }
            
            updatedManagedObjects.appendContentsOf(managedObjectIDs)
        }
        catch let error as NSError {
            print("Error fetching from CoreData: \(error.localizedDescription)")
        }
    }
    
    func fetchDeletedRecordIDs(managedObjectContext: NSManagedObjectContext) -> [CKRecordID] {
        
        let fetchRequest = NSFetchRequest(entityName: ModelObjectType.DeletedCloudKitObject.rawValue)
        
        do {
            let fetchResults = try managedObjectContext.executeFetchRequest(fetchRequest)
            return fetchResults.flatMap() { ($0 as? DeletedCloudKitObject)?.cloudKitRecordID()  }
        }
        catch let error as NSError {
            print("Error fetching from CoreData: \(error.localizedDescription)")
        }
        
        return []
    }
}
