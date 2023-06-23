//
//  PresistenceController.swift
//  MiQ3
//
//  Created by Yuuki Nishiyama on 2021/08/19.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "MiQ3")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print(error.localizedDescription)
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
    
    func save() {
      let context = container.viewContext
      if context.hasChanges {
          do {
              try context.save()
          } catch {
              // Show some error here
          }
      }
  }
}
