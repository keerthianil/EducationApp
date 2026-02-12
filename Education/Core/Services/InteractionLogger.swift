//
//  InteractionLogger.swift
//  Education
//
//  Data logging service for user interaction tracking
//  Logs gestures, events, and accessibility interactions per flow
//
//  NOTE: Excel export (XLSX) uses ZipFoundation.
//  Added via SPM: https://github.com/weichsel/ZIPFoundation

import Foundation
import UIKit
import SwiftUI
import Combine
import ZIPFoundation

// MARK: - Interaction Event Types

enum TouchEventType: String {
    case touchDown = "Touch Down"
    case touchMove = "Touch Move"
    case touchUp = "Touch Up"
    case tap = "Tap"
    case doubleTap = "Double Tap"
    case longPress = "Long Press"
    case swipeLeft = "Swipe Left"
    case swipeRight = "Swipe Right"
    case swipeUp = "Swipe Up"
    case swipeDown = "Swipe Down"
    case threeFingerSwipe = "3-Finger Swipe"
    case twoFingerSwipe = "2-Finger Swipe"
    case pinch = "Pinch"
    case pan = "Pan"
    
    // VoiceOver specific
    case voFocus = "VO Focus"
    case voActivate = "VO Activate"
    case voEscape = "VO Escape"
    case voScroll = "VO Scroll"
    case voRotorChange = "VO Rotor Change"
    case voMagicTap = "VO Magic Tap"
    case voAnnouncement = "VO Announcement"
    
    // App specific
    case pageChange = "Page Change"
    case screenTransition = "Screen Transition"
    case mathModeEnter = "Math Mode Enter"
    case mathModeExit = "Math Mode Exit"
    case mathNavigate = "Math Navigate"
    case mathLevelChange = "Math Level Change"
    case uploadStart = "Upload Start"
    case uploadConfirm = "Upload Confirm"
    case uploadComplete = "Upload Complete"
    case tabChange = "Tab Change"
    case menuOpen = "Menu Open"
    case menuClose = "Menu Close"
    case documentOpen = "Document Open"
    case documentClose = "Document Close"
    case sessionStart = "Session Start"
    case sessionEnd = "Session End"
    case screenDurationSummary = "Screen Duration"
    case idleTime = "Idle Time"
}

enum ObjectType: String {
    case button = "Button"
    case tab = "Tab"
    case card = "Card"
    case listRow = "List Row"
    case mathEquation = "Math Equation"
    case heading = "Heading"
    case paragraph = "Paragraph"
    case image = "Image"
    case svg = "SVG"
    case background = "Background"
    case navigationBar = "Navigation Bar"
    case uploadArea = "Upload Area"
    case fileCard = "File Card"
    case processingCard = "Processing Card"
    case banner = "Banner"
    case pageControl = "Page Control"
    case textField = "Text Field"
    case menu = "Menu"
    case dialog = "Dialog"
    case scrollView = "Scroll View"
    case webView = "Web View"
    case document = "Document"
    case session = "Session"
    case unknown = "Unknown"
}

enum RotorFunction: String {
    case none = "None"
    case headings = "Headings"
    case links = "Links"
    case formControls = "Form Controls"
    case containers = "Containers"
    case characters = "Characters"
    case words = "Words"
    case lines = "Lines"
    case mathNavigation = "Math Navigation"
    case adjustValue = "Adjust Value"
}

// MARK: - Interaction Log Entry

struct InteractionLogEntry: Codable {
    let timeStamp: String           // Absolute time (HH:mm:ss.S)
    let trialTime: String           // Relative time from session start (mm:ss.S)
    let touchEvent: String          // Event type
    let objectType: String          // Type of UI element
    let objectLabel: String         // Accessibility label or identifier
    let touchX: Double              // X coordinate
    let touchY: Double              // Y coordinate
    let condition: String           // Flow 1, Flow 2, or Flow 3
    let screenName: String          // Current screen/view name
    let rotorFunction: String       // VoiceOver rotor setting
    let additionalInfo: String      // Extra context
    
    var csvRow: String {
        let escapedLabel = objectLabel.replacingOccurrences(of: "\"", with: "\"\"")
        let escapedInfo = additionalInfo.replacingOccurrences(of: "\"", with: "\"\"")
        return "\(timeStamp),\(trialTime),\(touchEvent),\(objectType),\"\(escapedLabel)\",\(touchX),\(touchY),\(condition),\(screenName),\(rotorFunction),\"\(escapedInfo)\""
    }
    
    static var csvHeader: String {
        return "Time Stamp,Trial Time,Touch Event,Object Type,Object Label,Touch X,Touch Y,Condition,Screen Name,Rotor Function,Additional Info"
    }
}

// MARK: - Interaction Logger Service

final class InteractionLogger: ObservableObject {
    static let shared = InteractionLogger()
    
    @Published private(set) var isLogging: Bool = false
    @Published private(set) var currentFlow: Int = 1
    @Published private(set) var entryCount: Int = 0
    
    private var sessionStartTime: Date?
    private var entries: [Int: [InteractionLogEntry]] = [1: [], 2: [], 3: []]
    private var currentRotorFunction: RotorFunction = .none
    private var currentScreenName: String = "Unknown"
    
    // Screen duration tracking
    private var screenEntryTimes: [String: Date] = [:]
    private var screenDurations: [Int: [String: TimeInterval]] = [1: [:], 2: [:], 3: [:]]
    private var currentScreenEntryTime: Date?
    
    // Idle time tracking
    private var lastInteractionTime: Date?
    private let idleThreshold: TimeInterval = 5.0
    
    // Currently open document
    private var currentDocumentTitle: String?
    private var documentOpenTime: Date?
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.S"
        return df
    }()
    
    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "com.stemalley.interactionlogger", qos: .utility)
    
    private init() {
        setupAccessibilityObservers()
    }
    
    // MARK: - Session Management
    
    func startSession(flow: Int) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.currentFlow = flow
                self.sessionStartTime = Date()
                self.isLogging = true
                self.entryCount = self.entries[flow]?.count ?? 0
                self.lastInteractionTime = Date()
                self.currentScreenEntryTime = Date()
            }
            
            let voStatus = UIAccessibility.isVoiceOverRunning ? "ON" : "OFF"
            let deviceModel = UIDevice.current.model
            let systemVersion = UIDevice.current.systemVersion
            let screenSize = "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))"
            
            self.logInternal(
                event: .sessionStart,
                objectType: .session,
                label: "Session Started",
                location: .zero,
                additionalInfo: "Flow \(flow) | VoiceOver: \(voStatus) | Device: \(deviceModel) | iOS \(systemVersion) | Screen: \(screenSize)"
            )
        }
        
        print("[InteractionLogger] Session started for Flow \(flow)")
    }
    
    func endSession() {
        guard isLogging else { return }
        
        recordCurrentScreenDuration()
        
        if let docTitle = currentDocumentTitle {
            logDocumentClose(title: docTitle)
        }
        
        if let durations = screenDurations[currentFlow] {
            for (screen, duration) in durations.sorted(by: { $0.key < $1.key }) {
                log(
                    event: .screenDurationSummary,
                    objectType: .session,
                    label: screen,
                    location: .zero,
                    additionalInfo: "Total duration: \(String(format: "%.1f", duration))s"
                )
            }
        }
        
        let totalDuration: String
        if let start = sessionStartTime {
            let seconds = Date().timeIntervalSince(start)
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            totalDuration = "\(mins)m \(secs)s"
        } else {
            totalDuration = "unknown"
        }
        
        log(
            event: .sessionEnd,
            objectType: .session,
            label: "Session Ended",
            location: .zero,
            additionalInfo: "Flow \(currentFlow) | Total duration: \(totalDuration) | Entries: \(entryCount)"
        )
        
        isLogging = false
        print("[InteractionLogger] Session ended for Flow \(currentFlow) with \(entryCount) entries")
    }
    
    func setCurrentScreen(_ screenName: String) {
        let previousScreen = currentScreenName
        
        if previousScreen != screenName {
            recordCurrentScreenDuration()
        }
        
        currentScreenName = screenName
        currentScreenEntryTime = Date()
        
        if previousScreen != screenName && isLogging {
            log(
                event: .screenTransition,
                objectType: .background,
                label: screenName,
                location: .zero,
                additionalInfo: "From: \(previousScreen)"
            )
        }
    }
    
    private func recordCurrentScreenDuration() {
        guard let entryTime = currentScreenEntryTime else { return }
        let duration = Date().timeIntervalSince(entryTime)
        let screen = currentScreenName
        let flow = currentFlow
        
        if screenDurations[flow] == nil {
            screenDurations[flow] = [:]
        }
        screenDurations[flow]?[screen, default: 0] += duration
    }
    
    // MARK: - Document Open/Close
    
    func logDocumentClose(title: String) {
            guard currentDocumentTitle != nil else { return }
            
            let duration: String
            if let openTime = documentOpenTime {
                let seconds = Date().timeIntervalSince(openTime)
                duration = String(format: "%.1f", seconds) + "s"
            } else {
                duration = "unknown"
            }
            
            log(
                event: .documentClose,
                objectType: .document,
                label: title,
                location: .zero,
                additionalInfo: "Document closed | Duration: \(duration)"
            )
            
            // Clear immediately so second call is no-op
            currentDocumentTitle = nil
            documentOpenTime = nil
        }


        func logDocumentOpen(title: String) {
            // If same document already open, don't log again
            if currentDocumentTitle == title { return }
            
            // If different document was open, close it first
            if let prevTitle = currentDocumentTitle {
                logDocumentClose(title: prevTitle)
            }
            
            currentDocumentTitle = title
            documentOpenTime = Date()
            log(
                event: .documentOpen,
                objectType: .document,
                label: title,
                location: .zero,
                additionalInfo: "Document opened"
            )
        }
    
    // MARK: - Logging Methods
    
    func log(
        event: TouchEventType,
        objectType: ObjectType,
        label: String,
        location: CGPoint,
        rotorFunction: RotorFunction? = nil,
        additionalInfo: String = ""
    ) {
        logQueue.async { [weak self] in
            self?.logInternal(
                event: event,
                objectType: objectType,
                label: label,
                location: location,
                rotorFunction: rotorFunction,
                additionalInfo: additionalInfo
            )
        }
    }
    
    private func logInternal(
        event: TouchEventType,
        objectType: ObjectType,
        label: String,
        location: CGPoint,
        rotorFunction: RotorFunction? = nil,
        additionalInfo: String = ""
    ) {
        guard isLogging, let startTime = sessionStartTime else { return }
        
        let now = Date()
        let timeStamp = dateFormatter.string(from: now)
        let trialTime = formatTrialTime(from: startTime, to: now)
        let rotor = rotorFunction ?? currentRotorFunction
        
        // Check for idle time gap
        if let lastTime = lastInteractionTime {
            let gap = now.timeIntervalSince(lastTime)
            if gap >= idleThreshold {
                let idleEntry = InteractionLogEntry(
                    timeStamp: timeStamp,
                    trialTime: trialTime,
                    touchEvent: TouchEventType.idleTime.rawValue,
                    objectType: ObjectType.background.rawValue,
                    objectLabel: "Idle",
                    touchX: 0,
                    touchY: 0,
                    condition: "Flow \(currentFlow)",
                    screenName: currentScreenName,
                    rotorFunction: RotorFunction.none.rawValue,
                    additionalInfo: "Idle for \(String(format: "%.1f", gap))s"
                )
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.entries[self.currentFlow, default: []].append(idleEntry)
                }
            }
        }
        lastInteractionTime = now
        
        let entry = InteractionLogEntry(
            timeStamp: timeStamp,
            trialTime: trialTime,
            touchEvent: event.rawValue,
            objectType: objectType.rawValue,
            objectLabel: label,
            touchX: round(location.x * 10) / 10,
            touchY: round(location.y * 10) / 10,
            condition: "Flow \(currentFlow)",
            screenName: currentScreenName,
            rotorFunction: rotor.rawValue,
            additionalInfo: additionalInfo
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entries[self.currentFlow, default: []].append(entry)
            self.entryCount = self.entries[self.currentFlow]?.count ?? 0
        }
        
        #if DEBUG
        print("[Log] \(timeStamp) | \(event.rawValue) | \(objectType.rawValue) | \(label)")
        #endif
    }
    
    // MARK: - Convenience Methods
    
    func logTap(objectType: ObjectType, label: String, location: CGPoint = .zero, additionalInfo: String = "") {
        log(event: .tap, objectType: objectType, label: label, location: location, additionalInfo: additionalInfo)
    }
    
    func logDoubleTap(objectType: ObjectType, label: String, location: CGPoint = .zero, additionalInfo: String = "") {
        log(event: .doubleTap, objectType: objectType, label: label, location: location, additionalInfo: additionalInfo)
    }
    
    func logVoiceOverFocus(objectType: ObjectType, label: String, additionalInfo: String = "") {
        log(event: .voFocus, objectType: objectType, label: label, location: .zero, additionalInfo: additionalInfo)
    }
    
    func logVoiceOverActivate(objectType: ObjectType, label: String, additionalInfo: String = "") {
        log(event: .voActivate, objectType: objectType, label: label, location: .zero, additionalInfo: additionalInfo)
    }
    
    func logSwipe(direction: TouchEventType, objectType: ObjectType = .background, label: String = "", additionalInfo: String = "") {
        log(event: direction, objectType: objectType, label: label, location: .zero, additionalInfo: additionalInfo)
    }
    
    // MARK: - Rotor Tracking
    
    func setRotorFunction(_ rotor: RotorFunction) {
        if currentRotorFunction != rotor {
            let previousRotor = currentRotorFunction
            currentRotorFunction = rotor
            log(
                event: .voRotorChange,
                objectType: .background,
                label: rotor.rawValue,
                location: .zero,
                additionalInfo: "Changed from \(previousRotor.rawValue) to \(rotor.rawValue)"
            )
        }
    }
    
    // MARK: - Accessibility Observers
    
    private func setupAccessibilityObservers() {
        // VoiceOver on/off status change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        // VoiceOver announcement finished
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnnouncementFinished),
            name: UIAccessibility.announcementDidFinishNotification,
            object: nil
        )
        
        // Real per-element VoiceOver focus tracking
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleElementFocused),
            name: UIAccessibility.elementFocusedNotification,
            object: nil
        )
    }
    
    @objc private func handleVoiceOverStatusChanged() {
        let status = UIAccessibility.isVoiceOverRunning ? "Enabled" : "Disabled"
        log(
            event: .voFocus,
            objectType: .background,
            label: "VoiceOver \(status)",
            location: .zero,
            additionalInfo: "VoiceOver status changed"
        )
    }
    
    @objc private func handleAnnouncementFinished(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let announcement = userInfo[UIAccessibility.announcementStringValueUserInfoKey] as? String {
            log(
                event: .voAnnouncement,
                objectType: .background,
                label: String(announcement.prefix(100)),
                location: .zero,
                additionalInfo: "Announcement completed"
            )
        }
    }
    
    // Real VoiceOver focus: fires each time VO cursor moves to an element
    @objc private func handleElementFocused(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let focusedElement = userInfo[UIAccessibility.focusedElementUserInfoKey] else {
                return
            }
            
            var label = "Unknown"
            var objectType: ObjectType = .unknown
            
            if let obj = focusedElement as? NSObject {
                // 1. Direct accessibilityLabel (works for UIKit and some SwiftUI)
                if let accessLabel = obj.accessibilityLabel, !accessLabel.isEmpty {
                    label = accessLabel
                }
                // 2. Try accessibilityValue as fallback
                else if let accessValue = obj.accessibilityValue, !accessValue.isEmpty {
                    label = accessValue
                }
                // 3. Try accessibilityIdentifier on UIView
                else if let view = obj as? UIView,
                        let ident = view.accessibilityIdentifier, !ident.isEmpty {
                    label = ident
                }
                // 4. For SwiftUI hosting views, walk up to find labeled parent
                else if let view = obj as? UIView {
                    label = findAccessibilityLabelInHierarchy(view) ?? "Unlabeled"
                }
                
                // Get traits from the element
                let traits = obj.accessibilityTraits
                objectType = mapTraitsToObjectType(traits)
            }
            
            let truncatedLabel = String(label.prefix(100))
            
            log(
                event: .voFocus,
                objectType: objectType,
                label: truncatedLabel,
                location: .zero,
                additionalInfo: "VoiceOver focused"
            )
        }
        
        /// Walk up the view hierarchy to find the nearest accessibility label.
        /// SwiftUI wraps views in private hosting views; the label is often
        /// on a parent or sibling rather than the directly-focused view.
        private func findAccessibilityLabelInHierarchy(_ view: UIView) -> String? {
            // Check accessibility elements of the view first
            if view.isAccessibilityElement, let lbl = view.accessibilityLabel, !lbl.isEmpty {
                return lbl
            }
            
            // Check immediate children
            for subview in view.subviews {
                if subview.isAccessibilityElement,
                   let lbl = subview.accessibilityLabel, !lbl.isEmpty {
                    return lbl
                }
            }
            
            // Walk up to parent (max 3 levels)
            var parent = view.superview
            var depth = 0
            while let p = parent, depth < 3 {
                if p.isAccessibilityElement, let lbl = p.accessibilityLabel, !lbl.isEmpty {
                    return lbl
                }
                parent = p.superview
                depth += 1
            }
            
            return nil
        }
        
    
    // Map UIAccessibilityTraits → ObjectType
    private func mapTraitsToObjectType(_ traits: UIAccessibilityTraits) -> ObjectType {
            if traits.contains(.header)       { return .heading }
            if traits.contains(.button)       { return .button }
            if traits.contains(.image)        { return .image }
            if traits.contains(.staticText)   { return .paragraph }
            if traits.contains(.link)         { return .button }
            if traits.contains(.searchField)  { return .textField }
            if traits.contains(.adjustable)   { return .pageControl }
            return .unknown
        }
    
    // MARK: - Export to CSV
    
    func exportToCSV(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else {
            print("[InteractionLogger] No entries for Flow \(flow)")
            return nil
        }
        
        let csvContent = generateCSVContent(entries: flowEntries)
        let fileName = generateFileName(flow: flow)
        
        guard let fileURL = saveToFile(content: csvContent, fileName: fileName) else {
            print("[InteractionLogger] Failed to save CSV for Flow \(flow)")
            return nil
        }
        
        print("[InteractionLogger] Exported \(flowEntries.count) entries to \(fileURL.path)")
        return fileURL
    }
    
    /// Export ONLY math-equation related entries for a given flow.
    func exportMathCSV(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else {
            print("[InteractionLogger] No entries for Flow \(flow) (math export)")
            return nil
        }
        
        let mathType = ObjectType.mathEquation.rawValue
        let mathEntries = flowEntries.filter { $0.objectType == mathType }
        guard !mathEntries.isEmpty else {
            print("[InteractionLogger] No math entries for Flow \(flow)")
            return nil
        }
        
        let csvContent = generateCSVContent(entries: mathEntries)
        let baseName = generateFileName(flow: flow)
        let fileName = insertSuffix("_math", intoFileName: baseName)
        
        guard let fileURL = saveToFile(content: csvContent, fileName: fileName) else {
            print("[InteractionLogger] Failed to save Math CSV for Flow \(flow)")
            return nil
        }
        
        print("[InteractionLogger] Exported \(mathEntries.count) math entries to \(fileURL.path)")
        return fileURL
    }
    
    /// Export ONLY graphic (SVG) related entries for a given flow.
    func exportGraphicCSV(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else {
            print("[InteractionLogger] No entries for Flow \(flow) (graphic export)")
            return nil
        }
        
        let svgType = ObjectType.svg.rawValue
        let graphicEntries = flowEntries.filter { $0.objectType == svgType }
        guard !graphicEntries.isEmpty else {
            print("[InteractionLogger] No graphic entries for Flow \(flow)")
            return nil
        }
        
        let csvContent = generateCSVContent(entries: graphicEntries)
        let baseName = generateFileName(flow: flow)
        let fileName = insertSuffix("_graphic", intoFileName: baseName)
        
        guard let fileURL = saveToFile(content: csvContent, fileName: fileName) else {
            print("[InteractionLogger] Failed to save Graphic CSV for Flow \(flow)")
            return nil
        }
        
        print("[InteractionLogger] Exported \(graphicEntries.count) graphic entries to \(fileURL.path)")
        return fileURL
    }
    
    func exportAllFlows() -> [URL] {
        var urls: [URL] = []
        for flow in 1...3 {
            // Always try to export overall CSV (even if empty, for consistency)
            if let url = exportToCSV(flow: flow) {
                urls.append(url)
                print("[InteractionLogger] Added overall CSV for Flow \(flow): \(url.lastPathComponent)")
            }
            // Export math CSV if entries exist
            if let mathURL = exportMathCSV(flow: flow) {
                urls.append(mathURL)
                print("[InteractionLogger] Added math CSV for Flow \(flow): \(mathURL.lastPathComponent)")
            }
            // Export graphic CSV if entries exist
            if let graphicURL = exportGraphicCSV(flow: flow) {
                urls.append(graphicURL)
                print("[InteractionLogger] Added graphic CSV for Flow \(flow): \(graphicURL.lastPathComponent)")
            }
        }
        print("[InteractionLogger] exportAllFlows returning \(urls.count) files total")
        return urls
    }
    
    /// Export only the current flow's data (overall, math, graphic).
    func exportCurrentFlow() -> [URL] {
        var urls: [URL] = []
        let flow = currentFlow
        
        if let url = exportToCSV(flow: flow) {
            urls.append(url)
            print("[InteractionLogger] Added overall CSV for Flow \(flow): \(url.lastPathComponent)")
        }
        if let mathURL = exportMathCSV(flow: flow) {
            urls.append(mathURL)
            print("[InteractionLogger] Added math CSV for Flow \(flow): \(mathURL.lastPathComponent)")
        }
        if let graphicURL = exportGraphicCSV(flow: flow) {
            urls.append(graphicURL)
            print("[InteractionLogger] Added graphic CSV for Flow \(flow): \(graphicURL.lastPathComponent)")
        }
        
        print("[InteractionLogger] exportCurrentFlow returning \(urls.count) files for Flow \(flow)")
        return urls
    }
    
    /// Export current flow as a single Excel file (XLSX) with 3 tabs: Overall, Graphics, Math.
    func exportCurrentFlowAsExcel() -> URL? {
        exportFlowAsExcel(flow: currentFlow)
    }

    /// Export a specific flow as a single Excel file (XLSX) with 3 tabs: Overall, Graphics, Math.
    func exportFlowAsExcel(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else {
            print("[InteractionLogger] No entries for Flow \(flow) (Excel export)")
            return nil
        }
        
        let svgType = ObjectType.svg.rawValue
        let mathType = ObjectType.mathEquation.rawValue
        
        let overallEntries = flowEntries
        let graphicEntries = flowEntries.filter { $0.objectType == svgType }
        let mathEntries = flowEntries.filter { $0.objectType == mathType }
        
        return createExcelFile(
            flow: flow,
            overallEntries: overallEntries,
            graphicEntries: graphicEntries,
            mathEntries: mathEntries
        )
    }
    
    /// Export all flows (1–3) as Excel files. Returns one XLSX per flow that has entries.
    func exportAllFlowsAsExcel() -> [URL] {
        var urls: [URL] = []
        for flow in 1...3 {
            if let url = exportFlowAsExcel(flow: flow) {
                urls.append(url)
            }
        }
        print("[InteractionLogger] exportAllFlowsAsExcel returning \(urls.count) files")
        return urls
    }
    
    /// Create an XLSX file with multiple sheets.
    private func createExcelFile(
        flow: Int,
        overallEntries: [InteractionLogEntry],
        graphicEntries: [InteractionLogEntry],
        mathEntries: [InteractionLogEntry]
    ) -> URL? {
        let baseName = generateFileName(flow: flow)
        let excelFileName = baseName.replacingOccurrences(of: ".csv", with: ".xlsx")
        
        guard let documentsDirectory = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        
        let logsDirectory = documentsDirectory.appendingPathComponent(
            "InteractionLogs", isDirectory: true
        )
        
        do {
            try fileManager.createDirectory(
                at: logsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("[InteractionLogger] Failed to create logs directory: \(error)")
            return nil
        }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("[InteractionLogger] Failed to create temp directory: \(error)")
            return nil
        }
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Create XML files for each sheet
        let overallXML = generateSheetXML(entries: overallEntries, sheetName: "Overall")
        let graphicXML = generateSheetXML(entries: graphicEntries, sheetName: "Graphics")
        let mathXML = generateSheetXML(entries: mathEntries, sheetName: "Math")
        
        // Write sheet XMLs
        let sheet1Path = tempDir.appendingPathComponent("xl/worksheets/sheet1.xml")
        let sheet2Path = tempDir.appendingPathComponent("xl/worksheets/sheet2.xml")
        let sheet3Path = tempDir.appendingPathComponent("xl/worksheets/sheet3.xml")
        do {
            try fileManager.createDirectory(at: sheet1Path.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try overallXML.write(to: sheet1Path, atomically: true, encoding: .utf8)
            try graphicXML.write(to: sheet2Path, atomically: true, encoding: .utf8)
            try mathXML.write(to: sheet3Path, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write worksheet XMLs: \(error)")
            return nil
        }
        
        // Create workbook.xml
        let workbookXML = generateWorkbookXML(hasGraphics: !graphicEntries.isEmpty, hasMath: !mathEntries.isEmpty)
        let workbookPath = tempDir.appendingPathComponent("xl/workbook.xml")
        do {
            try fileManager.createDirectory(at: workbookPath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try workbookXML.write(to: workbookPath, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write workbook.xml: \(error)")
            return nil
        }
        
        // Minimal styles.xml required by Excel
        let stylesXML = generateStylesXML()
        let stylesPath = tempDir.appendingPathComponent("xl/styles.xml")
        do {
            try stylesXML.write(to: stylesPath, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write styles.xml: \(error)")
            return nil
        }
        
        // Theme (Excel can be picky if missing)
        let themeXML = generateThemeXML()
        let themePath = tempDir.appendingPathComponent("xl/theme/theme1.xml")
        do {
            try fileManager.createDirectory(at: themePath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try themeXML.write(to: themePath, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write theme1.xml: \(error)")
            return nil
        }

        // Create workbook relationships
        let workbookRelsXML = generateWorkbookRelsXML(hasGraphics: !graphicEntries.isEmpty, hasMath: !mathEntries.isEmpty)
        let workbookRelsPath = tempDir.appendingPathComponent("xl/_rels/workbook.xml.rels")
        do {
            try fileManager.createDirectory(at: workbookRelsPath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try workbookRelsXML.write(to: workbookRelsPath, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write workbook.xml.rels: \(error)")
            return nil
        }
        
        // Create [Content_Types].xml
        let contentTypesXML = generateContentTypesXML(hasGraphics: !graphicEntries.isEmpty, hasMath: !mathEntries.isEmpty)
        let contentTypesPath = tempDir.appendingPathComponent("[Content_Types].xml")
        do {
            try contentTypesXML.write(to: contentTypesPath, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write [Content_Types].xml: \(error)")
            return nil
        }
        
        // Create _rels/.rels
        let relsXML = generateRootRelsXML()
        let relsPath = tempDir.appendingPathComponent("_rels/.rels")
        do {
            try fileManager.createDirectory(at: relsPath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try relsXML.write(to: relsPath, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write root .rels: \(error)")
            return nil
        }

        // Create docProps (some Excel builds are picky if these are missing)
        let coreXML = generateCorePropsXML(flow: flow)
        let appXML = generateAppPropsXML()
        let corePath = tempDir.appendingPathComponent("docProps/core.xml")
        let appPath = tempDir.appendingPathComponent("docProps/app.xml")
        do {
            try fileManager.createDirectory(at: corePath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try coreXML.write(to: corePath, atomically: true, encoding: .utf8)
            try appXML.write(to: appPath, atomically: true, encoding: .utf8)
        } catch {
            print("[InteractionLogger] Failed to write docProps: \(error)")
            return nil
        }
        
        // Create ZIP archive (XLSX is a ZIP file)
        let excelURL = logsDirectory.appendingPathComponent(excelFileName)
        let success = createZipArchive(from: tempDir, to: excelURL)
        
        if success {
            print("[InteractionLogger] Created Excel file: \(excelURL.path)")
            print("  - Overall: \(overallEntries.count) entries")
            print("  - Graphics: \(graphicEntries.count) entries")
            print("  - Math: \(mathEntries.count) entries")
            return excelURL
        } else {
            print("[InteractionLogger] Failed to create Excel ZIP archive")
            return nil
        }
    }
    
    /// Generate XML for a worksheet sheet.
    private func generateSheetXML(entries: [InteractionLogEntry], sheetName: String) -> String {
        // IMPORTANT: Excel is strict about XML declarations. Do not emit leading whitespace before `<?xml ...?>`.
        let rowCount = max(1, entries.count + 1) // header + data rows (at least 1)
        let lastRow = rowCount
        let lastCol = "K" // 11 columns
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        xml += "\n<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
        xml += "\n<dimension ref=\"A1:\(lastCol)\(lastRow)\"/>"
        xml += "\n<sheetViews><sheetView workbookViewId=\"0\"/></sheetViews>"
        xml += "\n<sheetFormatPr defaultRowHeight=\"15\"/>"
        xml += "\n<sheetData>"
        
        // Header row
        let headers = InteractionLogEntry.csvHeader.split(separator: ",")
        xml += "\n<row r=\"1\">"
        for (index, header) in headers.enumerated() {
            let col = columnLetter(for: index + 1)
            xml += inlineStringCellRef("\(col)1", value: String(header))
        }
        xml += "</row>"
        
        // Data rows
        for (rowIndex, entry) in entries.enumerated() {
            let rowNum = rowIndex + 2
            xml += "\n<row r=\"\(rowNum)\">"
            
            let values: [String] = [
                entry.timeStamp,
                entry.trialTime,
                entry.touchEvent,
                entry.objectType,
                entry.objectLabel,
                String(entry.touchX),
                String(entry.touchY),
                entry.condition,
                entry.screenName,
                entry.rotorFunction,
                entry.additionalInfo
            ]
            
            for (colIndex, value) in values.enumerated() {
                let col = columnLetter(for: colIndex + 1)
                xml += inlineStringCellRef("\(col)\(rowNum)", value: value)
            }
            
            xml += "</row>"
        }
        
        xml += "\n</sheetData>\n</worksheet>\n"
        
        return xml
    }

    /// Excel string cell using inlineStr (more compatible than t="str")
    private func inlineStringCellRef(_ ref: String, value: String) -> String {
        // Preserve leading/trailing spaces for Excel
        let escaped = escapeXML(value)
        return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escaped)</t></is></c>"
    }
    
    /// Generate workbook.xml (always 3 tabs)
    private func generateWorkbookXML(hasGraphics: Bool, hasMath: Bool) -> String {
        // Keep signature, but we always include 3 sheets to match study export format.
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">",
            "<workbookPr/>",
            "<bookViews><workbookView xWindow=\"0\" yWindow=\"0\" windowWidth=\"28800\" windowHeight=\"16560\"/></bookViews>",
            "<sheets>",
            "<sheet name=\"Overall\" sheetId=\"1\" r:id=\"rId1\"/>",
            "<sheet name=\"Graphics\" sheetId=\"2\" r:id=\"rId2\"/>",
            "<sheet name=\"Math\" sheetId=\"3\" r:id=\"rId3\"/>",
            "</sheets>",
            "<calcPr calcId=\"171027\"/>",
            "</workbook>",
            ""
        ].joined(separator: "\n")
    }
    
    /// Generate workbook.xml.rels (always 3 sheets + styles)
    private func generateWorkbookRelsXML(hasGraphics: Bool, hasMath: Bool) -> String {
        // Keep signature, but always include relationships for 3 worksheets.
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
            "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
            "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet2.xml\"/>",
            "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet3.xml\"/>",
            "<Relationship Id=\"rId4\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>",
            "<Relationship Id=\"rId5\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/>",
            "</Relationships>",
            ""
        ].joined(separator: "\n")
    }
    
    /// Generate [Content_Types].xml (always 3 sheets + styles)
    private func generateContentTypesXML(hasGraphics: Bool, hasMath: Bool) -> String {
        // Keep signature, but always include overrides for 3 worksheets.
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
            "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>",
            "<Default Extension=\"xml\" ContentType=\"application/xml\"/>",
            "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>",
            "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>",
            "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>",
            "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
            "<Override PartName=\"/xl/worksheets/sheet2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
            "<Override PartName=\"/xl/worksheets/sheet3.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
            "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>",
            "<Override PartName=\"/xl/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>",
            "</Types>",
            ""
        ].joined(separator: "\n")
    }

    /// Minimal Office theme (theme1.xml). Excel sometimes marks files as corrupt if theme is missing.
    private func generateThemeXML() -> String {
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"Office Theme\">",
            "  <a:themeElements>",
            "    <a:clrScheme name=\"Office\">",
            "      <a:dk1><a:sysClr val=\"windowText\" lastClr=\"000000\"/></a:dk1>",
            "      <a:lt1><a:sysClr val=\"window\" lastClr=\"FFFFFF\"/></a:lt1>",
            "      <a:dk2><a:srgbClr val=\"1F497D\"/></a:dk2>",
            "      <a:lt2><a:srgbClr val=\"EEECE1\"/></a:lt2>",
            "      <a:accent1><a:srgbClr val=\"4F81BD\"/></a:accent1>",
            "      <a:accent2><a:srgbClr val=\"C0504D\"/></a:accent2>",
            "      <a:accent3><a:srgbClr val=\"9BBB59\"/></a:accent3>",
            "      <a:accent4><a:srgbClr val=\"8064A2\"/></a:accent4>",
            "      <a:accent5><a:srgbClr val=\"4BACC6\"/></a:accent5>",
            "      <a:accent6><a:srgbClr val=\"F79646\"/></a:accent6>",
            "      <a:hlink><a:srgbClr val=\"0000FF\"/></a:hlink>",
            "      <a:folHlink><a:srgbClr val=\"800080\"/></a:folHlink>",
            "    </a:clrScheme>",
            "    <a:fontScheme name=\"Office\">",
            "      <a:majorFont><a:latin typeface=\"Calibri\"/></a:majorFont>",
            "      <a:minorFont><a:latin typeface=\"Calibri\"/></a:minorFont>",
            "    </a:fontScheme>",
            "    <a:fmtScheme name=\"Office\">",
            "      <a:fillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:fillStyleLst>",
            "      <a:lnStyleLst><a:ln w=\"9525\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:prstDash val=\"solid\"/></a:ln></a:lnStyleLst>",
            "      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>",
            "      <a:bgFillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:bgFillStyleLst>",
            "    </a:fmtScheme>",
            "  </a:themeElements>",
            "</a:theme>",
            ""
        ].joined(separator: "\n")
    }
    
    /// Generate _rels/.rels
    private func generateRootRelsXML() -> String {
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
            "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>",
            "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>",
            "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>",
            "</Relationships>",
            ""
        ].joined(separator: "\n")
    }

    private func generateCorePropsXML(flow: Int) -> String {
        // Excel likes these present; keep minimal and stable.
        let now = ISO8601DateFormatter().string(from: Date())
        let title = escapeXML("Study Export - Flow \(flow)")
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">",
            "  <dc:title>\(title)</dc:title>",
            "  <dc:creator>Education</dc:creator>",
            "  <cp:lastModifiedBy>Education</cp:lastModifiedBy>",
            "  <dcterms:created xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:created>",
            "  <dcterms:modified xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:modified>",
            "</cp:coreProperties>",
            ""
        ].joined(separator: "\n")
    }

    private func generateAppPropsXML() -> String {
        // Minimal extended properties with sheet names.
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">",
            "  <Application>Education</Application>",
            "  <DocSecurity>0</DocSecurity>",
            "  <ScaleCrop>false</ScaleCrop>",
            "  <HeadingPairs>",
            "    <vt:vector size=\"2\" baseType=\"variant\">",
            "      <vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>",
            "      <vt:variant><vt:i4>3</vt:i4></vt:variant>",
            "    </vt:vector>",
            "  </HeadingPairs>",
            "  <TitlesOfParts>",
            "    <vt:vector size=\"3\" baseType=\"lpstr\">",
            "      <vt:lpstr>Overall</vt:lpstr>",
            "      <vt:lpstr>Graphics</vt:lpstr>",
            "      <vt:lpstr>Math</vt:lpstr>",
            "    </vt:vector>",
            "  </TitlesOfParts>",
            "</Properties>",
            ""
        ].joined(separator: "\n")
    }
    
    /// Convert column number to Excel column letter (1 -> A, 2 -> B, etc.)
    private func columnLetter(for column: Int) -> String {
        var result = ""
        var num = column
        while num > 0 {
            num -= 1
            result = String(Character(UnicodeScalar(65 + (num % 26))!)) + result
            num /= 26
        }
        return result
    }
    
    /// Escape XML special characters
    private func escapeXML(_ text: String) -> String {
        // Excel is strict about XML 1.0 validity. Strip control characters that are illegal in XML.
        // Valid XML 1.0 chars: #x9 #xA #xD #x20-#xD7FF #xE000-#xFFFD #x10000-#x10FFFF
        let sanitized: String = {
            var scalars = String.UnicodeScalarView()
            scalars.reserveCapacity(text.unicodeScalars.count)
            for s in text.unicodeScalars {
                let v = s.value
                let isValid =
                    v == 0x9 || v == 0xA || v == 0xD ||
                    (v >= 0x20 && v <= 0xD7FF) ||
                    (v >= 0xE000 && v <= 0xFFFD) ||
                    (v >= 0x10000 && v <= 0x10FFFF)
                if isValid { scalars.append(s) }
            }
            return String(scalars)
        }()

        return sanitized
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    /// Create ZIP archive from directory (XLSX is a ZIP file), using ZipFoundation.
    private func createZipArchive(from sourceDir: URL, to destination: URL) -> Bool {
        do {
            // Remove any existing file at destination
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            
            guard let archive = Archive(url: destination, accessMode: .create) else {
                print("[InteractionLogger] Failed to create ZIP archive at \(destination.path)")
                return false
            }
            
            guard let fileEnumerator = fileManager.enumerator(
                at: sourceDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                print("[InteractionLogger] Failed to enumerate files for ZIP at \(sourceDir.path)")
                return false
            }
            
            for case let fileURL as URL in fileEnumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
                
                let relativePath = fileURL.path.replacingOccurrences(of: sourceDir.path + "/", with: "")
                
                do {
                    try archive.addEntry(
                        with: relativePath,
                        relativeTo: sourceDir
                    )
                } catch {
                    print("[InteractionLogger] Failed to add entry \(relativePath) to ZIP: \(error)")
                    return false
                }
            }
            
            return true
        } catch {
            print("[InteractionLogger] Failed to create ZIP archive: \(error)")
            return false
        }
    }

    /// Minimal style sheet so Excel doesn't complain about missing styles.
    private func generateStylesXML() -> String {
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
            "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">",
            "  <fonts count=\"1\">",
            "    <font>",
            "      <sz val=\"11\"/>",
            "      <color rgb=\"FF000000\"/>",
            "      <name val=\"Calibri\"/>",
            "      <family val=\"2\"/>",
            "    </font>",
            "  </fonts>",
            "  <fills count=\"2\">",
            "    <fill><patternFill patternType=\"none\"/></fill>",
            "    <fill><patternFill patternType=\"gray125\"/></fill>",
            "  </fills>",
            "  <borders count=\"1\">",
            "    <border><left/><right/><top/><bottom/><diagonal/></border>",
            "  </borders>",
            "  <cellStyleXfs count=\"1\">",
            "    <xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/>",
            "  </cellStyleXfs>",
            "  <cellXfs count=\"1\">",
            "    <xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>",
            "  </cellXfs>",
            "  <cellStyles count=\"1\">",
            "    <cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/>",
            "  </cellStyles>",
            "  <dxfs count=\"0\"/>",
            "  <tableStyles count=\"0\" defaultTableStyle=\"TableStyleMedium9\" defaultPivotStyle=\"PivotStyleLight16\"/>",
            "</styleSheet>",
            ""
        ].joined(separator: "\n")
    }
    
    private func generateCSVContent(entries: [InteractionLogEntry]) -> String {
        var content = InteractionLogEntry.csvHeader + "\n"
        for entry in entries {
            content += entry.csvRow + "\n"
        }
        return content
    }
    
    /// Insert a suffix (e.g. "_math") before the file extension, if any.
    private func insertSuffix(_ suffix: String, intoFileName fileName: String) -> String {
        guard let dotIndex = fileName.lastIndex(of: ".") else {
            return fileName + suffix
        }
        let namePart = fileName[..<dotIndex]
        let extPart = fileName[dotIndex...]   // includes '.'
        return String(namePart) + suffix + String(extPart)
    }
    
    // Short but meaningful: SA_F1_0208_1430.csv
    private func generateFileName(flow: Int) -> String {
        let df = DateFormatter()
        // Include seconds so exporting multiple flows doesn't collide.
        df.dateFormat = "MMdd_HHmmss"
        let ts = df.string(from: Date())
        return "SA_F\(flow)_\(ts).csv"
    }
    
    private func saveToFile(content: String, fileName: String) -> URL? {
        guard let documentsDirectory = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        
        let logsDirectory = documentsDirectory.appendingPathComponent(
            "InteractionLogs", isDirectory: true
        )
        
        do {
            try fileManager.createDirectory(
                at: logsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("[InteractionLogger] Failed to create logs directory: \(error)")
            return nil
        }
        
        let fileURL = logsDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("[InteractionLogger] Failed to write file: \(error)")
            return nil
        }
    }
    
    // MARK: - Data Management
    
    func clearData(for flow: Int) {
        entries[flow] = []
        screenDurations[flow] = [:]
        if flow == currentFlow { entryCount = 0 }
    }
    
    func clearAllData() {
        entries = [1: [], 2: [], 3: []]
        screenDurations = [1: [:], 2: [:], 3: [:]]
        entryCount = 0
    }
    
    func getEntryCount(for flow: Int) -> Int {
        return entries[flow]?.count ?? 0
    }
    
    func getAllEntries(for flow: Int) -> [InteractionLogEntry] {
        return entries[flow] ?? []
    }
    
    // MARK: - Helpers
    
    private func formatTrialTime(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - SwiftUI View Extension for Easy Logging

extension View {
    func logInteraction(
        _ event: TouchEventType,
        objectType: ObjectType,
        label: String,
        location: CGPoint = .zero,
        additionalInfo: String = ""
    ) -> some View {
        self.onAppear { }
    }
    
    func trackScreen(_ screenName: String) -> some View {
        self.onAppear {
            InteractionLogger.shared.setCurrentScreen(screenName)
        }
    }
}

// MARK: - Gesture Logging Modifier

struct InteractionLoggingModifier: ViewModifier {
    let objectType: ObjectType
    let label: String
    
    @State private var touchStartLocation: CGPoint = .zero
    @State private var touchStartTime: Date = Date()
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation == .zero {
                            touchStartLocation = value.location
                            touchStartTime = Date()
                            InteractionLogger.shared.log(
                                event: .touchDown,
                                objectType: objectType,
                                label: label,
                                location: value.location
                            )
                        } else {
                            InteractionLogger.shared.log(
                                event: .touchMove,
                                objectType: objectType,
                                label: label,
                                location: value.location
                            )
                        }
                    }
                    .onEnded { value in
                        let distance = sqrt(
                            pow(value.translation.width, 2) +
                            pow(value.translation.height, 2)
                        )
                        let duration = Date().timeIntervalSince(touchStartTime)
                        
                        InteractionLogger.shared.log(
                            event: .touchUp,
                            objectType: objectType,
                            label: label,
                            location: value.location
                        )
                        
                        if distance < 10 && duration < 0.3 {
                            InteractionLogger.shared.log(
                                event: .tap,
                                objectType: objectType,
                                label: label,
                                location: value.location
                            )
                        } else if distance < 10 && duration >= 0.5 {
                            InteractionLogger.shared.log(
                                event: .longPress,
                                objectType: objectType,
                                label: label,
                                location: value.location
                            )
                        } else if distance >= 50 {
                            let horizontal = abs(value.translation.width) > abs(value.translation.height)
                            let event: TouchEventType
                            if horizontal {
                                event = value.translation.width > 0 ? .swipeRight : .swipeLeft
                            } else {
                                event = value.translation.height > 0 ? .swipeDown : .swipeUp
                            }
                            InteractionLogger.shared.log(
                                event: event,
                                objectType: objectType,
                                label: label,
                                location: value.location
                            )
                        }
                    }
            )
    }
}

extension View {
    func logTouches(objectType: ObjectType, label: String) -> some View {
        self.modifier(InteractionLoggingModifier(objectType: objectType, label: label))
    }
}
