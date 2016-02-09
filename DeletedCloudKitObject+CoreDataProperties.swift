//
//  DeletedCloudKitObject+CoreDataProperties.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/27/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension DeletedCloudKitObject {

    @NSManaged var recordType: String?
    @NSManaged var recordID: NSData?

}
