//
//  CloudKitManager.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/16/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//


import Foundation
import UIKit
import CoreData
import CloudKit

class CloudKitManager {
    
    // MARK: Class Properties
    private let privateDB: CKDatabase
    private let coreDataManager: CoreDataManager
    private let operationQueue: NSOperationQueue
    
    // MARK: init
    init(coreDataManager: CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        self.operationQueue = NSOperationQueue()
        self.operationQueue.maxConcurrentOperationCount = 1
        
        privateDB = CKContainer.defaultContainer().privateCloudDatabase
        CKContainer.defaultContainer().accountStatusWithCompletionHandler() {
            [unowned self]
            (accountStatus:CKAccountStatus, error:NSError?) -> Void in
            
            switch accountStatus {
            case .Available:
                self.initializeCloudKit()
            default:
                self.handleCloudKitUnavailable(accountStatus, error: error)
            }
        }
    }
    
    // MARK: Public Functions
    func saveChangesToCloudKit(insertedObjects: [NSManagedObjectID], modifiedManagedObjectIDs: [NSManagedObjectID], deletedRecordIDs: [CKRecordID]) {

        // create the operations
        let createRecordsForNewObjectsOperation = CreateRecordsForNewObjectsOperation(insertedManagedObjectIDs: insertedObjects, coreDataManager: coreDataManager)
        let fetchModifiedRecordsOperation = FetchRecordsForModifiedObjectsOperation(coreDataManager: coreDataManager, modifiedManagedObjectIDs: modifiedManagedObjectIDs)
        let modifyRecordsOperation = ModifyRecordsFromManagedObjectsOperation(coreDataManager: coreDataManager, cloudKitManager: self, modifiedManagedObjectIDs: modifiedManagedObjectIDs, deletedRecordIDs: deletedRecordIDs)
        let clearDeletedCloudKitObjectsOperation = ClearDeletedCloudKitObjectsOperation(coreDataManager: coreDataManager)
        
        let transferCreatedRecordsOperation = NSBlockOperation() {
            [unowned modifyRecordsOperation, unowned createRecordsForNewObjectsOperation] in
            
            modifyRecordsOperation.recordsToSave = createRecordsForNewObjectsOperation.createdRecords
        }
        
        let transferFetchedRecordsOperation = NSBlockOperation() {
            [unowned modifyRecordsOperation, unowned fetchModifiedRecordsOperation] in
            
            modifyRecordsOperation.fetchedRecordsToModify = fetchModifiedRecordsOperation.fetchedRecords
        }
        
        // setup dependencies
        transferCreatedRecordsOperation.addDependency(createRecordsForNewObjectsOperation)
        transferFetchedRecordsOperation.addDependency(fetchModifiedRecordsOperation)
        modifyRecordsOperation.addDependency(transferCreatedRecordsOperation)
        modifyRecordsOperation.addDependency(transferFetchedRecordsOperation)
        clearDeletedCloudKitObjectsOperation.addDependency(modifyRecordsOperation)
        
        // add the operations to the queue
        operationQueue.addOperation(createRecordsForNewObjectsOperation)
        operationQueue.addOperation(transferCreatedRecordsOperation)
        operationQueue.addOperation(fetchModifiedRecordsOperation)
        operationQueue.addOperation(transferFetchedRecordsOperation)
        operationQueue.addOperation(modifyRecordsOperation)
        operationQueue.addOperation(clearDeletedCloudKitObjectsOperation)
    }
    
    func performFullSync() {
        
        queueFullSyncOperations()
    }
    
    func syncZone(zoneName: String, completionBlockOperation: NSBlockOperation) {
        
        if let cloudKitZone = CloudKitZone(rawValue: zoneName) {
            
            // suspend the queue so nothing finishes before all our dependencies are setup
            operationQueue.suspended = true
            
            // queue up the change operations for a zone
            let saveChangedRecordsToCoreDataOperation = queueChangeOperationsForZone(cloudKitZone, modifyRecordZonesOperation: nil)
            
            // add our completion block to the queue as well to handle background fetches
            completionBlockOperation.addDependency(saveChangedRecordsToCoreDataOperation)
            operationQueue.addOperation(completionBlockOperation)
            
            // let the queue begin firing again
            operationQueue.suspended = false
        }
    }
    
    // MARK: CloudKit Unavailable Functions
    private func handleCloudKitUnavailable(accountStatus: CKAccountStatus, error:NSError?) {
        
        cloudKitEnabled = false
        
        var errorText = "Synchronization is disabled\n"
        if let error = error {
            print("handleCloudKitUnavailable ERROR: \(error)")
            print("An error occured: \(error.localizedDescription)")
            errorText += error.localizedDescription
        }
        
        switch accountStatus {
        case .Restricted:
            errorText += "iCloud is not available due to restrictions"
        case .NoAccount:
            errorText += "There is no CloudKit account setup.\nYou can setup iCloud in the Settings app."
        default:
            break
        }
        
        displayCloudKitNotAvailableError(errorText)
    }
    
    private func displayCloudKitNotAvailableError(errorText: String) {
        
        if !suppressCloudKitEnabledError {
            dispatch_async(dispatch_get_main_queue(),{
                
                let alertController = UIAlertController(title: "iCloud Synchronization Error", message: errorText, preferredStyle: UIAlertControllerStyle.Alert)
                
                let firstButton = CloudKitPromptButtonType.OK
                let firstButtonAction = UIAlertAction(title: firstButton.rawValue, style: firstButton.actionStyle(), handler: {
                    (action: UIAlertAction) -> Void in
                    
                    firstButton.performAction()
                });
                alertController.addAction(firstButtonAction)
                
                let secondButton = CloudKitPromptButtonType.DontShowAgain
                let secondButtonAction = UIAlertAction(title: secondButton.rawValue, style: secondButton.actionStyle(), handler: {
                    (action: UIAlertAction) -> Void in
                    
                    secondButton.performAction()
                });
                alertController.addAction(secondButtonAction)
                
                if let appDelegate = UIApplication.sharedApplication().delegate,
                    let appWindow = appDelegate.window!, // yes the UIWindow really is window?? - http://stackoverflow.com/questions/28901893/why-is-main-window-of-type-double-optional
                    let rootViewController = appWindow.rootViewController {
                        rootViewController.presentViewController(alertController, animated: true, completion: nil)
                }
            })
        }
    }
    
    // MARK: CloudKit Init Functions
    private func initializeCloudKit() {
        
        print("CloudKit IS available")
        cloudKitEnabled = true
        
        // suspend the operation queue until all operations are created and enqueued
        operationQueue.suspended = true
        
//        self.deleteRecordZone()
        
        let modifyRecordZonesOperation = queueZoneInitilizationOperations()
        let modifySubscriptionsOperation = queueSubscriptionInitilizationOperations()
        
        // set the dependencies between zones and subscriptions (we need the zones to exist before any subscriptions can be created)
        modifySubscriptionsOperation.addDependency(modifyRecordZonesOperation)
        
        let syncAllZonesOperation = NSBlockOperation {
            [unowned self] in
            self.queueFullSyncOperations()
        }
        
        syncAllZonesOperation.addDependency(modifyRecordZonesOperation)
        operationQueue.addOperation(syncAllZonesOperation)
        
        // all init operations are ready, start the queue
        operationQueue.suspended = false
    }
    
    private func queueFullSyncOperations() {
        
        // 1. Fetch all the changes both locally and from each zone
        let fetchOfflineChangesFromCoreDataOperation = FetchOfflineChangesFromCoreDataOperation(coreDataManager: coreDataManager, cloudKitManager: self, entityNames: ModelObjectType.allCloudKitModelObjectTypes)
        let fetchCarZoneChangesOperation = FetchRecordChangesForCloudKitZoneOperation(cloudKitZone: CloudKitZone.CarZone)
        let fetchTruckZoneChangesOperation = FetchRecordChangesForCloudKitZoneOperation(cloudKitZone: CloudKitZone.TruckZone)
        let fetchBusZoneChangesOperation = FetchRecordChangesForCloudKitZoneOperation(cloudKitZone: CloudKitZone.BusZone)
        
        // 2. Process the changes after transfering
        let processSyncChangesOperation = ProcessSyncChangesOperation(coreDataManager: coreDataManager)
        let transferDataToProcessSyncChangesOperation = NSBlockOperation {
            [unowned processSyncChangesOperation, unowned fetchOfflineChangesFromCoreDataOperation, unowned fetchCarZoneChangesOperation, unowned fetchTruckZoneChangesOperation, unowned fetchBusZoneChangesOperation] in
            
            processSyncChangesOperation.preProcessLocalChangedObjectIDs.appendContentsOf(fetchOfflineChangesFromCoreDataOperation.updatedManagedObjects)
            processSyncChangesOperation.preProcessLocalDeletedRecordIDs.appendContentsOf(fetchOfflineChangesFromCoreDataOperation.deletedRecordIDs)
            
            processSyncChangesOperation.preProcessServerChangedRecords.appendContentsOf(fetchCarZoneChangesOperation.changedRecords)
            processSyncChangesOperation.preProcessServerChangedRecords.appendContentsOf(fetchTruckZoneChangesOperation.changedRecords)
            processSyncChangesOperation.preProcessServerChangedRecords.appendContentsOf(fetchBusZoneChangesOperation.changedRecords)
            
            processSyncChangesOperation.preProcessServerDeletedRecordIDs.appendContentsOf(fetchCarZoneChangesOperation.deletedRecordIDs)
            processSyncChangesOperation.preProcessServerDeletedRecordIDs.appendContentsOf(fetchTruckZoneChangesOperation.deletedRecordIDs)
            processSyncChangesOperation.preProcessServerDeletedRecordIDs.appendContentsOf(fetchBusZoneChangesOperation.deletedRecordIDs)
        }
        
        // 3. Fetch records from the server that we need to change
        let fetchRecordsForModifiedObjectsOperation = FetchRecordsForModifiedObjectsOperation(coreDataManager: coreDataManager)
        let transferDataToFetchRecordsOperation = NSBlockOperation {
            [unowned fetchRecordsForModifiedObjectsOperation, unowned processSyncChangesOperation] in
            
            fetchRecordsForModifiedObjectsOperation.preFetchModifiedRecords = processSyncChangesOperation.postProcessChangesToServer
        }
        
        // 4. Modify records in the cloud
        let modifyRecordsFromManagedObjectsOperation = ModifyRecordsFromManagedObjectsOperation(coreDataManager: coreDataManager, cloudKitManager: self)
        let transferDataToModifyRecordsOperation = NSBlockOperation {
            [unowned fetchRecordsForModifiedObjectsOperation, unowned modifyRecordsFromManagedObjectsOperation, unowned processSyncChangesOperation] in
            
            if let fetchedRecordsDictionary = fetchRecordsForModifiedObjectsOperation.fetchedRecords {
                modifyRecordsFromManagedObjectsOperation.fetchedRecordsToModify = fetchedRecordsDictionary
            }
            modifyRecordsFromManagedObjectsOperation.preModifiedRecords = processSyncChangesOperation.postProcessChangesToServer
            
            // also set the recordIDsToDelete from what we processed
            modifyRecordsFromManagedObjectsOperation.recordIDsToDelete = processSyncChangesOperation.postProcessDeletesToServer
        }
        
        // 5. Modify records locally
        let saveChangedRecordsToCoreDataOperation = SaveChangedRecordsToCoreDataOperation(coreDataManager: coreDataManager)
        let transferDataToSaveChangesToCoreDataOperation = NSBlockOperation {
            [unowned saveChangedRecordsToCoreDataOperation, unowned processSyncChangesOperation] in
            
            saveChangedRecordsToCoreDataOperation.changedRecords = processSyncChangesOperation.postProcessChangesToCoreData
            saveChangedRecordsToCoreDataOperation.deletedRecordIDs = processSyncChangesOperation.postProcessDeletesToCoreData
        }
        
        // 6. Delete all of the DeletedCloudKitObjects
        let clearDeletedCloudKitObjectsOperation = ClearDeletedCloudKitObjectsOperation(coreDataManager: coreDataManager)
        
        // set dependencies
        // 1. transfering all the fetched data to process for conflicts
        transferDataToProcessSyncChangesOperation.addDependency(fetchOfflineChangesFromCoreDataOperation)
        transferDataToProcessSyncChangesOperation.addDependency(fetchCarZoneChangesOperation)
        transferDataToProcessSyncChangesOperation.addDependency(fetchTruckZoneChangesOperation)
        transferDataToProcessSyncChangesOperation.addDependency(fetchBusZoneChangesOperation)
        
        // 2. processing the data onces its transferred
        processSyncChangesOperation.addDependency(transferDataToProcessSyncChangesOperation)
        
        // 3. fetching records changed local
        transferDataToFetchRecordsOperation.addDependency(processSyncChangesOperation)
        fetchRecordsForModifiedObjectsOperation.addDependency(transferDataToFetchRecordsOperation)
        
        // 4. modifying records in CloudKit
        transferDataToModifyRecordsOperation.addDependency(fetchRecordsForModifiedObjectsOperation)
        modifyRecordsFromManagedObjectsOperation.addDependency(transferDataToModifyRecordsOperation)
        
        // 5. modifying records in CoreData
        transferDataToSaveChangesToCoreDataOperation.addDependency(processSyncChangesOperation)
        saveChangedRecordsToCoreDataOperation.addDependency(transferDataToModifyRecordsOperation)
        
        // 6. clear the deleteCloudKitObjects
        clearDeletedCloudKitObjectsOperation.addDependency(saveChangedRecordsToCoreDataOperation)
        
        // add operations to the queue
        operationQueue.addOperation(fetchOfflineChangesFromCoreDataOperation)
        operationQueue.addOperation(fetchCarZoneChangesOperation)
        operationQueue.addOperation(fetchTruckZoneChangesOperation)
        operationQueue.addOperation(fetchBusZoneChangesOperation)
        operationQueue.addOperation(transferDataToProcessSyncChangesOperation)
        operationQueue.addOperation(processSyncChangesOperation)
        operationQueue.addOperation(transferDataToFetchRecordsOperation)
        operationQueue.addOperation(fetchRecordsForModifiedObjectsOperation)
        operationQueue.addOperation(transferDataToModifyRecordsOperation)
        operationQueue.addOperation(modifyRecordsFromManagedObjectsOperation)
        operationQueue.addOperation(transferDataToSaveChangesToCoreDataOperation)
        operationQueue.addOperation(saveChangedRecordsToCoreDataOperation)
        operationQueue.addOperation(clearDeletedCloudKitObjectsOperation)
    }
    
    // MARK: RecordZone Functions
    private func queueZoneInitilizationOperations() -> CKModifyRecordZonesOperation {
        
        // 1. Fetch all the zones
        // 2. Process the returned zones and create arrays for zones that need creating and those that need deleting
        // 3. Modify the zones in cloudkit
        
        let fetchAllRecordZonesOperation = FetchAllRecordZonesOperation.fetchAllRecordZonesOperation()
        let processServerRecordZonesOperation = ProcessServerRecordZonesOperation()
        let modifyRecordZonesOperation = createModifyRecordZoneOperation(nil, recordZoneIDsToDelete: nil)
        
        let transferFetchedZonesOperation = NSBlockOperation() {
            [unowned fetchAllRecordZonesOperation, unowned processServerRecordZonesOperation] in
            
            if let fetchedRecordZones = fetchAllRecordZonesOperation.fetchedRecordZones {
                processServerRecordZonesOperation.preProcessRecordZoneIDs = Array(fetchedRecordZones.keys)
            }
        }
        
        let transferProcessedZonesOperation = NSBlockOperation() {
            [unowned modifyRecordZonesOperation, unowned processServerRecordZonesOperation] in
            
            modifyRecordZonesOperation.recordZonesToSave = processServerRecordZonesOperation.postProcessRecordZonesToCreate
            modifyRecordZonesOperation.recordZoneIDsToDelete = processServerRecordZonesOperation.postProcessRecordZoneIDsToDelete
        }
        
        transferFetchedZonesOperation.addDependency(fetchAllRecordZonesOperation)
        processServerRecordZonesOperation.addDependency(transferFetchedZonesOperation)
        transferProcessedZonesOperation.addDependency(processServerRecordZonesOperation)
        modifyRecordZonesOperation.addDependency(transferProcessedZonesOperation)
        
        operationQueue.addOperation(fetchAllRecordZonesOperation)
        operationQueue.addOperation(transferFetchedZonesOperation)
        operationQueue.addOperation(processServerRecordZonesOperation)
        operationQueue.addOperation(transferProcessedZonesOperation)
        operationQueue.addOperation(modifyRecordZonesOperation)
        
        return modifyRecordZonesOperation
    }
    
    private func deleteRecordZone() {
        
        let fetchAllRecordZonesOperation = FetchAllRecordZonesOperation.fetchAllRecordZonesOperation()
        let modifyRecordZonesOperation = createModifyRecordZoneOperation(nil, recordZoneIDsToDelete: nil)
        
        let dataTransferOperation = NSBlockOperation() {
            [unowned modifyRecordZonesOperation, unowned fetchAllRecordZonesOperation] in
            
            if let fetchedRecordZones = fetchAllRecordZonesOperation.fetchedRecordZones {
                modifyRecordZonesOperation.recordZoneIDsToDelete = Array(fetchedRecordZones.keys)
            }
        }
        
        dataTransferOperation.addDependency(fetchAllRecordZonesOperation)
        modifyRecordZonesOperation.addDependency(dataTransferOperation)
        
        operationQueue.addOperation(fetchAllRecordZonesOperation)
        operationQueue.addOperation(dataTransferOperation)
        operationQueue.addOperation(modifyRecordZonesOperation)
    }
    
    // MARK: Subscription Functions
    private func queueSubscriptionInitilizationOperations() -> CKModifySubscriptionsOperation {
        
        // 1. Fetch all subscriptions
        // 2. Process which need to be created and which need to be deleted
        // 3. Make the adjustments in iCloud
        
        let fetchAllSubscriptionsOperation = FetchAllSubscriptionsOperation.fetchAllSubscriptionsOperation()
        let processServerSubscriptionsOperation = ProcessServerSubscriptionsOperation()
        let modifySubscriptionsOperation = createModifySubscriptionOperation()
        
        let transferFetchedSubscriptionsOperation = NSBlockOperation() {
            [unowned processServerSubscriptionsOperation, unowned fetchAllSubscriptionsOperation] in
            
            processServerSubscriptionsOperation.preProcessFetchedSubscriptions = fetchAllSubscriptionsOperation.fetchedSubscriptions
        }
        
        let transferProcessedSubscriptionsOperation = NSBlockOperation() {
            [unowned modifySubscriptionsOperation, unowned processServerSubscriptionsOperation] in
            
            modifySubscriptionsOperation.subscriptionsToSave = processServerSubscriptionsOperation.postProcessSubscriptionsToCreate
            modifySubscriptionsOperation.subscriptionIDsToDelete = processServerSubscriptionsOperation.postProcessSubscriptionIDsToDelete
        }
        
        transferFetchedSubscriptionsOperation.addDependency(fetchAllSubscriptionsOperation)
        processServerSubscriptionsOperation.addDependency(transferFetchedSubscriptionsOperation)
        transferProcessedSubscriptionsOperation.addDependency(processServerSubscriptionsOperation)
        modifySubscriptionsOperation.addDependency(transferProcessedSubscriptionsOperation)
        
        operationQueue.addOperation(fetchAllSubscriptionsOperation)
        operationQueue.addOperation(transferFetchedSubscriptionsOperation)
        operationQueue.addOperation(processServerSubscriptionsOperation)
        operationQueue.addOperation(transferProcessedSubscriptionsOperation)
        operationQueue.addOperation(modifySubscriptionsOperation)
        
        return modifySubscriptionsOperation
    }
    
    // MARK: Sync Records
    private func queueChangeOperationsForZone(cloudKitZone: CloudKitZone, modifyRecordZonesOperation: CKModifyRecordZonesOperation?) -> SaveChangedRecordsToCoreDataOperation {
        
        // there are two operations that need to be chained together for each zone
        // the first is to fetch record changes
        // the second is to save those changes to CoreData
        // we'll also need a block operation to transfer data between them
        let fetchRecordChangesOperation = FetchRecordChangesForCloudKitZoneOperation(cloudKitZone: cloudKitZone)
        let saveChangedRecordsToCoreDataOperation = SaveChangedRecordsToCoreDataOperation(coreDataManager: coreDataManager)
        
        let dataTransferOperation = NSBlockOperation() {
            [unowned saveChangedRecordsToCoreDataOperation, unowned fetchRecordChangesOperation] in
            
            print("addChangeOperationsForZone.dataTransferOperation")
            saveChangedRecordsToCoreDataOperation.changedRecords = fetchRecordChangesOperation.changedRecords
            saveChangedRecordsToCoreDataOperation.deletedRecordIDs = fetchRecordChangesOperation.deletedRecordIDs
        }
        
        // set the dependencies
        if let modifyRecordZonesOperation = modifyRecordZonesOperation {
            fetchRecordChangesOperation.addDependency(modifyRecordZonesOperation)
        }
        dataTransferOperation.addDependency(fetchRecordChangesOperation)
        saveChangedRecordsToCoreDataOperation.addDependency(dataTransferOperation)
        
        // add the operations to the queue
        operationQueue.addOperation(fetchRecordChangesOperation)
        operationQueue.addOperation(dataTransferOperation)
        operationQueue.addOperation(saveChangedRecordsToCoreDataOperation)
        
        return saveChangedRecordsToCoreDataOperation
    }
    
    // MARK: Create Operation Helper Functions
    private func createModifyRecordZoneOperation(recordZonesToSave: [CKRecordZone]?, recordZoneIDsToDelete: [CKRecordZoneID]?) -> CKModifyRecordZonesOperation {
        
        let modifyRecordZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: recordZonesToSave, recordZoneIDsToDelete: recordZoneIDsToDelete)
        modifyRecordZonesOperation.modifyRecordZonesCompletionBlock = {
            (modifiedRecordZones: [CKRecordZone]?, deletedRecordZoneIDs: [CKRecordZoneID]?, error: NSError?) -> Void in
            
            print("--- CKModifyRecordZonesOperation.modifyRecordZonesOperation")
            
            if let error = error {
                print("createModifyRecordZoneOperation ERROR: \(error)")
                return
            }
            
            if let modifiedRecordZones = modifiedRecordZones {
                for recordZone in modifiedRecordZones {
                    print("Modified recordZone: \(recordZone)")
                }
            }
            
            if let deletedRecordZoneIDs = deletedRecordZoneIDs {
                for zoneID in deletedRecordZoneIDs {
                    print("Deleted zoneID: \(zoneID)")
                }
            }
        }
        
        return modifyRecordZonesOperation
    }
    
    private func createModifySubscriptionOperation() -> CKModifySubscriptionsOperation {
        
        let modifySubscriptionsOperation = CKModifySubscriptionsOperation()
        modifySubscriptionsOperation.modifySubscriptionsCompletionBlock = {
            (modifiedSubscriptions: [CKSubscription]?, deletedSubscriptionIDs: [String]?, error: NSError?) -> Void in
            
            print("--- CKModifySubscriptionsOperation.modifySubscriptionsCompletionBlock")
            
            if let error = error {
                print("createModifySubscriptionOperation ERROR: \(error)")
                return
            }
            
            if let modifiedSubscriptions = modifiedSubscriptions {
                for subscription in modifiedSubscriptions {
                    print("Modified subscription: \(subscription)")
                }
            }
            
            if let deletedSubscriptionIDs = deletedSubscriptionIDs {
                for subscriptionID in deletedSubscriptionIDs {
                    print("Deleted subscriptionID: \(subscriptionID)")
                }
            }
        }
        
        return modifySubscriptionsOperation
    }
    
    // MARK: NSUserDefault Properties
    var lastCloudKitSyncTimestamp: NSDate {
        
        get {
            if let lastCloudKitSyncTimestamp = NSUserDefaults.standardUserDefaults().objectForKey(CloudKitUserDefaultKeys.LastCloudKitSyncTimestamp.rawValue) as? NSDate {
                return lastCloudKitSyncTimestamp
            }
            else {
                return NSDate.distantPast()
            }
        }
        set {
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: CloudKitUserDefaultKeys.LastCloudKitSyncTimestamp.rawValue)
        }
    }
    
    private var cloudKitEnabled: Bool {
        
        get {
            return NSUserDefaults.standardUserDefaults().boolForKey(CloudKitUserDefaultKeys.CloudKitEnabledKey.rawValue)
        }
        set {
            NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: CloudKitUserDefaultKeys.CloudKitEnabledKey.rawValue)
        }
    }
    
    private var suppressCloudKitEnabledError: Bool {
        
        get {
            return NSUserDefaults.standardUserDefaults().boolForKey(CloudKitUserDefaultKeys.SuppressCloudKitErrorKey.rawValue)
        }
    }
}
