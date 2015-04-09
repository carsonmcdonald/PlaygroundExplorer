import Cocoa

class PreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var addXcodeButtonCell: NSButton!
    @IBOutlet weak var removeXcodeButtonCell: NSButton!
    
    @IBOutlet weak var xcodeVersionsTableView: NSTableView!
    
    private var xcodeVersions = [XcodeVersion]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        removeXcodeButtonCell.enabled = false
        
        self.xcodeVersions = Utils.loadXcodeVersions()
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.xcodeVersions.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeViewWithIdentifier("XCodeVersionCell", owner: self) as? NSTableCellView {
            cell.textField?.stringValue = "\(self.xcodeVersions[row].bundleVersionString) build \(self.xcodeVersions[row].buildVersion): \(self.xcodeVersions[row].xcodePath)"
            return cell
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        
        if self.xcodeVersionsTableView.selectedRow >= 0 &&
           self.xcodeVersions.count > self.xcodeVersionsTableView.selectedRow {
            
            self.removeXcodeButtonCell.enabled = true
            
        } else {
            
            self.removeXcodeButtonCell.enabled = false
            
        }
        
    }
    
    @IBAction func addXcodeAction(sender: AnyObject) {
        
        var openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.beginSheetModalForWindow(self.view.window!, completionHandler: { (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                
                if let xcodePath = openPanel.URL?.path {
                    let versionPlistPath = xcodePath.stringByAppendingPathComponent("Contents").stringByAppendingPathComponent("version.plist")
                    if let versionDict = NSDictionary(contentsOfFile: versionPlistPath) as? Dictionary<String, AnyObject> {
                        
                        let bundleVersionString = versionDict["CFBundleShortVersionString"] as? String
                        let buildVersion = versionDict["BuildVersion"] as? String
                        
                        if bundleVersionString == nil || buildVersion == nil {
                            Utils.showErrorAlert("Could not find version of Xcode")
                        } else {
                            var xcodeVersion = XcodeVersion()
                            xcodeVersion.bundleVersionString = bundleVersionString!
                            xcodeVersion.buildVersion = buildVersion!
                            xcodeVersion.xcodePath = xcodePath
                            self.xcodeVersions.append(xcodeVersion)
                            self.xcodeVersionsTableView.reloadData()
                            
                            Utils.syncXcodeVersions(self.xcodeVersions)
                        }
                        
                    } else {
                        Utils.showErrorAlert("Could not read version")
                    }
                } else {
                    Utils.showErrorAlert("Could not read path")
                }
                
            }
        })

    }
    
    @IBAction func removeXcodeAction(sender: AnyObject) {
        let row = self.xcodeVersionsTableView.selectedRow

        self.xcodeVersions.removeAtIndex(row)
        self.xcodeVersionsTableView.removeRowsAtIndexes(NSIndexSet(index: row), withAnimation: NSTableViewAnimationOptions.EffectFade)
        
        Utils.syncXcodeVersions(self.xcodeVersions)
    }
    
}
