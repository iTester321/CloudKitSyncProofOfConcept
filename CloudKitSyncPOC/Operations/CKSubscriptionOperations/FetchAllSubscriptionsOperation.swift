//
//  FetchAllSubscriptionsOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/18/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit

class FetchAllSubscriptionsOperation: CKFetchSubscriptionsOperation {
    
    var fetchedSubscriptions: [String : CKSubscription]
    
    override init() {
        
        fetchedSubscriptions = [:]
        super.init()
    }
    
    override func main() {
        
        print("FetchAllSubscriptionsOperation.main()")
        
        setOperationBlocks()
        super.main()
    }
    
    func setOperationBlocks() {
        
        fetchSubscriptionCompletionBlock = {
            [unowned self] 
            (subscriptions: [String : CKSubscription]?, error: NSError?) -> Void in
            
            print("FetchAllSubscriptionsOperation.fetchRecordZonesCompletionBlock")
            
            if let error = error {
                print("FetchAllRecordZonesOperation error: \(error)")
            }
            
            if let subscriptions = subscriptions {
                self.fetchedSubscriptions = subscriptions
                for subscriptionID in subscriptions.keys {
                    print("Fetched CKSubscription: \(subscriptionID)")
                }
            }
        }
    }
}
