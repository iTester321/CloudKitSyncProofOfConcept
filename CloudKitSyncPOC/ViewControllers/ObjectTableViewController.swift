//
//  ObjectTableViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class ObjectTableViewController: UITableViewController, CoreDataManagerViewController, NSFetchedResultsControllerDelegate {
    
    lazy var coreDataEntityName: String = self.getCoreDataObjectName()
    func getCoreDataObjectName() -> String {
        guard let restorationIdentifier = restorationIdentifier,
            let objectType = ModelObjectType.init(storyboardRestorationID: restorationIdentifier) else {
                fatalError("Tabbar view setup without a known restorationIdentifier")
        }
        
        modelObjectType = objectType
        return objectType.rawValue
    }
    
    var fetchedResultsController: NSFetchedResultsController?
    var modelObjectType: ModelObjectType?
    var coreDataManager: CoreDataManager? {
        didSet {
            if isViewLoaded() {
                configureFetchedResultsController()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if coreDataManager != nil {
            configureFetchedResultsController()
        }
    }
    
    func configureFetchedResultsController() {
        let fetchRequest = NSFetchRequest(entityName: coreDataEntityName)
        let nameSortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        
        fetchRequest.sortDescriptors = [nameSortDescriptor]
        
        if let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext {
            fetchedResultsController = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil)
        }
        
        fetchedResultsController?.delegate = self
        
        do {
            try fetchedResultsController?.performFetch()
        }
        catch let error as NSError {
            fatalError("ObjectTableViewController - configureFetchedResultsController: fetch failed \(error.localizedDescription)")
        }
        
        tableView.reloadData()
    }
    
    // MARK: IBAction
    @IBAction func addObjectAction() {
        performSegueWithIdentifier("DetailsObjectSegue", sender: nil)
    }
    
    @IBAction func refresh() {
        coreDataManager?.sync()
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            guard let newIndexPath = newIndexPath else {
                fatalError("ObjectTableViewController: nil indexpath")
            }
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
            
        case .Update:
            guard let indexPath = indexPath,
                let objectListCell = tableView.cellForRowAtIndexPath(indexPath) as? ObjectListCell,
                let managedObject = anObject as? NSManagedObject,
                let ctbRootObject = managedObject as? CTBRootManagedObject else {
                    fatalError("ObjectTableViewController: not enough data to update a cell")
            }
            objectListCell.configureCell(ctbRootObject)
            
        case .Delete:
            guard let indexPath = indexPath else {
                fatalError("ObjectTableViewController: nil indexpath")
            }
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            
        case .Move:
            guard let newIndexPath = newIndexPath,
                let indexPath = indexPath else {
                    fatalError("ObjectTableViewController: not enough data to move a cell")
            }
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
    
    // MARK: UITableViewDataSource
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let numberOfObjects = fetchedResultsController?.fetchedObjects?.count {
            return numberOfObjects
        }
        
        return 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let objectListCell = tableView.dequeueReusableCellWithIdentifier(ObjectListCell.ReuseID) as? ObjectListCell,
           let managedObject = fetchedResultsController?.objectAtIndexPath(indexPath) as? NSManagedObject,
           let ctbRootObject = managedObject as? CTBRootManagedObject {
            objectListCell.configureCell(ctbRootObject)
            return objectListCell
        }
        else {
            fatalError("ObjectTableViewController: Unexpected Cell Type")
        }
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            if let managedObject = fetchedResultsController?.objectAtIndexPath(indexPath) as? NSManagedObject {
                
                if let cloudKitManagedObject = managedObject as? CloudKitManagedObject {
                    cloudKitManagedObject.addDeletedCloudKitObject()
                }
                
                coreDataManager?.mainThreadManagedObjectContext.deleteObject(managedObject)
                coreDataManager?.save()
            }
        }
    }
    
    // MARK: UITableViewDelegate
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }
    
    // MARK: Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        // set the coreDataManager either on the root of a UINavigationController or on the segue destination itself
        if var destinationCoreDataViewController = segue.destinationViewController as? CoreDataManagerViewController {
            destinationCoreDataViewController.coreDataManager = coreDataManager
            destinationCoreDataViewController.modelObjectType = modelObjectType
        }
        
        if let detailsViewController = segue.destinationViewController as? DetailsViewController {
            if let tableViewCell = sender as? UITableViewCell,
               let indexPath = tableView?.indexPathForCell(tableViewCell)
            {
                if let car = fetchedResultsController?.objectAtIndexPath(indexPath) as? Car {
                    detailsViewController.car = car
                }
                else if let truck = fetchedResultsController?.objectAtIndexPath(indexPath) as? Truck {
                    detailsViewController.truck = truck
                }
                else if let bus = fetchedResultsController?.objectAtIndexPath(indexPath) as? Bus {
                    detailsViewController.bus = bus
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                [unowned self] in
                
                self.transitionCoordinator()?.animateAlongsideTransition(nil, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
                    detailsViewController.setFirstResponder()
                })
            })
        }
    }
}

class ObjectListCell: UITableViewCell {
    class var ReuseID: String { return "ObjectListCellID" }
    
    func configureCell(object: CTBRootManagedObject) {
        textLabel?.text = object.name
    }
}
