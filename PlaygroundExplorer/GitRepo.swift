import Foundation

enum GitError {
    case None
    case Error
    case NotFound
    case Exists
    case Ambiguous
    case Bufs
    case User
    case BareRepo
    case UnbornBranch
    case UnMerged
    case NonFastForward
    case InvalidSpec
    case MergeConflict
    case Locked
    case Modified
    case Auth
    case Certificate
    case Applied
    case Peel
    case Passthrough
    case IterationOver
}

class GitHelper {
    
    class func printVersion() {
        let initRC = git_libgit2_init()
        
        var major : Int32 = 0
        var minor : Int32 = 0
        var rev : Int32 = 0
        git_libgit2_version(&major, &minor, &rev)
        
        println("libgit2 version: \(major).\(minor).\(rev)")
        
        let shutdowRC = git_libgit2_shutdown()
    }
    
    class func translateReturnCode(rc:Int32) -> GitError {
        
        switch(rc) {
            
        case GIT_OK.value:
            return .None
            
        case GIT_ERROR.value:
            return .Error
        case GIT_ENOTFOUND.value:
            return .NotFound
        case GIT_EEXISTS.value:
            return .Exists
        case GIT_EAMBIGUOUS.value:
            return .Ambiguous
        case GIT_EBUFS.value:
            return .Bufs
        case GIT_EUSER.value:
            return .User
        case GIT_EBAREREPO.value:
            return .BareRepo
        case GIT_EUNBORNBRANCH.value:
            return .UnbornBranch
        case GIT_EUNMERGED.value:
            return .UnMerged
        case GIT_ENONFASTFORWARD.value:
            return .NonFastForward
        case GIT_EINVALIDSPEC.value:
            return .InvalidSpec
        case GIT_EMERGECONFLICT.value:
            return .MergeConflict
        case GIT_ELOCKED.value:
            return .Locked
        case GIT_EMODIFIED.value:
            return .Modified
        case GIT_EAUTH.value:
            return .Auth
        case GIT_ECERTIFICATE.value:
            return .Certificate
        case GIT_EAPPLIED.value:
            return .Applied
        case GIT_EPEEL.value:
            return .Peel
        case GIT_PASSTHROUGH.value:
            return .Passthrough
        case GIT_ITEROVER.value:
            return .IterationOver
            
        default:
            return .Error
            
        }
        
    }
    
}

class GitRepo {
    
    var repoInternal: COpaquePointer = nil
    
    deinit {
        git_repository_free(repoInternal)
        
        git_libgit2_shutdown()
    }
    
    func open(repoName:String) -> GitError {
        let initRC = git_libgit2_init()
        if initRC <= 0 {
            return GitHelper.translateReturnCode(initRC)
        }
        
        let repoOpenRC = git_repository_open(&repoInternal, "\(repoName)/.git")
        return GitHelper.translateReturnCode(repoOpenRC)
    }
    
    func cloneAndOpen(remoteName:String, localName:String) -> GitError {
        let initRC = git_libgit2_init()
        if initRC <= 0 {
            return GitHelper.translateReturnCode(initRC)
        }
        
        let opts = UnsafeMutablePointer<git_clone_options>.alloc(1)
        git_clone_init_options(opts, UInt32(GIT_CLONE_OPTIONS_VERSION))

        let errorCode = git_clone(&repoInternal, remoteName, localName, opts)
        opts.dealloc(1)
        if errorCode != GIT_OK.value {
            return GitHelper.translateReturnCode(errorCode)
        }
        
        return .None
    }
    
    func pull() -> GitError {
        
        let remote = GitRemote(repo: self)
        let remoteOpenError = remote.popuplateFromLookup("origin")
        if remoteOpenError != .None {
            return remoteOpenError
        }
        
        let remoteFetchError = remote.fetch()
        if remoteFetchError != .None {
            return remoteFetchError
        }
        
        let remoteMasterReference = GitReference(repo: self)
        let remoteReferenceError = remoteMasterReference.popuplateFromLookup("refs/remotes/origin/master")
        if remoteReferenceError != .None {
            return remoteReferenceError
        }
        
        let remoteHEAD = GitAnnotatedCommit(repo: self)
        let remoteHEADRC = remoteHEAD.populateFromReference(remoteMasterReference)
        if remoteHEADRC != .None {
            return remoteHEADRC
        }
        
        var commitTree: GitCommitTree?
        let commitTreeRC = remoteHEAD.getCommitTree(&commitTree)
        if commitTreeRC != .None {
            return commitTreeRC
        }
        if commitTree == nil {
            return .Error
        }
        
        let checkoutOpts = UnsafeMutablePointer<git_checkout_options>.alloc(1)
        git_checkout_init_options(checkoutOpts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        checkoutOpts.memory.checkout_strategy = GIT_CHECKOUT_FORCE.value | GIT_CHECKOUT_ALLOW_CONFLICTS.value
        
        let checkoutTreeRC = git_checkout_tree(repoInternal, commitTree!.commitTreeInternal.memory, checkoutOpts)
        checkoutOpts.dealloc(1)
        if checkoutTreeRC != GIT_OK.value {
            return GitHelper.translateReturnCode(checkoutTreeRC)
        }
        
        var commitRef = UnsafeMutablePointer<COpaquePointer>.alloc(1)
        let refCreateRC = git_reference_create(commitRef, repoInternal, "refs/heads/master", remoteHEAD.getOid(), 1, nil)
        git_reference_free(commitRef.memory)
        commitRef.dealloc(1)
        if refCreateRC != GIT_OK.value {
            return GitHelper.translateReturnCode(refCreateRC)
        }
        
        return .None
    
    }
    
    func getRevisionWalker() -> GitRevisionWalker? {
        
        var revWalkerRef = UnsafeMutablePointer<COpaquePointer>.alloc(1)
        let revwalkNewRC = git_revwalk_new(revWalkerRef, self.repoInternal)
        if revwalkNewRC == GIT_OK.value {
            git_revwalk_sorting(revWalkerRef.memory, GIT_SORT_TOPOLOGICAL.value | GIT_SORT_TIME.value)
            git_revwalk_push_head(revWalkerRef.memory)
            
            return GitRevisionWalker(repo: self, revWalker: revWalkerRef)
        }
        
        return nil
    }
}

class GitRemote {
    
    private var repo: GitRepo!
    private var remoteInternal: COpaquePointer
    
    deinit {
        git_remote_free(remoteInternal)
    }
    
    init(repo:GitRepo) {
        self.repo = repo
        self.remoteInternal = nil
    }
    
    func popuplateFromLookup(name:String) -> GitError {
        let remoteLookupRC = git_remote_lookup(&remoteInternal, repo.repoInternal, name)
        return GitHelper.translateReturnCode(remoteLookupRC)
    }

    func fetch() -> GitError {
        let fetchRC = git_remote_fetch(remoteInternal, nil, nil)
        return GitHelper.translateReturnCode(fetchRC)
    }
    
}

class GitReference {
    
    private var repo: GitRepo!
    var referenceInternal: COpaquePointer
    
    deinit {
        git_reference_free(referenceInternal)
    }
    
    init(repo:GitRepo) {
        self.repo = repo
        self.referenceInternal = nil
    }
    
    func popuplateFromLookup(name:String) -> GitError {
        let referenceLookupRC = git_reference_lookup(&referenceInternal, repo.repoInternal, name)
        return GitHelper.translateReturnCode(referenceLookupRC)
    }
    
}

class GitAnnotatedCommit {
    
    private var repo: GitRepo!
    private var annotatedCommitInternal: COpaquePointer
    
    deinit {
        git_annotated_commit_free(annotatedCommitInternal)
    }
    
    init(repo:GitRepo) {
        self.repo = repo
        self.annotatedCommitInternal = nil
    }
    
    func populateFromReference(reference:GitReference) -> GitError {
        let annotatedCommitRC = git_annotated_commit_from_ref(&annotatedCommitInternal, repo.repoInternal, reference.referenceInternal)
        return GitHelper.translateReturnCode(annotatedCommitRC)
    }
    
    func getOid() -> UnsafePointer<git_oid> {
        return git_annotated_commit_id(annotatedCommitInternal)
    }
    
    func getCommitTree(inout commitTreeResponse:GitCommitTree?) -> GitError {
        let commitOid = git_annotated_commit_id(annotatedCommitInternal)
        
        let headCommit = UnsafeMutablePointer<COpaquePointer>.alloc(1)
        var objectLookupRC = git_object_lookup(headCommit, repo.repoInternal, commitOid, GIT_OBJ_COMMIT)
        if objectLookupRC != GIT_OK.value {
            git_object_free(headCommit.memory)
            headCommit.dealloc(1)
            return GitHelper.translateReturnCode(objectLookupRC)
        }
        
        var commitTree = UnsafeMutablePointer<COpaquePointer>.alloc(1)
        var commitTreeRC = git_commit_tree(commitTree, headCommit.memory)
        if commitTreeRC != GIT_OK.value {
            git_tree_free(commitTree.memory)
            commitTree.dealloc(1)
            git_object_free(headCommit.memory)
            headCommit.dealloc(1)
            return GitHelper.translateReturnCode(commitTreeRC)
        }
        
        commitTreeResponse = GitCommitTree(commitTree:commitTree)
        
        git_object_free(headCommit.memory)
        headCommit.dealloc(1)
        
        return .None
    }
    
}

class GitCommitTree {
    
    private var commitTreeInternal:UnsafeMutablePointer<COpaquePointer>!
    
    deinit {
        git_tree_free(commitTreeInternal.memory)
        commitTreeInternal.dealloc(1)
    }

    init(commitTree:UnsafeMutablePointer<COpaquePointer>) {
        commitTreeInternal = commitTree
    }
    
}

class GitCommit {
    
    private var commitInternal:UnsafeMutablePointer<COpaquePointer>!
    
    deinit {
        git_commit_free(commitInternal.memory)
        commitInternal.dealloc(1)
    }
    
    init(commit:UnsafeMutablePointer<COpaquePointer>) {
        self.commitInternal = commit
    }
    
    func getParentCount() -> Int {
        return Int(git_commit_parentcount(commitInternal.memory))
    }
    
    func getCommitHash() -> String? {
        let maxSize = count(GIT_OID_HEX_ZERO) + 1
        var cBuffer = UnsafeMutablePointer<CChar>.alloc(maxSize)
        
        let tostrRC = git_oid_tostr(cBuffer, maxSize, git_commit_id(commitInternal.memory))
        if tostrRC != nil {
            return String.fromCString(cBuffer)
        }
        
        return nil
    }
    
    func getCommitMessage() -> String? {
        
        let commitMessage = git_commit_message(commitInternal.memory)
        if commitMessage != nil {
            return String.fromCString(commitMessage)?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        }
        
        return nil
    }
    
    func getCommitTime() -> NSDate? {
        
        let commitAuthor = git_commit_author(commitInternal.memory)
        if commitAuthor != nil {
            return NSDate(timeIntervalSince1970: NSTimeInterval(commitAuthor.memory.when.time))
        }
        
        return nil
    }
    
    func getCommitTree(inout commitTreeResponse:GitCommitTree?) -> GitError {
        
        var commitTree = UnsafeMutablePointer<COpaquePointer>.alloc(1)
        var commitTreeRC = git_commit_tree(commitTree, self.commitInternal.memory)
        if commitTreeRC != GIT_OK.value {
            git_tree_free(commitTree.memory)
            commitTree.dealloc(1)
            println(commitTreeRC)
            return GitHelper.translateReturnCode(commitTreeRC)
        }
        
        commitTreeResponse = GitCommitTree(commitTree:commitTree)
        
        return .None
    }
}

class GitRevisionWalker {
    
    private var repo: GitRepo!
    private var revWalkerInternal:UnsafeMutablePointer<COpaquePointer>!
    
    deinit {
        git_revwalk_free(self.revWalkerInternal.memory)
        self.revWalkerInternal.dealloc(1)
    }
    
    init(repo:GitRepo, revWalker:UnsafeMutablePointer<COpaquePointer>) {
        self.repo = repo
        self.revWalkerInternal = revWalker
    }
    
    func nextCommit() -> GitCommit? {
        var oid = UnsafeMutablePointer<git_oid>.alloc(1)
        let revwalkNextRC = git_revwalk_next(oid, self.revWalkerInternal.memory)
        if revwalkNextRC == GIT_OK.value {
            
            var gitCommit = UnsafeMutablePointer<COpaquePointer>.alloc(1)
            
            let gitCommitLookupRC = git_commit_lookup(gitCommit, self.repo.repoInternal, oid)
            if gitCommitLookupRC == GIT_OK.value {
                oid.dealloc(1)
                return GitCommit(commit: gitCommit)
            }
            
        }
        return nil
    }
    
    func reset() {
        git_revwalk_reset(self.revWalkerInternal.memory)
        
        git_revwalk_sorting(self.revWalkerInternal.memory, GIT_SORT_TOPOLOGICAL.value | GIT_SORT_TIME.value)
        git_revwalk_push_head(self.revWalkerInternal.memory)
    }
    
    func getMatchingCommits(pathSpec:GitPathSpec, maxCount:Int) -> [GitCommit] {
        
        var matchingCommits = [GitCommit]()
        
        var count = 0
        while let nextCommit = self.nextCommit() {
            
            var commitTree: GitCommitTree?
            let commitTreeRC = nextCommit.getCommitTree(&commitTree)
            if commitTreeRC == .None {
                
                if pathSpec.inTree(commitTree) {
                    matchingCommits.append(nextCommit)
                }
                
            }
            
            count++
            if count >= maxCount {
                break
            }
        }
        
        return matchingCommits
    }
    
    func getFirstMatchingCommit(pathSpec:GitPathSpec) -> GitCommit? {
        
        let matchingCommits = self.getMatchingCommits(pathSpec, maxCount: 1)
        if matchingCommits.count > 0 {
            return matchingCommits[0]
        } else {
            return nil
        }
        
    }
    
}

class GitPathSpec {
    
    private var pathSpec = UnsafeMutablePointer<COpaquePointer>.alloc(1)
    
    private var pathStringCArray: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>
    private var count: Int
    private var gitStrArray = UnsafeMutablePointer<git_strarray>.alloc(1)
    
    deinit {
        git_pathspec_free(pathSpec.memory)
        pathSpec.dealloc(1)
        
        gitStrArray.dealloc(1)
        
        pathStringCArray.dealloc(count)
    }
    
    init(pathStrings:[String]) {
        self.count = pathStrings.count
        
        self.pathStringCArray = UnsafeMutablePointer<UnsafeMutablePointer<CChar>>.alloc(pathStrings.count)
        
        var index = 0
        for string in pathStrings {
            pathStringCArray[index] = UnsafeMutablePointer((string as NSString).UTF8String)
            index++
        }
        
        self.gitStrArray[0] = git_strarray(strings: pathStringCArray, count: pathStrings.count)
        
        git_pathspec_new(self.pathSpec, gitStrArray)
    }
    
    func inTree(commitTree:GitCommitTree?) -> Bool {
        if commitTree == nil {
            return false
        }
        let rc = git_pathspec_match_tree(nil, commitTree!.commitTreeInternal.memory, GIT_PATHSPEC_NO_MATCH_ERROR.value, self.pathSpec.memory)
        return rc >= 0
    }
    
}

