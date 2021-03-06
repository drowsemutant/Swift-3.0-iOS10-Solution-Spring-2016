//
//  RecentsTableViewController.swift
//  Smashtag
//
//  Created by Tatiana Kornilova on 7/19/16.
//  Copyright © 2016 Stanford University. All rights reserved.
//

import UIKit
import CoreData

class RecentsTableViewController: UITableViewController {

    // MARK: Model
    
    var recentSearches: [String] {
        return RecentSearches.searches
    }
    
    var container: NSPersistentContainer! =
          (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer
    
    var moc:NSManagedObjectContext {
                 return container.viewContext
    }
    
    // MARK: View
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        tableView.reloadData()
    }
    
    fileprivate struct Storyboard {
        fileprivate static let RecentCell = "Recent Cell"
        fileprivate static let TweetsSegue = "Show Tweets from Recent"
        fileprivate static let PopularSegueIdentifier = "ShowPopularMensions"
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 }
    
    override func tableView(_ tableView: UITableView,
                                  numberOfRowsInSection section: Int) -> Int {
        return recentSearches.count}

    
    override func tableView(_ tableView: UITableView,
             cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.RecentCell,
                                          for: indexPath) as UITableViewCell
        cell.textLabel?.text = recentSearches[(indexPath as NSIndexPath).row]
        return cell
    }
    
    // Переопределяем поддержку редактирования table view.
    
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCellEditingStyle,
                            forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            // уничтожаем строку из data source
            let term = recentSearches[(indexPath as NSIndexPath).row]
            moc.perform({ 
                let request: NSFetchRequest<SearchTerm> = SearchTerm.fetchRequest()
                request.predicate = NSPredicate(format: "term = %@", term)
                if let results = try? self.moc.fetch(request),
                    let searchTerm = results.first {
                    self.moc.delete(searchTerm)
                    do {
                        try self.moc.save()
                        RecentSearches.removeAtIndex((indexPath as NSIndexPath).row)
                        tableView.deleteRows(at: [indexPath], with: .fade)
                    } catch {
                        fatalError("Ошибка сохранения main managed object context! \(error)")
                    }
                }
            })
        }
    }

    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {        
        if let identifier = segue.identifier , identifier == Storyboard.TweetsSegue,
            let cell = sender as? UITableViewCell,
            let ttvc = segue.destination as? TweetTableViewController
        {
            ttvc.searchText = cell.textLabel?.text
            
        } else  if let identifier = segue.identifier ,
            identifier == Storyboard.PopularSegueIdentifier,
            let cell = sender as? UITableViewCell,
            let pvc = segue.destination as? PopularityTableViewController
        {
            pvc.searchText = cell.textLabel?.text
            pvc.moc = moc
            pvc.title = "Popularity for " + (cell.textLabel?.text ?? "")
        }
    }
    
}
