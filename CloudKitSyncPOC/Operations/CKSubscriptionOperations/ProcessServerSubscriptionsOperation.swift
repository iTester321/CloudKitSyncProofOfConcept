//
//  ProcessServerSubscriptionsOperation.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/18/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import CloudKit

class ProcessServerSubscriptionsOperation: NSOperation {

    var preProcessFetchedSubscriptions: [String : CKSubscription]
    var postProcessSubscriptionsToCreate: [CKSubscription]?
    var postProcessSubscriptionIDsToDelete: [String]?
    
    override init() {
        
        self.preProcessFetchedSubscriptions = [:]
        self.postProcessSubscriptionsToCreate = nil
        self.postProcessSubscriptionIDsToDelete = nil
        
        super.init()
    }
    
    override func main() {
        
        print("ProcessServerSubscriptionsOperation.main()")
        
        setSubscriptionsToCreate()
        setSubscriptionsToDelete()
    }
    
    private func setSubscriptionsToCreate() {
        
        let serverSubscriptionZoneNamesSet = createServerSubscriptionZoneNameSet()
        let expectedZoneNamesWithSubscriptionsSet = Set(CloudKitZone.allCloudKitZoneNames)
        let missingSubscriptionZoneNames = expectedZoneNamesWithSubscriptionsSet.subtract(serverSubscriptionZoneNamesSet)
        
        if missingSubscriptionZoneNames.count > 0 {
            postProcessSubscriptionsToCreate = []
            for missingSubscriptionZoneName in missingSubscriptionZoneNames {
                if let cloudKitSubscription = CloudKitZone(rawValue: missingSubscriptionZoneName) {
                    postProcessSubscriptionsToCreate?.append(cloudKitSubscription.cloudKitSubscription())
                }
            }
        }
    }
    
    private func setSubscriptionsToDelete() {
        
        let serverSubscriptionZoneNamesSet = createServerSubscriptionZoneNameSet()
        let expectedZoneNamesWithSubscriptionsSet = Set(CloudKitZone.allCloudKitZoneNames)
        let unexpectedSubscriptionZoneNamesSet = serverSubscriptionZoneNamesSet.subtract(expectedZoneNamesWithSubscriptionsSet)
        
        if unexpectedSubscriptionZoneNamesSet.count > 0 {
            postProcessSubscriptionIDsToDelete = []
            
            var subscriptionZoneNameDictionary: [String : CKSubscription] = [:]
            for subscription in preProcessFetchedSubscriptions.values {
                if let zoneID = subscription.zoneID {
                    subscriptionZoneNameDictionary[zoneID.zoneName] = subscription
                }
            }
            
            for subscriptionZoneName in unexpectedSubscriptionZoneNamesSet {
                if let subscription = subscriptionZoneNameDictionary[subscriptionZoneName] {
                    postProcessSubscriptionIDsToDelete?.append(subscription.subscriptionID)
                }
            }
        }
    }
    
    private func createServerSubscriptionZoneNameSet() -> Set<String> {
        
        let serverSubscriptions = Array(preProcessFetchedSubscriptions.values)
        let serverSubscriptionZoneIDs = serverSubscriptions.flatMap { $0.zoneID }
        let serverSubscriptionZoneNamesSet = Set(serverSubscriptionZoneIDs.map { $0.zoneName })
        
        return serverSubscriptionZoneNamesSet
    }
}
