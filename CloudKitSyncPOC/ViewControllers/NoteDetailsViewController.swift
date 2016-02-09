//
//  NoteDetailsViewController.swift
//  CloudKitSyncPOC
//
//  Created by Nick Harris on 12/12/15.
//  Copyright © 2015 Nick Harris. All rights reserved.
//

import UIKit
import CoreData

class NoteDetailsViewController: UIViewController, CoreDataManagerViewController {

    @IBOutlet weak var noteTextView: UITextView!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    
    let noNoteErrorMessage = "Please supply a note"
    var originalFrameHeight: CGFloat?
    var coreDataManager: CoreDataManager?
    var modelObjectType: ModelObjectType?
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
    var note: Note?
    var managedObject: CTBRootManagedObject?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectContextChanged:", name: NSManagedObjectContextObjectsDidChangeNotification, object: coreDataManager?.mainThreadManagedObjectContext)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        originalFrameHeight = view.frame.size.height
        
        setTextView()
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
        if let note = note,
            let updatedObjectIndex = updatedObjects.indexOf(note) {
                let updatedObject = updatedObjects[updatedObjectIndex]
                self.note = updatedObject as? Note
                setTextView()
        }
    }
    
    func checkIfDeleted(deletedObjects: Set<NSManagedObject>) {
        if let managedObject = managedObject {
            if deletedObjects.contains(managedObject as! NSManagedObject) {
                navigationController?.popToRootViewControllerAnimated(true)
            }
        }
        if let note = note {
            if deletedObjects.contains(note) {
                navigationController?.popViewControllerAnimated(true)
            }
        }
    }
    
    func setTextView() {
        if let note = note {
            noteTextView.text = note.text
        }
        else {
            noteTextView.text = ""
            deleteButton.enabled = false
        }
    }
    
    func setFirstResponder() {
        
        if note == nil {
            noteTextView.becomeFirstResponder()
        }
    }
    
    @IBAction func saveAction() {
        let validationResult = validateNote()
        
        if let errorMessage = validationResult.errorMessage {
            showErrorAlert(errorMessage) {
                if let safeInputView = validationResult.inputView {
                    safeInputView.becomeFirstResponder()
                }
            }
        }
        else {
            saveNote()
        }
    }
    
    // MARK: Validate and Save
    func validateNote() -> (errorMessage: String?, inputView: UIView?) {
        guard let noteText = noteTextView.text else {
            return (noNoteErrorMessage, noteTextView)
        }
        
        if noteText.isEmpty {
            return (noNoteErrorMessage, noteTextView)
        }
        
        return (nil, nil)
    }
    
    func saveNote() {
        view.endEditing(true)
        
        guard let managedObjectContext = coreDataManager?.mainThreadManagedObjectContext,
            let noteText = noteTextView.text else {
                fatalError("NoteDetailsViewController: guard statement failed for either no managedObjectContext or invalid input")
        }
        
        if note == nil {
            guard let newNote = NSEntityDescription.insertNewObjectForEntityForName("Note", inManagedObjectContext: managedObjectContext) as? Note else {
                fatalError("NoteDetailsViewController: could not create Note object")
            }
            
            // make sure to set its uniqueID as well.
            newNote.added = NSDate()            
            if let car = car {
                if let notes = car.valueForKeyPath("notes") as? NSMutableSet {
                    notes.addObject(newNote)
                }
                newNote.car = car
            }
            else if let truck = truck {
                if let notes = truck.valueForKeyPath("notes") as? NSMutableSet {
                    notes.addObject(newNote)
                }
                newNote.truck = truck
            }
            else if let bus = bus {
                if let notes = bus.valueForKeyPath("notes") as? NSMutableSet {
                    notes.addObject(newNote)
                }
                newNote.bus = bus
            }
            
            note = newNote
        }
        
        note?.text = noteText
        note?.lastUpdate = NSDate()
        managedObject?.lastUpdate = NSDate()
        
        coreDataManager?.save()
        
        deleteButton.enabled = true
    }
    
    // MARK: Delete note
    @IBAction func deleteNote() {
        
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive) {
            [unowned self]
            action in
            
            guard let managedObjectContext = self.coreDataManager?.mainThreadManagedObjectContext,
                let note = self.note else {
                    fatalError("NoteDetailsViewController: No managedObjectContext or note")
            }
            
            note.addDeletedCloudKitObject()
            
            managedObjectContext.deleteObject(note)
            self.managedObject?.lastUpdate = NSDate()
            self.coreDataManager?.save()
            self.navigationController?.popViewControllerAnimated(true)
        }
        actionSheetController.addAction(deleteAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
        actionSheetController.addAction(cancelAction)
        
        presentViewController(actionSheetController, animated: true, completion: nil)
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

    // MARK: Keyboard
    func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let keyboardEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(),
            let rawAnimationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            else {
                fatalError("NoteDetailsViewController: Could not handle keyboard notification correctly")
        }
        
        let convertedKeyboardEndFrame = view.convertRect(keyboardEndFrame, fromView: view.window)
        let shiftedRawAnimationCurve = rawAnimationCurve.unsignedIntValue << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(shiftedRawAnimationCurve))
        
        let offset = noteTextView.frame.origin.y + noteTextView.frame.size.height - convertedKeyboardEndFrame.origin.y
        var viewFrame = view.frame
        viewFrame = CGRectMake(viewFrame.origin.x, viewFrame.origin.y, viewFrame.size.width, viewFrame.size.height - offset)
        view.frame = viewFrame
        
        UIView.animateWithDuration(animationDuration, delay: 0.0, options: [.BeginFromCurrentState, animationCurve], animations: {
            [unowned self] in
            self.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let rawAnimationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber,
            let originalFrameHeight = originalFrameHeight
            else {
                fatalError("NoteDetailsViewController: Could not handle keyboard notification correctly")
        }
        
        let shiftedRawAnimationCurve = rawAnimationCurve.unsignedIntValue << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(shiftedRawAnimationCurve))
        
        var viewFrame = view.frame
        viewFrame = CGRectMake(viewFrame.origin.x, viewFrame.origin.y, viewFrame.size.width, originalFrameHeight)
        view.frame = viewFrame
        
        UIView.animateWithDuration(animationDuration, delay: 0.0, options: [.BeginFromCurrentState, animationCurve], animations: {
            [unowned self] in
            self.view.layoutIfNeeded()
            }, completion: nil)
    }
}
