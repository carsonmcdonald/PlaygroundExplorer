import Cocoa

class BrowseTableViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var browseTableView : NSTableView!
    
    private var playgroundDataFiles: [String] = []
    private var playgroundRepoData: [String:[PlaygroundEntryRepoData]]?
    
    override func viewDidAppear() {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            
            StatusNotification.broadcastStatus("Updating metadata")
            
            Utils.cloneOrUpdatePlaygroundData()
            self.playgroundRepoData = Utils.getRepoInformationFromPlaygroundData()
            self.loadAndParsePlaygroundData()
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.browseTableView.reloadData()
                StatusNotification.broadcastStatus("Metadata update complete")
            })

        })
        
    }

    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 75
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeViewWithIdentifier("BrowseTableCellView", owner: self) as? BrowseTableCellView {
            if let playgroundData = self.parseJSONData(self.playgroundDataFiles[row]) {
                cell.playgroundData = playgroundData
                return cell
            }
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        
        if self.browseTableView.selectedRow >= 0 && self.playgroundDataFiles.count > self.browseTableView.selectedRow {
            let playgroundDataFile = self.playgroundDataFiles[self.browseTableView.selectedRow]
            if let playgroundData = self.parseJSONData(playgroundDataFile) {
                
                NSNotificationCenter.defaultCenter().postNotificationName(Config.Notification.BrowsePlaygroundSelected, object: self, userInfo: ["playgroundData":playgroundData])
                
            }
        } else {
            NSNotificationCenter.defaultCenter().postNotificationName(Config.Notification.BrowsePlaygroundSelected, object: self, userInfo: nil)
        }
        
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.playgroundDataFiles.count
    }
    
    private func loadAndParsePlaygroundData() {
        
        self.playgroundDataFiles.removeAll(keepCapacity: true)
        
        let playgroundRepo = Utils.getPlaygroundRepoDirectory()
        let files = NSFileManager.defaultManager().contentsOfDirectoryAtPath(playgroundRepo!, error: nil)
        
        if files != nil {
            for file in files! {
                
                let filename = file as! String
                
                if let range = filename.rangeOfString(".json") {
                    if range.endIndex == filename.endIndex {
                        if let jsonFile = playgroundRepo?.stringByAppendingPathComponent(filename) {
                            if NSFileManager.defaultManager().fileExistsAtPath(jsonFile) {
                                
                                self.playgroundDataFiles.append(jsonFile)
                                
                            }
                        }
                    }
                }
                
            }
        }
        
    }
    
    private func parseJSONData(jsonFile:String) -> PlaygroundEntryData? {
        
        if let jsonData = NSData(contentsOfFile: jsonFile) {
            var parseError: NSError?
            let parsedObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(jsonData, options: NSJSONReadingOptions.AllowFragments, error:&parseError)
            
            if parseError != nil {
                Utils.showErrorAlert("Error parsing json in \(jsonFile): \(parseError)")
            } else {
                if let playgroundDataDictionary = parsedObject as? NSDictionary {
                    if let playgroundData = PlaygroundEntryData(jsonData: playgroundDataDictionary) {
                        
                        if self.playgroundRepoData != nil {
                            playgroundData.repoDataList = self.playgroundRepoData![jsonFile.lastPathComponent]
                        }
                        
                        return playgroundData
                        
                    } else {
                        Utils.showErrorAlert("Playground data format incorrect \(jsonFile)")
                    }
                } else {
                    Utils.showErrorAlert("Root is not a dictionary \(jsonFile)")
                }
            }
            
        } else {
            Utils.showErrorAlert("Couldn't read file \(jsonFile)")
        }
        
        return nil
        
    }
    
}

