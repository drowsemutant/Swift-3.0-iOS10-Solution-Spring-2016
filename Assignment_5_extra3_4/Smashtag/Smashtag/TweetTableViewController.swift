//
//  TweetTableViewController.swift
//  Smashtag
//
//  Created by CS193p Instructor.
//  Copyright © 2016 Stanford University. All rights reserved.
//

import UIKit
import Twitter
import CoreData
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class TweetTableViewController: UITableViewController, UITextFieldDelegate
{
    // MARK: Model

    var container: NSPersistentContainer! =
             (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer

    var tweets = [Array<Twitter.Tweet>](){
        didSet {
            tableView.reloadData()
        }
    }
   
    var searchText: String? = RecentSearches.searches.first ?? "#stanford"{
        didSet {
            lastTwitterRequest = nil
            searchTextField?.text = searchText
            tweets.removeAll()
            RecentSearches.add(searchText!)
            searchForTweets()
            title = searchText
        }
    }
    
    // MARK: Fetching Tweets
    
    fileprivate var twitterRequest: Twitter.Request? {
        if lastTwitterRequest == nil {
            if let query = searchText , !query.isEmpty {
                return Twitter.Request(search: query + " -filter:retweets", count: 100)
            }
        }
        return lastTwitterRequest?.requestForNewer
    }
    
    fileprivate var lastTwitterRequest: Twitter.Request?

    @IBAction fileprivate func searchForTweets(_ sender: UIRefreshControl?)
    {
        if let request = twitterRequest {
            lastTwitterRequest = request
            request.fetchTweets { [weak weakSelf = self] newTweets in
                DispatchQueue.main.async {
                    if request == weakSelf?.lastTwitterRequest {
                        if !newTweets.isEmpty {
                            weakSelf?.tweets.insert(newTweets, at: 0)
                            weakSelf?.tableView.reloadData()
                            sender?.endRefreshing()
                            weakSelf?.updateDatabase(newTweets: newTweets,
                                                     searchTerm:(weakSelf?.searchText)!)

                        }
                    }
                    sender?.endRefreshing()
                }
            }
        } else {
            sender?.endRefreshing()
        }
    }
    
    fileprivate func updateDatabase(newTweets: [Twitter.Tweet],searchTerm: String) {
       
         container.performBackgroundTask({ (moc) in
            TweetM.newTweetsWith(twitterInfo: newTweets,andSearchTerm: self.searchText!,
                                 inContext: moc)
            
            moc.saveThrows()
            TweetM.syncTerms(context: moc)
            
            self.printDatabaseStatistics(context: moc)
            
         })
    }
 
     private func printDatabaseStatistics(context: NSManagedObjectContext) {
 
            let request: NSFetchRequest<TweetM> = TweetM.fetchRequest()
            if let results = try? context.fetch(request) {
                print("\(results.count) TweetMs")
            }
            let requestSearch: NSFetchRequest<SearchTerm> = SearchTerm.fetchRequest()
            if let results = try? context.fetch(requestSearch) {
                for result  in results {
                    print("\(result.tweets.count) tweets \(result.mensions.count) mensions in \(result.term)")
                }
            }

           // более эффективный способ подсчета числа объектов  ...
            let searchCount = try! context.count(for: SearchTerm.fetchRequest())
            print("\(searchCount) SearchTerms")
            let mensionCount = try! context.count(for: Mension.fetchRequest())
            print("\(mensionCount) Mensions")

    }

    fileprivate func searchForTweets () {
        refreshControl?.beginRefreshing()
        searchForTweets(refreshControl)
    }
    
    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\(tweets.count - section)"
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return tweets.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tweets[section].count
    }
    
    // MARK: Constants
    
    fileprivate struct Storyboard {
        static let TweetCellIdentifier = "Tweet"
        static let MentionsIdentifier = "Show Mentions"
         static let ImagesIdentifier = "Show Images"
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.TweetCellIdentifier,
                                                                       for: indexPath)

        let tweet = tweets[indexPath.section][indexPath.row]
        
        if let tweetCell = cell as? TweetTableViewCell {
            tweetCell.tweet = tweet
        }
    
        return cell
    }
    
    
    // MARK: Outlets

    @IBOutlet weak var searchTextField: UITextField! {
        didSet {
            searchTextField.delegate = self
            searchTextField.text = searchText
        }
    }
    
    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        searchText = textField.text
        return true
    }
    
    // MARK: View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.estimatedRowHeight = tableView.rowHeight
        tableView.rowHeight = UITableViewAutomaticDimension
 
          if tweets.count == 0 {
             searchForTweets()
        }
              if RecentSearches.searches.first == nil {
             RecentSearches.add(searchText!)
        }
     }
    
    func toRootViewController(_ sender: UIBarButtonItem) {
       _ = navigationController?.popToRootViewController(animated: true)
     
    }
    
    func showImages(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: Storyboard.ImagesIdentifier, sender: sender)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Stop Button -----
        let imageButton = UIBarButtonItem(barButtonSystemItem: .camera,
                                          target: self,
                                          action: #selector(TweetTableViewController.showImages(_:)))
        navigationItem.rightBarButtonItems = [imageButton]
        if navigationController?.viewControllers.count > 1 {
            
            let stopBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop,
                                                    target: self,
                                                    action: #selector(TweetTableViewController.toRootViewController(_:)))
            
            if let rightBarButtonItem = navigationItem.rightBarButtonItem {
                navigationItem.rightBarButtonItems = [stopBarButtonItem, rightBarButtonItem]
            } else {
                navigationItem.rightBarButtonItem = stopBarButtonItem
            }
        }

       }

    
    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String?,
                                                   sender: Any?) -> Bool {
        if identifier == Storyboard.MentionsIdentifier {
            if let tweetCell = sender as? TweetTableViewCell {
                if tweetCell.tweet!.hashtags.count + tweetCell.tweet!.urls.count +
                   tweetCell.tweet!.userMentions.count +
                   tweetCell.tweet!.media.count == 0 {
                    return false
                }
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            if identifier == Storyboard.MentionsIdentifier,
                let mtvc = segue.destination as? MentionsTableViewController,
                let tweetCell = sender as? TweetTableViewCell {
                mtvc.tweet = tweetCell.tweet
                
            } else if identifier == Storyboard.ImagesIdentifier {
                if let icvc = segue.destination as? ImageCollectionViewController {
                    icvc.tweets = tweets
                    icvc.title = "Images: \(searchText!)"
                }
            }
        }
    }
}
