import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidBecomeActive(notification: NSNotification) {

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let titlebarController = storyboard?.instantiateControllerWithIdentifier("TitlebarStatusViewController") as? TitlebarStatusViewController {
            NSApplication.sharedApplication().mainWindow?.addTitlebarAccessoryViewController(titlebarController)
            NSApplication.sharedApplication().mainWindow?.titlebarAppearsTransparent = true
        }
        
    }

}

