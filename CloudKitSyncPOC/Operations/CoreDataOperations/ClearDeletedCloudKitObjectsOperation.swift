//
//  ClearDeletedCloudKitObjectsOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CoreData

class ClearDeletedCloudKitObjectsOperation: NSOperation {
    
    let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        
        super.init()
    }
    
    override func main() {
        
        print("ClearDeletedCloudKitObjectsOperation.main()")
        
        let managedObjectContext = coreDataManager.createBackgroundManagedContext()
        
        managedObjectContext.performBlockAndWait {
            [unowned self] in
            
            let fetchRequest = NSFetchRequest(entityName: ModelObjectType.DeletedCloudKitObject.rawValue)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try managedObjectContext.executeRequest(deleteRequest)
            }
            catch let error as NSError {
                print("Error deleting from CoreData: \(error.localizedDescription)")
            }
            
            self.coreDataManager.saveBackgroundManagedObjectContext(managedObjectContext)
        }
    }
}
