import Cocoa

enum FinderService {
    static func copySelectedPaths() {
        let permissionStatus = FinderPermissionChecker.requestAutomationPermissionToFinder()
        if permissionStatus == -1743 {
            FinderPermissionChecker.showPermissionAlert()
            return
        }

        let (paths, errorInfo) = getFinderSelection()

        if let errorInfo,
           let errorNumber = errorInfo["NSAppleScriptErrorNumber"] as? Int,
           errorNumber == -1743 {
            FinderPermissionChecker.showPermissionAlert()
            return
        }

        guard let paths, !paths.isEmpty else {
            NotificationService.showMessage(title: "No selection", body: "No files selected in Finder")
            return
        }

        ClipboardService.copyPath(paths)
        NotificationService.showMessage(title: "Path copied", body: paths)
    }

    private static func getFinderSelection() -> (paths: String?, errorInfo: NSDictionary?) {
        let script = """
        tell application "Finder"
            if selection is {} then return ""
            set selectedItems to selection
            set pathList to {}
            repeat with i in selectedItems
                set end of pathList to POSIX path of (i as alias)
            end repeat
            set AppleScript's text item delimiters to linefeed
            return pathList as string
        end tell
        """

        var errorInfo: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return (nil, nil)
        }

        let result = appleScript.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            print("AppleScript error: \(error)")
            return (nil, error)
        }

        return (result.stringValue, nil)
    }
}
