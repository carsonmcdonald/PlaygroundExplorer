import Foundation

class XcodeVersion: NSObject, NSCoding {
    var bundleVersionString: String = "" {
        didSet {
            self.fullVersion = "\(self.bundleVersionString)-\(self.buildVersion)"
        }
    }
    var buildVersion: String = "" {
        didSet {
            self.fullVersion = "\(self.bundleVersionString)-\(self.buildVersion)"
        }
    }
    var xcodePath: String = ""
    
    var fullVersion: String = "" {
        didSet {
            self.parseVersion()
        }
    }
    private var majorVersionNumber = 9999
    private var minorVersionNumber = 9999
    private var subVersionNumber = 9999
    private var buildVersionNumber = 9999
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(bundleVersionString, forKey: "bundleVersionString")
        aCoder.encodeObject(buildVersion, forKey: "buildVersion")
        aCoder.encodeObject(xcodePath, forKey: "xcodePath")
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init()
        
        self.bundleVersionString = aDecoder.decodeObjectForKey("bundleVersionString") as! String
        self.buildVersion = aDecoder.decodeObjectForKey("buildVersion") as! String
        self.xcodePath = aDecoder.decodeObjectForKey("xcodePath") as! String
        
        self.fullVersion = "\(self.bundleVersionString)-\(self.buildVersion)"
        self.parseVersion()
    }
    
    init(fromFullVersionString:String) {
        super.init()
        
        self.fullVersion = fromFullVersionString
        self.parseVersion()
    }
    
    override init() {
    }
    
    func isLargerThan(otherVersion:XcodeVersion) -> Bool {
        if self.majorVersionNumber > otherVersion.majorVersionNumber {
            return true
        }
        
        if self.majorVersionNumber == otherVersion.majorVersionNumber &&
           self.minorVersionNumber > otherVersion.minorVersionNumber {
            return true
        }
        
        if self.majorVersionNumber == otherVersion.majorVersionNumber &&
           self.minorVersionNumber == otherVersion.minorVersionNumber &&
           self.subVersionNumber > otherVersion.subVersionNumber {
                return true
        }
        if self.majorVersionNumber == otherVersion.majorVersionNumber &&
           self.minorVersionNumber == otherVersion.minorVersionNumber &&
           self.subVersionNumber == otherVersion.subVersionNumber &&
           self.buildVersionNumber > otherVersion.buildVersionNumber {
                return true
        }
        
        return false
    }
    
    private func parseVersion() {
        let versionRegex = NSRegularExpression(pattern: "(\\d)\\.(\\d)(\\.(\\d))?-(\\d)", options: NSRegularExpressionOptions.allZeros, error: nil)
        let matches = versionRegex?.matchesInString(self.fullVersion, options: NSMatchingOptions.allZeros, range: NSMakeRange(0, self.fullVersion.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)))
        
        self.majorVersionNumber = 9999
        self.minorVersionNumber = 9999
        self.subVersionNumber = 9999
        self.buildVersionNumber = 9999
        
        if matches?.count >= 1 {
            if let matchesTCR = matches as? [NSTextCheckingResult] {
                let versionNS = self.fullVersion as NSString
                let match = matchesTCR[0]
                if match.numberOfRanges == 6 {
                    let majorRange = match.rangeAtIndex(1)
                    if majorRange.location != NSNotFound  {
                        if let value = versionNS.substringWithRange(majorRange).toInt() {
                            self.majorVersionNumber = value
                        }
                    }
                    let minorRange = match.rangeAtIndex(2)
                    if minorRange.location != NSNotFound  {
                        if let value = versionNS.substringWithRange(minorRange).toInt() {
                            self.minorVersionNumber = value
                        }
                    }
                    let subRange = match.rangeAtIndex(4)
                    if subRange.location != NSNotFound  {
                        if let value = versionNS.substringWithRange(subRange).toInt() {
                            self.subVersionNumber = value
                        }
                    } else {
                        self.subVersionNumber = 0
                    }
                    let buildRange = match.rangeAtIndex(5)
                    if buildRange.location != NSNotFound  {
                        if let value = versionNS.substringWithRange(buildRange).toInt() {
                            self.buildVersionNumber = value
                        }
                    }
                } else {
                    Utils.showErrorAlert("\(self.fullVersion) was not a valid format")
                }
            } else {
                Utils.showErrorAlert("\(self.fullVersion) was not a valid format")
            }
        }
    }
}
