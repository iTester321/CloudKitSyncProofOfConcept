//
//  DetailsViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class DetailsViewController: UIViewController, CoreDataManagerViewController {
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var addedLabel: UILabel!
    @IBOutlet weak var lastUpdatedLabel: UILabel!
    @IBOutlet weak var notesButton: UIButton!
    
    var modelObjectType: ModelObjectType?
    var car: Car?
    var truck: Truck?
    var bus: Bus?
    var coreDataManager: CoreDataManager?
    var dateFormatter = NSDateFormatter()
    var hasObject: Bool = false
    let noNameErrorMessage = "Please supply a name"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateStyle = NSDateFormatterStyle.ShortStyle
        dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectContextChanged:", name: NSManagedObjectContextObjectsDidChangeNotification, object: coreDataManager?.mainThreadManagedObjectContext)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setupView()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func managedObjectContextChanged(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            // we don't care about inserted objects in this view
            if let updatedObjects = userInfo[NSUpdatedObjectsKey] {
                checkForUpdate(updatedObjects as! Set<NSManagedObject>)
            }
            if let refreshed = userInfo[NSRefreshedObjectsKey] {
                checkForUpdate(refreshed as! Set<NSManagedObject>)
            }
            if let deletedObjects = userInfo[NSDeletedObjectsKey] {
                checkIfDeleted(deletedObjects as! Set<NSManagedObject>)
            }
        }
    }
    
    func checkForUpdate(updatedObjects: Set<NSManagedObject>) {
        if let rootObject = modelObject(),
           let managedObject = rootObject as? NSManagedObject,
           let updatedObjectIndex = updatedObjects.indexOf(managedObject) {
            let updatedObject = updatedObjects[updatedObjectIndex]
            setLabels(updatedObject as! CTBRootManagedObject)
        }
    }
    
    func checkIfDeleted(deletedObjects: Set<NSManagedObject>) {
        if let rootObject = modelObject(),
            let managedObject = rootObject as? NSManagedObject {
                if deletedObjects.contains(managedObject) {
                    navigationController?.popViewControllerAnimated(true)
                }
        }
    }
    
    // MARK: Setup the view
    func setupView() {
        if let modelObject = modelObject()  {
            setLabels(modelObject)
        }
        else {
            // new item, disable the delete and notes buttons
            deleteButton.enabled = false
            notesButton.enabled = false
            addedLabel.text = ""
            lastUpdatedLabel.text = ""
        }
    }
    
    func modelObject() -> CTBRootManagedObject? {
        if let managedObject = car as? CTBRootManagedObject {
            return managedObject
        }
        else if let managedObject = truck as? CTBRootManagedObject {
            return managedObject
        }
        else if let managedObject = bus as? CTBRootManagedObject {
            return managedObject
        }
        else {
            return nil
        }
    }
    
    func setLabels(managedObject: CTBRootManagedObject) {
        hasObject = true
        deleteButton.enabled = true
        notesButton.enabled = true
        nameTextField.text = managedObject.name
        if let added = managedObject.added,
            let lastUpdated = managedObject.lastUpdate {
                addedLabel.text = dateFormatter.stringFromDate(added)
                lastUpdatedLabel.text = dateFormatter.stringFromDate(lastUpdated)
        }
    }
    
    func setFirstResponder() {
        if car == nil && truck == nil && bus == nil {
            // new item, set the text field as the first responder
            nameTextField.becomeFirstResponder()
        }
    }
    
    // MARK: Validate and Save
    @IBAction func saveAction() {
        let validationResult = validateProject()
        
        if let errorMessage = validationResult.errorMessage {
            showErrorAlert(errorMessage) {
                if let safeInputView = validationResult.inputView {
                    safeInputView.becomeFirstResponder()
                }
            }
        }
        else {
            saveObject()
        }
    }
    
    func validateProject() -> (errorMessage: String?, inputView: UIView?) {
        guard let objectName = nameTextField.text else {
            return (noNameErrorMessage, nameTextField)
        }
        
        if objectName.isEmpty {
            return (noNameErrorMessage, nameTextField)
        }
        
        return(nil, nil)
    }
    
    func saveObject() {
        view.endEditing(true)
        
        guard let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext,
            let objectName = nameTextField.text,
            let modelObjectType = modelObjectType else {
                fatalError("DetailsViewController - saveObject: guard statement failed for either no managedObjectContext or invalid input")
        }
        
        var managedObject: CTBRootManagedObject? = nil
        if !hasObject {
            switch modelObjectType {
            case .Car:
                managedObject = createNewCarObject(managedObjectContext)
            case .Truck:
                managedObject = createNewTruckObject(managedObjectContext)
            case .Bus:
                managedObject = createNewBusObject(managedObjectContext)
            default: break
            }
            
            managedObject?.added = NSDate()
            hasObject = true
        }
        else {
            switch modelObjectType {
            case .Car:
                managedObject = car as? CTBRootManagedObject
            case .Truck:
                managedObject = truck as? CTBRootManagedObject
            case .Bus:
                managedObject = bus as? CTBRootManagedObject
            default: break
            }
        }
        
        managedObject?.name = objectName
        managedObject?.lastUpdate = NSDate()
        
        coreDataManager?.save()
        setLabels(managedObject!)
    }
    
    func createNewCarObject(managedObjectContext: NSManagedObjectContext) -> CTBRootManagedObject {
        guard let newCar = NSEntityDescription.insertNewObjectForEntityForName("Car", inManagedObjectContext: managedObjectContext) as? Car else {
            fatalError("DetailsViewController - saveProject : could not create Car object")
        }
        
        car = newCar
        return car as! CTBRootManagedObject
    }
    
    func createNewTruckObject(managedObjectContext: NSManagedObjectContext) -> CTBRootManagedObject {
        guard let newTruck = NSEntityDescription.insertNewObjectForEntityForName("Truck", inManagedObjectContext: managedObjectContext) as? Truck else {
            fatalError("DetailsViewController - saveProject : could not create Truck object")
        }
        
        truck = newTruck
        return truck as! CTBRootManagedObject
    }
    
    func createNewBusObject(managedObjectContext: NSManagedObjectContext) -> CTBRootManagedObject {
        guard let newBus = NSEntityDescription.insertNewObjectForEntityForName("Bus", inManagedObjectContext: managedObjectContext) as? Bus else {
            fatalError("DetailsViewController - saveProject : could not create Bus object")
        }
        
        bus = newBus
        return bus as! CTBRootManagedObject
    }
    
    // MARK: Delete
    @IBAction func deleteAction() {
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive) {
            [unowned self]
            action in
            
            self.deleteObject()
        }
        actionSheetController.addAction(deleteAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
        actionSheetController.addAction(cancelAction)
        
        presentViewController(actionSheetController, animated: true, completion: nil)
    }
    
    func deleteObject() {
        guard let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext else {
            fatalError("DetailsViewController - deleteManagedObject: guard statement failed for no managedObjectContext")
        }
        
        if let car = car {
            car.addDeletedCloudKitObject()
            managedObjectContext.deleteObject(car)
        }
        else if let truck = truck {
            truck.addDeletedCloudKitObject()
            managedObjectContext.deleteObject(truck)
        }
        else if let bus = bus {
            bus.addDeletedCloudKitObject()
            managedObjectContext.deleteObject(bus)
        }
        
        coreDataManager?.save()
        navigationController?.popViewControllerAnimated(true)
    }
    
    // MARK: Show Error
    func showErrorAlert(errorMessage: String, okAction:(()->())?) {
        let alertController = UIAlertController(title: nil, message: errorMessage, preferredStyle: .Alert)
        
        let OKAction = UIAlertAction(title: "OK", style: .Default) {
            action in
            
            if let safeOkAction = okAction {
                safeOkAction()
            }
        }
        alertController.addAction(OKAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    // MARK: Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        // set the coreDataManager either on the root of a UINavigationController or on the segue destination itself
        if var destinationCoreDataViewController = segue.destinationViewController as? CoreDataManagerViewController {
            destinationCoreDataViewController.coreDataManager = coreDataManager
            destinationCoreDataViewController.modelObjectType = modelObjectType
        }
        
        if let notesTableViewController = segue.destinationViewController as? NotesTableViewController {
            notesTableViewController.car = car
            notesTableViewController.bus = bus
            notesTableViewController.truck = truck
        }
    }

}
