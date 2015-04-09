import Cocoa

class MainContainerViewController: NSViewController {
    
    @IBOutlet weak var statusLabel: NSTextField!
    
    private var statusNotification: NSObjectProtocol?
    
    deinit {
        if self.statusNotification != nil {
            NSNotificationCenter.defaultCenter().removeObserver(self.statusNotification!)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.statusNotification = NSNotificationCenter.defaultCenter().addObserverForName(Config.Notification.StatusUpdate, object: nil, queue: NSOperationQueue.mainQueue()) { (notification:NSNotification!) -> Void in
        
            if notification.userInfo != nil {
                if let statusNotification = notification.userInfo!["statusNotification"] as? StatusNotification {
                    
                    if statusNotification.message != nil {
                        self.statusLabel.stringValue = statusNotification.message!
                    } else {
                        self.statusLabel.stringValue = ""
                    }
                    
                }
            }
            
        }
    }
    
}
