//
//  Bus+CoreDataProperties.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Bus {

    @NSManaged var name: String?
    @NSManaged var added: NSDate?
    @NSManaged var lastUpdate: NSDate?
    @NSManaged var notes: NSSet?
    @NSManaged var recordName: String?
    @NSManaged var recordID: NSData?

}
