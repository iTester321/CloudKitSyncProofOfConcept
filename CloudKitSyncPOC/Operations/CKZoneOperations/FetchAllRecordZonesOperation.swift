//
//  FetchAllRecordZonesOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/18/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit

class FetchAllRecordZonesOperation: CKFetchRecordZonesOperation {

    var fetchedRecordZones: [CKRecordZoneID : CKRecordZone]?
    
    override init() {
        
        self.fetchedRecordZones = nil
        
        super.init()
    }
    
    override func main() {
        
        print("FetchAllRecordZonesOperation.main()")
        
        setOperationBlocks()
        super.main()
    }
    
    func setOperationBlocks() {
        
        fetchRecordZonesCompletionBlock = {
            [unowned self]
            (recordZones: [CKRecordZoneID : CKRecordZone]?, error: NSError?) -> Void in
            
            print("FetchAllRecordZonesOperation.fetchRecordZonesCompletionBlock")
            
            if let error = error {
                print("FetchAllRecordZonesOperation error: \(error)")
            }
            
            if let recordZones = recordZones {
                
                self.fetchedRecordZones = recordZones
                for recordID in recordZones.keys {
                    print(recordID)
                }
            }
        }
    }
}
