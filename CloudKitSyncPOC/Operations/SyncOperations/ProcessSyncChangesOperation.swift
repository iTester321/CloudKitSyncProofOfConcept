//
//  ProcessOfflineChangesOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit
import Swift

class ProcessSyncChangesOperation: NSOperation {

    var preProcessLocalChangedObjectIDs: [NSManagedObjectID]
    var preProcessLocalDeletedRecordIDs: [CKRecordID]
    var preProcessServerChangedRecords: [CKRecord]
    var preProcessServerDeletedRecordIDs: [CKRecordID]
    
    var postProcessChangesToCoreData: [CKRecord]
    var postProcessChangesToServer: [CKRecord]
    var postProcessDeletesToCoreData: [CKRecordID]
    var postProcessDeletesToServer: [CKRecordID]
    
    private let coreDataManager: CoreDataManager
    private var changedCloudKitManagedObjects: [CloudKitManagedObject]
    
    init(coreDataManager: CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        
        self.preProcessLocalChangedObjectIDs = []
        self.preProcessLocalDeletedRecordIDs = []
        self.preProcessServerChangedRecords = []
        self.preProcessServerDeletedRecordIDs = []
        
        self.postProcessChangesToCoreData = []
        self.postProcessChangesToServer = []
        self.postProcessDeletesToCoreData = []
        self.postProcessDeletesToServer = []
        
        self.changedCloudKitManagedObjects = []
        
        super.init()
    }
    
    override func main() {
        
        print("ProcessSyncChangesOperation.main()")
        
        let managedObjectContext = coreDataManager.createBackgroundManagedContext()
        
        managedObjectContext.performBlockAndWait() {
            [unowned self] in
            
            print("------------------------------------------")
            print("preProcessLocalChangedObjectIDs: \(self.preProcessLocalChangedObjectIDs.count)")
            print("preProcessLocalDeletedRecordIDs: \(self.preProcessLocalDeletedRecordIDs.count)")
            print("preProcessServerChangedRecords: \(self.preProcessServerChangedRecords.count)")
            print("preProcessServerDeletedRecordIDs: \(self.preProcessServerDeletedRecordIDs.count)")
            print("------------------------------------------")
            
            // first we need CloudKitManagedObjects from NSManagedObjectIDs
            self.changedCloudKitManagedObjects = self.coreDataManager.fetchCloudKitManagedObjects(managedObjectContext, managedObjectIDs: self.preProcessLocalChangedObjectIDs)
            
            // deletes are the first thing we should process
            // anything deleted on the server should be removed from any local changes
            // anything deleted local should be removed from any server changes
            self.processServerDeletions(managedObjectContext)
            self.processLocalDeletions()
            
            // next process the conflicts
            self.processConflicts(managedObjectContext)
            
            // anything left in changedCloudKitManagedObjects needs to be added to postProcessChangesToServer
            let changedLocalRecords = self.changedCloudKitManagedObjects.flatMap { $0.managedObjectToRecord(nil) }
            self.postProcessChangesToServer.appendContentsOf(changedLocalRecords)
            
            // anything left in preProcessServerChangedRecords needs to be added to postProcessChangesToCoreData
            self.postProcessChangesToCoreData.appendContentsOf(self.preProcessServerChangedRecords)
            
            print("postProcessChangesToServer: \(self.postProcessChangesToServer.count)")
            print("postProcessDeletesToServer: \(self.postProcessDeletesToServer.count)")
            print("postProcessChangesToCoreData: \(self.postProcessChangesToCoreData.count)")
            print("postProcessDeletesToCoreData: \(self.postProcessDeletesToCoreData.count)")
            print("------------------------------------------")
            
            self.coreDataManager.saveBackgroundManagedObjectContext(managedObjectContext)
        }
    }
    
    // MARK: Process Deleted Objects
    func processServerDeletions(managedObjectContext: NSManagedObjectContext) {

        // anything deleted on the server needs to be removed from local change objects
        // and then added to the postProcessDeletesToCoreData array
        for deletedServerRecordID in preProcessServerDeletedRecordIDs {
            
            // do we have this record locally? We need to know so we can remove it from the changedCloudKitManagedObjects
            if let index = changedCloudKitManagedObjects.indexOf( { $0.recordName == deletedServerRecordID.recordName } ) {
                changedCloudKitManagedObjects.removeAtIndex(index)
            }
            
            // make sure to add it to the postProcessDeletesToCoreData array so we delete it from core data
            postProcessDeletesToCoreData.append(deletedServerRecordID)
        }
    }
    
    func processLocalDeletions() {
        
        // anything deleted locally needs to be removed from the server change objects
        // and also added to the postProcessDeletesToServer array
        
        for deletedLocalRecordID in preProcessLocalDeletedRecordIDs {
            
            if let index = preProcessServerChangedRecords.indexOf( { $0.recordID.recordName == deletedLocalRecordID.recordName} ) {
                preProcessServerChangedRecords.removeAtIndex(index)
            }
            
            // make sure to add it to the
            postProcessDeletesToServer.append(deletedLocalRecordID)
        }
    }
    
    // MARK: Process Conflicts
    func processConflicts(managedObjectContext: NSManagedObjectContext) {
        
        // make sets of the recordNames for both local and server changes
        let changedLocalRecordNamesArray = changedCloudKitManagedObjects.flatMap { $0.recordName }
        let changedServerRecordNamesArray = preProcessServerChangedRecords.flatMap { $0.recordID.recordName }
        let changedLocalRecordNamesSet = Set(changedLocalRecordNamesArray)
        let changedServerRecordNamesSet = Set(changedServerRecordNamesArray)
        
        // the interset of the sets are the recordNames we need to resolve conflicts with
        let conflictRecordNameSet = changedLocalRecordNamesSet.intersect(changedServerRecordNamesSet)
        
        for recordName in conflictRecordNameSet {
            resolveConflict(recordName, managedObjectContext: managedObjectContext)
        }
    }
    
    func resolveConflict(recordName: String, managedObjectContext: NSManagedObjectContext) {
        
        // only do the comparison if we have both objects. If we don't that's really bad
        guard let serverChangedRecordIndex = preProcessServerChangedRecords.indexOf( { $0.recordID.recordName == recordName } ),
            let localChangedObjectIndex = changedCloudKitManagedObjects.indexOf( { $0.recordName == recordName } ) else {
                fatalError("Could not find either the server record or local managed object to compare in conflict")
        }
        
        // get the objects from their respective arrays
        let serverChangedRecord = preProcessServerChangedRecords[serverChangedRecordIndex]
        let localChangedObject = changedCloudKitManagedObjects[localChangedObjectIndex]
        
        // also would be really bad if either of them don't have a lastUpdate property
        guard let serverChangedRecordLastUpdate = serverChangedRecord["lastUpdate"] as? NSDate,
              let localChangedObjectLastUpdate = localChangedObject.lastUpdate else {
            fatalError("Could not find either the server record or local managed object lastUpdate property to compare in conflict")
        }
    
        // we need to remove the change from their respective preProcess arrays so they don't end up there later in the process
        preProcessServerChangedRecords.removeAtIndex(serverChangedRecordIndex)
        changedCloudKitManagedObjects.removeAtIndex(localChangedObjectIndex)
        
        // finally we check which time stamp is newer
        if serverChangedRecordLastUpdate.compare(localChangedObjectLastUpdate) == NSComparisonResult.OrderedDescending {
            
            // server wins - add the record to those that will go to core data
            print("CONFLICT: \(recordName) - SERVER WINS. UPDATE COREDATA")
            postProcessChangesToCoreData.append(serverChangedRecord)
            
        } else if serverChangedRecordLastUpdate.compare(localChangedObjectLastUpdate) == NSComparisonResult.OrderedAscending {
            
            // local wins - add the NSManagedObjectID to those that will go to the server
            print("CONFLICT: \(recordName) - LOCAL WINS. UPDATE CLOUDKIT")
            postProcessChangesToServer.append(localChangedObject.managedObjectToRecord(serverChangedRecord))
            
        }
        else {
            // they're the same - we can just ignore these changes (curious how they would be the same ever though)
            print("CONFLICT: \(recordName) - SAME!! Will ignore")
        }
    }
}
