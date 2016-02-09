//
//  CoreDataEnumerations.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 1/12/16.
//  Copyright © 2016 Nick Harris. All rights reserved.
//

import Foundation

enum ModelObjectType: String {
    case Car = "Car"
    case Truck = "Truck"
    case Bus = "Bus"
    case Note = "Note"
    case DeletedCloudKitObject = "DeletedCloudKitObject"
    
    init?(storyboardRestorationID: String) {
        switch storyboardRestorationID {
        case "CarsListScene" : self = .Car
        case "TrucksListScene" : self = .Truck
        case "BusesListScene" : self = .Bus
        default : return nil
        }
    }
    
    static let allCloudKitModelObjectTypes = [
        ModelObjectType.Car.rawValue,
        ModelObjectType.Truck.rawValue,
        ModelObjectType.Bus.rawValue,
        ModelObjectType.Note.rawValue
    ]
}