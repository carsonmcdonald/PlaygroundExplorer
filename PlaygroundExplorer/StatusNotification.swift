import Foundation

class StatusNotification {
    
    var message: String?
    
    class func broadcastStatus(statusMessage:String) {
        let status = StatusNotification()
        status.message = statusMessage
        NSNotificationCenter.defaultCenter().postNotificationName(Config.Notification.StatusUpdate, object: self, userInfo: ["statusNotification":status])
    }
    
}