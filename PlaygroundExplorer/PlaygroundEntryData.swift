import Foundation

struct PlaygroundEntryRepoData {
    var commitDateTime: NSDate?
    var commitHash: String?
    var commitMessage: String?
}

class PlaygroundEntryData {
    
    var ident: String!
    var name: String!
    var playgroundDir: String!
    var author: String!
    var longDescription: String!
    var location: String!
    var locationType: String!
    var minXcodeVersion: XcodeVersion!
    var moreInfoLink: String?
    var tags: [String]?
    var repoDataList: [PlaygroundEntryRepoData]?
    
    init?(jsonData:NSDictionary) {
        
        if jsonData["description"] == nil {
            return nil
        }

        if jsonData["playground_dir"] == nil {
            return nil
        }
        
        if jsonData["location"] == nil {
            return nil
        }
        
        if jsonData["location_type"] == nil {
            return nil
        }
        
        if jsonData["min_xcode_version"] == nil {
            return nil
        }
        
        if jsonData["name"] == nil {
            return nil
        }
        
        if jsonData["author"] == nil {
            return nil
        }
        
        if jsonData["location"] == nil {
            return nil
        }
        
        if let name = jsonData["name"] as! String! {
            self.name = name
        } else {
            return nil
        }
        
        if let dir = jsonData["playground_dir"] as! String! {
            self.playgroundDir = dir
        } else {
            return nil
        }
        
        
        if let author = jsonData["author"] as! String! {
            self.author = author
        } else {
            return nil
        }
        
        if let longDescription = jsonData["description"] as! String! {
            self.longDescription = longDescription
        } else {
            return nil
        }
        
        if let location = jsonData["location"] as! String! {
            self.location = location
        } else {
            return nil
        }
        
        if let locationType = jsonData["location_type"] as! String! {
            self.locationType = locationType
        } else {
            return nil
        }
        
        if let minXcodeVersion = jsonData["min_xcode_version"] as! String! {
            self.minXcodeVersion = XcodeVersion(fromFullVersionString:minXcodeVersion)
        } else {
            return nil
        }
        
        self.moreInfoLink = jsonData["more_info_link"] as! String?
        self.tags = jsonData["tags"] as! [String]?

        self.ident = self.generateMD5Hash(self.location)
        
    }
    
    func tagsAsString() -> String {
        if self.tags == nil {
            return ""
        } else {
            return ", ".join(self.tags!)
        }
    }
    
    func lastUpdatedTime() -> NSDate? {
        if self.repoDataList != nil && self.repoDataList!.count > 0 {
            return self.repoDataList![0].commitDateTime
        }
        return nil
    }
    
    private func generateMD5Hash(input:String) -> String {
        let str = input.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = CC_LONG(input.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        
        CC_MD5(str!, strLen, result)
        
        var hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.dealloc(digestLen)
        
        return String(format: hash as String)
    }
    
}
