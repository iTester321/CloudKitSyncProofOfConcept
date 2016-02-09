//
//  CoreDataManager.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import CoreData
import CloudKit

typealias networkOperationResult = (success: Bool, errorMessage: String?) -> Void

class CoreDataManager: NSObject {
    
    var mainThreadManagedObjectContext: NSManagedObjectContext
    var cloudKitManager: CloudKitManager?
    private var privateObjectContext: NSManagedObjectContext
    private let coordinator: NSPersistentStoreCoordinator
    
    init(closure:()->()) {
        
        guard let modelURL = NSBundle.mainBundle().URLForResource("CoreDataModel", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel.init(contentsOfURL: modelURL)
            else {
                fatalError("CoreDataManager - COULD NOT INIT MANAGED OBJECT MODEL")
        }
        
        coordinator = NSPersistentStoreCoordinator.init(managedObjectModel: managedObjectModel)
        
        mainThreadManagedObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        privateObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        
        privateObjectContext.persistentStoreCoordinator = coordinator
        mainThreadManagedObjectContext.persistentStoreCoordinator = coordinator
        
        super.init()
        
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
            [unowned self] in
            
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSSQLitePragmasOption: ["journal_mode": "DELETE"]
            ]
            
            let documentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last
            let storeURL = NSURL.init(string: "coredatamodel.sqlite", relativeToURL: documentsURL)
            
            do {
                try self.coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options)
                
                dispatch_async(dispatch_get_main_queue()) {
                    closure()
                }
            }
            catch let error as NSError {
                fatalError("CoreDataManager - COULD NOT INIT SQLITE STORE: \(error.localizedDescription)")
            }
        }
        
        cloudKitManager = CloudKitManager(coreDataManager: self)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mergeContext:", name:NSManagedObjectContextDidSaveNotification , object: nil)
    }
    
    func mergeContext(notification: NSNotification) {
        
        let sender = notification.object as! NSManagedObjectContext
        
        if sender != mainThreadManagedObjectContext {
            mainThreadManagedObjectContext.performBlockAndWait {
                [unowned self] in
                
                print("mainThreadManagedObjectContext.mergeChangesFromContextDidSaveNotification")
                self.mainThreadManagedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
    }
    
    func createBackgroundManagedContext() -> NSManagedObjectContext {
        
        let backgroundManagedObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        backgroundManagedObjectContext.persistentStoreCoordinator = coordinator
        backgroundManagedObjectContext.undoManager = nil
        return backgroundManagedObjectContext
    }
    
    func save() {
        
        let insertedObjects = mainThreadManagedObjectContext.insertedObjects
        let modifiedObjects = mainThreadManagedObjectContext.updatedObjects
        let deletedRecordIDs = mainThreadManagedObjectContext.deletedObjects.flatMap { ($0 as? CloudKitManagedObject)?.cloudKitRecordID() }
        
        if privateObjectContext.hasChanges || mainThreadManagedObjectContext.hasChanges {
            
            self.mainThreadManagedObjectContext.performBlockAndWait {
                [unowned self] in
                
                do {
                    try self.mainThreadManagedObjectContext.save()
                    self.savePrivateObjectContext()
                }
                catch let error as NSError {
                    fatalError("CoreDataManager - SAVE MANAGEDOBJECTCONTEXT FAILED: \(error.localizedDescription)")
                }
                
                let insertedManagedObjectIDs = insertedObjects.flatMap { $0.objectID }
                let modifiedManagedObjectIDs = modifiedObjects.flatMap { $0.objectID }
                
                self.cloudKitManager?.saveChangesToCloudKit(insertedManagedObjectIDs, modifiedManagedObjectIDs: modifiedManagedObjectIDs, deletedRecordIDs: deletedRecordIDs)
            }
        }
    }
    
    func saveBackgroundManagedObjectContext(backgroundManagedObjectContext: NSManagedObjectContext) {
        
        if backgroundManagedObjectContext.hasChanges {
            do {
                try backgroundManagedObjectContext.save()
            }
            catch let error as NSError {
                fatalError("CoreDataManager - save backgroundManagedObjectContext ERROR: \(error.localizedDescription)")
            }
        }
    }
    
    func sync() {
        cloudKitManager?.performFullSync()
    }
    
    internal func savePrivateObjectContext() {
        
        privateObjectContext.performBlockAndWait {
            [unowned self] in
            
            print("savePrivateObjectContext")
            do {
                try self.privateObjectContext.save()
            }
            catch let error as NSError {
                fatalError("CoreDataManager - SAVE PRIVATEOBJECTCONTEXT FAILED: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Fetch CloudKitManagedObjects from Context by NSManagedObjectID
    func fetchCloudKitManagedObjects(managedObjectContext: NSManagedObjectContext, managedObjectIDs: [NSManagedObjectID]) -> [CloudKitManagedObject] {
        
        var cloudKitManagedObjects: [CloudKitManagedObject] = []
        for managedObjectID in managedObjectIDs {
            do {
                let managedObject = try managedObjectContext.existingObjectWithID(managedObjectID)
                
                if let cloudKitManagedObject = managedObject as? CloudKitManagedObject {
                    cloudKitManagedObjects.append(cloudKitManagedObject)
                }
            }
            catch let error as NSError {
                print("Error fetching from CoreData: \(error.localizedDescription)")
            }
        }
        
        return cloudKitManagedObjects
    }
}
