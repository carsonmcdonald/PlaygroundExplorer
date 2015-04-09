import Cocoa

class PlaygroundDetailViewController: NSViewController, NSURLSessionDownloadDelegate {

    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var authorLabel: NSTextField!
    @IBOutlet var descriptionTextView: NSTextView!
    @IBOutlet var tagsTextView: NSTextView!
    @IBOutlet var urlTextView: NSTextView!
    @IBOutlet weak var downloadButton: NSButtonCell!
    @IBOutlet weak var openButton: NSButtonCell!
    @IBOutlet weak var openInFinderButton: NSButtonCell!
    @IBOutlet weak var moreInfoButton: NSButtonCell!
    
    private var currentlySelectedPlaygroundEntry: PlaygroundEntryData?
    private var downloadTaskToEntryData = [NSURLSessionTask:PlaygroundEntryData]()
    
    private var browseDetailNotification: NSObjectProtocol?
    
    private let sessionConfig = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("net.ioncannon.pge.Downloader")
    private var backgroundDownloadSession: NSURLSession!
    
    deinit {
        if self.browseDetailNotification != nil {
            NSNotificationCenter.defaultCenter().removeObserver(self.browseDetailNotification!)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.backgroundDownloadSession
            = NSURLSession(configuration: self.sessionConfig, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        
        self.browseDetailNotification = NSNotificationCenter.defaultCenter().addObserverForName(Config.Notification.BrowsePlaygroundSelected, object: nil, queue: NSOperationQueue.mainQueue()) { (notification:NSNotification!) -> Void in
            
            if notification.userInfo != nil {
                if let playgroundEntryData = notification.userInfo!["playgroundData"] as? PlaygroundEntryData {
                    self.nameLabel.stringValue = playgroundEntryData.name
                    self.authorLabel.stringValue = playgroundEntryData.author
                    self.descriptionTextView.string = playgroundEntryData.longDescription
                    self.tagsTextView.string = playgroundEntryData.tagsAsString()
                    self.urlTextView.string = playgroundEntryData.location
                    self.downloadButton.enabled = true
                    self.downloadButton.title = (playgroundEntryData.locationType == "zip" ? "Download" : "Clone")
                    self.openButton.enabled = self.findPlaygroundToOpen(playgroundEntryData.ident, playgrdoundDir: playgroundEntryData.playgroundDir) != nil
                    self.openInFinderButton.enabled = self.openButton.enabled
                    self.moreInfoButton.enabled = playgroundEntryData.moreInfoLink != nil
                    
                    self.currentlySelectedPlaygroundEntry = playgroundEntryData
                }
            } else {
                self.nameLabel.stringValue = ""
                self.authorLabel.stringValue = ""
                self.descriptionTextView.string = ""
                self.tagsTextView.string = ""
                self.urlTextView.string = ""
                self.downloadButton.enabled = false
                self.openButton.enabled = false
                self.currentlySelectedPlaygroundEntry = nil
                self.moreInfoButton.enabled = false
                self.openInFinderButton.enabled = self.openButton.enabled
            }

        }
    }
    
    @IBAction func openWithFinderAction(sender: NSButtonCell) {
        
        if self.currentlySelectedPlaygroundEntry != nil {
            if let playgroundLocation = self.findPlaygroundToOpen(self.currentlySelectedPlaygroundEntry!.ident, playgrdoundDir: self.currentlySelectedPlaygroundEntry!.playgroundDir) {
                if !NSWorkspace.sharedWorkspace().openFile(playgroundLocation.stringByDeletingLastPathComponent, withApplication: "Finder") {
                    Utils.showErrorAlert("Error opening directory")
                }
            }
        }
        
    }
    
    @IBAction func openAction(sender: NSButtonCell) {
        
        if self.currentlySelectedPlaygroundEntry != nil {
            if let playgroundLocation = self.findPlaygroundToOpen(self.currentlySelectedPlaygroundEntry!.ident, playgrdoundDir: self.currentlySelectedPlaygroundEntry!.playgroundDir) {
                
                if let foundXcodeVersion = Utils.findCompatibleXcodeVersionPath(self.currentlySelectedPlaygroundEntry!.minXcodeVersion) {
                    if NSFileManager.defaultManager().isExecutableFileAtPath(foundXcodeVersion) {
                        if !NSWorkspace.sharedWorkspace().openFile(playgroundLocation, withApplication:foundXcodeVersion) {
                            Utils.showErrorAlert("Error opening playground")
                        }
                    } else {
                        Utils.showErrorAlert("Can not find Xcode executable at: \(foundXcodeVersion)")
                    }
                } else {
                    if !NSWorkspace.sharedWorkspace().openFile(playgroundLocation) {
                        Utils.showErrorAlert("Error opening playground")
                    }
                }
                
            }
        }
        
    }
    
    @IBAction func downloadAction(sender: NSButtonCell) {
        
        if self.currentlySelectedPlaygroundEntry != nil {
            
            if self.currentlySelectedPlaygroundEntry!.locationType == "zip" {
                StatusNotification.broadcastStatus("Download started: \(self.currentlySelectedPlaygroundEntry!.name)")
                
                self.downloadPlayground(self.currentlySelectedPlaygroundEntry!.location, entry: self.currentlySelectedPlaygroundEntry!)
            } else if self.currentlySelectedPlaygroundEntry!.locationType == "git" {
                StatusNotification.broadcastStatus("Cloning: \(self.currentlySelectedPlaygroundEntry!.name)")
                
                self.clonePlayground(self.currentlySelectedPlaygroundEntry!.location, entry: self.currentlySelectedPlaygroundEntry!)
            } else {
                Utils.showErrorAlert("Unknown location type: \(self.currentlySelectedPlaygroundEntry!.locationType)")
            }

        }
        
    }
    
    @IBAction func moreInfoAction(sender: NSButtonCell) {
        if currentlySelectedPlaygroundEntry != nil && currentlySelectedPlaygroundEntry!.moreInfoLink != nil {
            if let url = NSURL(string: self.currentlySelectedPlaygroundEntry!.moreInfoLink!) {
                NSWorkspace.sharedWorkspace().openURL(url)
            }
        }
    }
    
    private func findPlaygroundToOpen(ident:String, playgrdoundDir:String) -> String? {
        let playgroundsDir = Utils.getPlaygroundsDirectory()
        let playgroundPath = playgroundsDir!.stringByAppendingPathComponent(ident)

        let files = NSFileManager.defaultManager().contentsOfDirectoryAtPath(playgroundPath, error: nil)
        if files != nil {
            for file in files! {
                let filename = file as! String
                if filename == playgrdoundDir {
                    return playgroundPath.stringByAppendingPathComponent(playgrdoundDir)
                }
            }
        }
        
        return nil
    }
    
    private func clonePlayground(cloneURL:String, entry:PlaygroundEntryData) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            
            let playgroundsDir = Utils.getPlaygroundsDirectory()
            
            let repo = GitRepo()
            let openRC = repo.cloneAndOpen(cloneURL, localName: playgroundsDir!.stringByAppendingPathComponent(entry.ident))
            if openRC == .None {
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if self.currentlySelectedPlaygroundEntry != nil && self.currentlySelectedPlaygroundEntry?.ident == entry.ident {
                        self.openButton.enabled = self.findPlaygroundToOpen(self.currentlySelectedPlaygroundEntry!.ident, playgrdoundDir: self.currentlySelectedPlaygroundEntry!.playgroundDir) != nil
                        self.openInFinderButton.enabled = self.openButton.enabled
                    }
                    
                    StatusNotification.broadcastStatus("Clone complete: \(entry.name)")
                })
                
            } else {
                StatusNotification.broadcastStatus("Clone error: \(entry.name)")
            }
            
        })

    }
    
    private func downloadPlayground(downloadURL:String, entry:PlaygroundEntryData) {

        if let url = NSURL(string: downloadURL) {
            let downloadTask = self.backgroundDownloadSession.downloadTaskWithURL(url)
            self.downloadTaskToEntryData[downloadTask] = entry
            downloadTask.resume()
        } else {
            Utils.showErrorAlert("Error parsing URL: \(downloadURL)")
        }

    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        let downloadEntry = self.downloadTaskToEntryData[task]
        self.downloadTaskToEntryData.removeValueForKey(task)

        if downloadEntry != nil {
            StatusNotification.broadcastStatus("Download error: \(downloadEntry!.name)")
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        let downloadEntry = self.downloadTaskToEntryData[downloadTask]
        self.downloadTaskToEntryData.removeValueForKey(downloadTask)
        
        let playgroundsDir = Utils.getPlaygroundsDirectory()
        let unZipped = SSZipArchive.unzipFileAtPath(location.path!, toDestination: playgroundsDir!.stringByAppendingPathComponent(downloadEntry!.ident))
        
        if unZipped {
            if self.currentlySelectedPlaygroundEntry != nil && self.currentlySelectedPlaygroundEntry?.ident == downloadEntry?.ident {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.openButton.enabled = self.findPlaygroundToOpen(self.currentlySelectedPlaygroundEntry!.ident, playgrdoundDir: self.currentlySelectedPlaygroundEntry!.playgroundDir) != nil
                    self.openInFinderButton.enabled = self.openButton.enabled
                })
            }
        } else {
            StatusNotification.broadcastStatus("Error unzipping playground: \(downloadEntry!.name)")
        }
        
        if downloadEntry != nil {
            StatusNotification.broadcastStatus("Download complete: \(downloadEntry!.name)")
        }
    }
    
}
