import Cocoa

class BrowseTableCellView : NSTableCellView {
    
    @IBOutlet weak var nameLabel : NSTextField!
    @IBOutlet weak var compatibleLabel : NSTextField!
    @IBOutlet weak var tagsLabel : NSTextField!
    @IBOutlet weak var lastUpdatedLabel : NSTextField!
    
    var playgroundData : PlaygroundEntryData! {
        didSet {
            self.nameLabel.stringValue = playgroundData.name
            self.compatibleLabel.stringValue = playgroundData.minXcodeVersion.fullVersion
            self.tagsLabel.stringValue = playgroundData.tagsAsString()
            if let lastUpdatedTS = playgroundData.lastUpdatedTime() {
                let dateFormat = NSDateFormatter()
                dateFormat.dateStyle = .MediumStyle
                dateFormat.timeStyle = .NoStyle
                self.lastUpdatedLabel.stringValue = dateFormat.stringFromDate(lastUpdatedTS)
            } else {
                self.lastUpdatedLabel.stringValue = ""
            }
        }
    }
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            let textColor = (backgroundStyle == .Dark) ? NSColor.windowBackgroundColor() : NSColor.blackColor()
            for subview in self.subviews {
                if let label = subview as? NSTextField {
                    label.textColor = textColor
                }
            }
        }
    }

}