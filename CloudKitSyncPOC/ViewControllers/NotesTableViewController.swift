//
//  NotesTableViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class NotesTableViewController: UITableViewController, CoreDataManagerViewController, NSFetchedResultsControllerDelegate {
    
    var fetchedResultsController: NSFetchedResultsController?
    var modelObjectType: ModelObjectType?
    var managedObject: CTBRootManagedObject?
    var car: Car? {
        didSet {
            if let car = car {
                managedObject = car as CTBRootManagedObject
            }
        }
    }
    var truck: Truck? {
        didSet {
            if let truck = truck {
                managedObject = truck as CTBRootManagedObject
            }
        }
    }
    var bus: Bus? {
        didSet {
            if let bus = bus {
                managedObject = bus as CTBRootManagedObject
            }
        }
    }
    var coreDataManager: CoreDataManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if coreDataManager != nil {
            configureFetchedResultsController()
        }
    }
    
    // NSFetchedResultsController
    func configureFetchedResultsController() {
        let fetchRequest = NSFetchRequest(entityName: "Note")
        let nameSortDescriptor = NSSortDescriptor(key: "added", ascending: true)
        
        fetchRequest.sortDescriptors = [nameSortDescriptor]
        fetchRequest.predicate = configureFetchPredicate()
        
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
            fatalError("NotesTableViewController - configureFetchedResultsController: fetch failed \(error.localizedDescription)")
        }
        
        tableView.reloadData()
    }
    
    func configureFetchPredicate() -> NSPredicate {
        if let car = car {
            return NSPredicate.init(format: "car == %@", car)
        }
        else if let truck = truck {
            return NSPredicate.init(format: "truck == %@", truck)
        }
        else if let bus = bus {
            return NSPredicate.init(format: "bus == %@", bus)
        }
        
        fatalError("NotesTableViewController: no suitable parent object found while configuring the FRC")
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
        if let noteListCell = tableView.dequeueReusableCellWithIdentifier(NoteListCell.ReuseID) as? NoteListCell,
            let note = fetchedResultsController?.objectAtIndexPath(indexPath) as? Note {
                noteListCell.configureCell(note)
                return noteListCell
        }
        else {
            fatalError("NotesTableViewController: Unexpected Cell Type")
        }
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            if let note = fetchedResultsController?.objectAtIndexPath(indexPath) as? Note {
                
                if let cloudKitManagedObject = managedObject as? CloudKitManagedObject {
                    cloudKitManagedObject.addDeletedCloudKitObject()
                }
                
                coreDataManager?.mainThreadManagedObjectContext.deleteObject(note)
                coreDataManager?.save()
            }
        }
    }
    
    // MARK: UITableViewDelegate
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            guard let newIndexPath = newIndexPath else {
                fatalError("NotesTableViewController: nil indexpath")
            }
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
            
        case .Update:
            guard let indexPath = indexPath,
                let noteListCell = tableView.cellForRowAtIndexPath(indexPath) as? NoteListCell,
                let note = anObject as? Note else {
                    fatalError("NotesTableViewController: not enough data to update a cell")
            }
            noteListCell.configureCell(note)
            
        case .Delete:
            guard let indexPath = indexPath else {
                fatalError("NotesTableViewController: nil indexpath")
            }
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            
        case .Move:
            guard let newIndexPath = newIndexPath,
                let indexPath = indexPath else {
                    fatalError("NotesTableViewController: not enough data to move a cell")
            }
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
    
    // MARK: IBOutlet
    @IBAction func addNoteAction() {
        performSegueWithIdentifier("NoteDetailsSegue", sender: nil)
    }
   
    // MARK: Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        // set the coreDataManager either on the root of a UINavigationController or on the segue destination itself
        if var destinationCoreDataViewController = segue.destinationViewController as? CoreDataManagerViewController {
            destinationCoreDataViewController.coreDataManager = coreDataManager
            destinationCoreDataViewController.modelObjectType = modelObjectType
        }
        
        if let noteDetailsViewController = segue.destinationViewController as? NoteDetailsViewController {
            noteDetailsViewController.car = car
            noteDetailsViewController.truck = truck
            noteDetailsViewController.bus = bus
            
            if let tableViewCell = sender as? UITableViewCell,
                let indexPath = tableView?.indexPathForCell(tableViewCell),
                let note = fetchedResultsController?.objectAtIndexPath(indexPath) as? Note
            {
                noteDetailsViewController.note = note
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                [unowned self] in
                
                self.transitionCoordinator()?.animateAlongsideTransition(nil, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
                    noteDetailsViewController.setFirstResponder()
                })
            })
        }
    }
}

class NoteListCell: UITableViewCell {
    class var ReuseID: String { return "NoteListCellID" }
    
    func configureCell(note: Note) {
        textLabel?.text = note.text
    }
}
