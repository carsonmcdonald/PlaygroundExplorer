import Cocoa

class Utils {
    
    class func getPlaygroundRoot() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)
        let appDirectoryPath = paths.first as! String
        let playgroundRepoDirectory = appDirectoryPath
            .stringByAppendingPathComponent("PlaygroundExplorer")
        
        let fileManager = NSFileManager.defaultManager()
        var error: NSErrorPointer = nil
        if fileManager.createDirectoryAtPath(playgroundRepoDirectory, withIntermediateDirectories: true, attributes: nil, error: error) {
            return playgroundRepoDirectory
        } else {
            return nil
        }
    }
    
    class func getPlaygroundsDirectory() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)
        let appDirectoryPath = paths.first as! String
        let playgroundRepoDirectory = appDirectoryPath
            .stringByAppendingPathComponent("PlaygroundExplorer")
            .stringByAppendingPathComponent("Playgrounds")
        
        let fileManager = NSFileManager.defaultManager()
        var error: NSErrorPointer = nil
        if fileManager.createDirectoryAtPath(playgroundRepoDirectory, withIntermediateDirectories: true, attributes: nil, error: error) {
            return playgroundRepoDirectory
        } else {
            return nil
        }
    }
    
    class func getPlaygroundRepoDirectory() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)
        let appDirectoryPath = paths.first as! String
        let playgroundRepoDirectory = appDirectoryPath
            .stringByAppendingPathComponent("PlaygroundExplorer")
            .stringByAppendingPathComponent("PlaygroundRepo")
        
        let fileManager = NSFileManager.defaultManager()
        var error: NSErrorPointer = nil
        if fileManager.createDirectoryAtPath(playgroundRepoDirectory, withIntermediateDirectories: true, attributes: nil, error: error) {
            return playgroundRepoDirectory
        } else {
            return nil
        }
    }
    
    
    class func syncXcodeVersions(xcodeVersions:[XcodeVersion]) {
        if let rootDir = Utils.getPlaygroundRoot() {
            NSKeyedArchiver.archiveRootObject(xcodeVersions, toFile: rootDir.stringByAppendingPathComponent("xcodeversions.plist"))
        }
    }
    
    class func loadXcodeVersions() -> [XcodeVersion] {
        if let rootDir = Utils.getPlaygroundRoot() {
            if let versions =  NSKeyedUnarchiver.unarchiveObjectWithFile(rootDir.stringByAppendingPathComponent("xcodeversions.plist")) as? [XcodeVersion] {
                return versions
            }
        }
        return []
    }
    
    class func findCompatibleXcodeVersionPath(minXcodeVersion:XcodeVersion) -> String? {
        let installedXcodeVersions = loadXcodeVersions()
        for installedXcodeVersion in installedXcodeVersions {
            if installedXcodeVersion.isLargerThan(minXcodeVersion) {
                return installedXcodeVersion.xcodePath
            }
        }
        return nil
    }
    
    class func showErrorAlert(errorMessage:String) {
        let alert = NSAlert()
        alert.informativeText = errorMessage
        alert.messageText = "Error"
        alert.showsHelp = false
        alert.runModal()
    }
    
    class func cloneOrUpdatePlaygroundData() {
        
        let sourceRepo = Config.Directory.SourcePlaygroundDataRepo
        let playgroundRepo = Utils.getPlaygroundRepoDirectory()
        
        if playgroundRepo == nil {
            Utils.showErrorAlert("Error creating repo directory")
        } else {
            
            let gitRepo = GitRepo()
            
            let files = NSFileManager.defaultManager().contentsOfDirectoryAtPath(playgroundRepo!, error: nil)
            if files?.count == 0 {
                let openError = gitRepo.cloneAndOpen(sourceRepo, localName:playgroundRepo!)
                if openError != .None {
                    Utils.showErrorAlert("Error cloning repo: \(openError.hashValue)")
                }
            } else {
                let openError = gitRepo.open(playgroundRepo!)
                if openError != .None {
                    Utils.showErrorAlert("Error opening repo: \(openError.hashValue)")
                } else {
                    let updateError = gitRepo.pull()
                    if updateError != .None {
                        Utils.showErrorAlert("Error updating repo: \(updateError.hashValue)")
                    }
                }
            }
            
        }
        
    }
    
    class func getRepoInformationFromPlaygroundData() -> [String:[PlaygroundEntryRepoData]] {
        
        var playgroundRepoData = [String:[PlaygroundEntryRepoData]]()
        
        let sourceRepo = Config.Directory.SourcePlaygroundDataRepo
        let playgroundRepo = Utils.getPlaygroundRepoDirectory()
        
        if playgroundRepo == nil {
            Utils.showErrorAlert("Error creating repo directory")
        } else {
            
            let gitRepo = GitRepo()
            
            let files = NSFileManager.defaultManager().contentsOfDirectoryAtPath(playgroundRepo!, error: nil)
            if files?.count > 0 {
                let openError = gitRepo.open(playgroundRepo!)
                if openError != .None {
                    Utils.showErrorAlert("Error opening repo: \(openError.hashValue)")
                } else {
                    
                    let revisionWalker = gitRepo.getRevisionWalker()
                    if revisionWalker == nil {
                        Utils.showErrorAlert("Can not walk revisions")
                    } else {
                        
                        for file in files! {
                            let filename = file as! String
                            if let range = filename.rangeOfString(".json") {
                                if range.endIndex == filename.endIndex {
                                    
                                    playgroundRepoData[filename] = [PlaygroundEntryRepoData]()
                                    
                                    let pathSpec = GitPathSpec(pathStrings: [filename])
                                    
                                    if let revisions = revisionWalker?.getMatchingCommits(pathSpec, maxCount: 5) {
                                        for rev in revisions {
                                            let entryRepoData = PlaygroundEntryRepoData(commitDateTime: rev.getCommitTime(), commitHash: rev.getCommitHash(), commitMessage: rev.getCommitMessage())
                                            playgroundRepoData[filename]?.append(entryRepoData)
                                        }
                                    }
                                    
                                }
                            }
                            revisionWalker?.reset()
                        }
                        
                    }
                    
                }
            }
            
        }
        
        return playgroundRepoData
    }

}