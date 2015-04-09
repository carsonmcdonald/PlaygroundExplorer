import Foundation

struct Config {
    struct Notification {
        static let StatusUpdate = "kStatusUpdateNotification"
        static let BrowsePlaygroundSelected = "kBrowsePlaygroundSelectedNotification"
    }
    
    struct Directory {
        static let SourcePlaygroundDataRepo =  "https://github.com/carsonmcdonald/PlaygroundExplorerRegistry.git"
    }
}