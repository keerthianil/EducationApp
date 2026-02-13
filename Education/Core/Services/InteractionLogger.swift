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
    let timeStamp: String
    let trialTime: String
    let touchEvent: String
    let objectType: String
    let objectLabel: String
    let touchX: Double
    let touchY: Double
    let condition: String
    let screenName: String
    let rotorFunction: String
    let additionalInfo: String
    
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
    private var screenDurations: [Int: [String: TimeInterval]] = [1: [:], 2: [:], 3: [:]]
    private var currentScreenEntryTime: Date?
    
    // Idle time tracking
    private var lastInteractionTime: Date?
    private let idleThreshold: TimeInterval = 5.0
    
    // Currently open document
    private var currentDocumentTitle: String?
    private var documentOpenTime: Date?
    
    // Dedup: prevent duplicate consecutive log entries
    private var lastLoggedEvent: (event: String, label: String, time: Date)? = nil
    
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
    
    // MARK: - Flow Name Helper
    
    static func flowName(for flow: Int) -> String {
        switch flow {
        case 1: return "Practice"
        case 2: return "Scenario1"
        case 3: return "Scenario2"
        default: return "Flow\(flow)"
        }
    }
    
    static func flowDisplayName(for flow: Int) -> String {
        switch flow {
        case 1: return "Practice Scenario"
        case 2: return "Scenario 1"
        case 3: return "Scenario 2"
        default: return "Flow \(flow)"
        }
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
                additionalInfo: "\(Self.flowDisplayName(for: flow)) | VoiceOver: \(voStatus) | Device: \(deviceModel) | iOS \(systemVersion) | Screen: \(screenSize)"
            )
        }
    }
    
    func endSession() {
        guard isLogging else { return }
        
        recordCurrentScreenDuration()
        
        if let docTitle = currentDocumentTitle {
            logDocumentClose(title: docTitle)
        }
        
        if let durations = screenDurations[currentFlow] {
            for (screen, duration) in durations.sorted(by: { $0.key < $1.key }) {
                log(event: .screenDurationSummary, objectType: .session, label: screen, location: .zero, additionalInfo: "Total duration: \(String(format: "%.1f", duration))s")
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
        
        log(event: .sessionEnd, objectType: .session, label: "Session Ended", location: .zero, additionalInfo: "\(Self.flowDisplayName(for: currentFlow)) | Total duration: \(totalDuration) | Entries: \(entryCount)")
        
        isLogging = false
    }
    
    func setCurrentScreen(_ screenName: String) {
        let previousScreen = currentScreenName
        if previousScreen != screenName { recordCurrentScreenDuration() }
        currentScreenName = screenName
        currentScreenEntryTime = Date()
        if previousScreen != screenName && isLogging {
            log(event: .screenTransition, objectType: .background, label: screenName, location: .zero, additionalInfo: "From: \(previousScreen)")
        }
    }
    
    private func recordCurrentScreenDuration() {
        guard let entryTime = currentScreenEntryTime else { return }
        let duration = Date().timeIntervalSince(entryTime)
        let screen = currentScreenName
        let flow = currentFlow
        if screenDurations[flow] == nil { screenDurations[flow] = [:] }
        screenDurations[flow]?[screen, default: 0] += duration
    }
    
    // MARK: - Document Open/Close
    
    func logDocumentClose(title: String) {
        guard currentDocumentTitle != nil else { return }
        let duration: String
        if let openTime = documentOpenTime {
            let seconds = Date().timeIntervalSince(openTime)
            duration = String(format: "%.1f", seconds) + "s"
        } else { duration = "unknown" }
        log(event: .documentClose, objectType: .document, label: title, location: .zero, additionalInfo: "Document closed | Duration: \(duration)")
        currentDocumentTitle = nil
        documentOpenTime = nil
    }

    func logDocumentOpen(title: String) {
        if currentDocumentTitle == title { return }
        if let prevTitle = currentDocumentTitle { logDocumentClose(title: prevTitle) }
        currentDocumentTitle = title
        documentOpenTime = Date()
        log(event: .documentOpen, objectType: .document, label: title, location: .zero, additionalInfo: "Document opened")
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
            self?.logInternal(event: event, objectType: objectType, label: label, location: location, rotorFunction: rotorFunction, additionalInfo: additionalInfo)
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
        
        // Dedup: skip consecutive identical event+label within 0.1s
        if let last = lastLoggedEvent,
           last.event == event.rawValue,
           last.label == label,
           now.timeIntervalSince(last.time) < 0.1 {
            return
        }
        lastLoggedEvent = (event: event.rawValue, label: label, time: now)
        
        // Idle time gap
        if let lastTime = lastInteractionTime {
            let gap = now.timeIntervalSince(lastTime)
            if gap >= idleThreshold {
                let idleEntry = InteractionLogEntry(
                    timeStamp: timeStamp, trialTime: trialTime,
                    touchEvent: TouchEventType.idleTime.rawValue,
                    objectType: ObjectType.background.rawValue,
                    objectLabel: "Idle", touchX: 0, touchY: 0,
                    condition: "Flow \(currentFlow)", screenName: currentScreenName,
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
            timeStamp: timeStamp, trialTime: trialTime,
            touchEvent: event.rawValue, objectType: objectType.rawValue,
            objectLabel: label,
            touchX: round(location.x * 10) / 10, touchY: round(location.y * 10) / 10,
            condition: "Flow \(currentFlow)", screenName: currentScreenName,
            rotorFunction: rotor.rawValue, additionalInfo: additionalInfo
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
            log(event: .voRotorChange, objectType: .background, label: rotor.rawValue, location: .zero, additionalInfo: "Changed from \(previousRotor.rawValue) to \(rotor.rawValue)")
        }
    }
    
    // MARK: - Accessibility Observers
    
    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleVoiceOverStatusChanged), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAnnouncementFinished), name: UIAccessibility.announcementDidFinishNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleElementFocused), name: UIAccessibility.elementFocusedNotification, object: nil)
    }
    
    @objc private func handleVoiceOverStatusChanged() {
        let status = UIAccessibility.isVoiceOverRunning ? "Enabled" : "Disabled"
        log(event: .voFocus, objectType: .background, label: "VoiceOver \(status)", location: .zero, additionalInfo: "VoiceOver status changed")
    }
    
    @objc private func handleAnnouncementFinished(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let announcement = userInfo[UIAccessibility.announcementStringValueUserInfoKey] as? String {
            log(event: .voAnnouncement, objectType: .background, label: String(announcement.prefix(100)), location: .zero, additionalInfo: "Announcement completed")
        }
    }
    
    @objc private func handleElementFocused(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let focusedElement = userInfo[UIAccessibility.focusedElementUserInfoKey] else { return }
        
        var label = "Unknown"
        var objectType: ObjectType = .unknown
        
        if let obj = focusedElement as? NSObject {
            if let accessLabel = obj.accessibilityLabel, !accessLabel.isEmpty { label = accessLabel }
            else if let accessValue = obj.accessibilityValue, !accessValue.isEmpty { label = accessValue }
            else if let view = obj as? UIView, let ident = view.accessibilityIdentifier, !ident.isEmpty { label = ident }
            else if let view = obj as? UIView { label = findAccessibilityLabelInHierarchy(view) ?? "Unlabeled" }
            
            objectType = mapTraitsToObjectType(obj.accessibilityTraits)
        }
        
        log(event: .voFocus, objectType: objectType, label: String(label.prefix(100)), location: .zero, additionalInfo: "VoiceOver focused")
    }
    
    private func findAccessibilityLabelInHierarchy(_ view: UIView) -> String? {
        if view.isAccessibilityElement, let lbl = view.accessibilityLabel, !lbl.isEmpty { return lbl }
        for subview in view.subviews {
            if subview.isAccessibilityElement, let lbl = subview.accessibilityLabel, !lbl.isEmpty { return lbl }
        }
        var parent = view.superview
        var depth = 0
        while let p = parent, depth < 3 {
            if p.isAccessibilityElement, let lbl = p.accessibilityLabel, !lbl.isEmpty { return lbl }
            parent = p.superview; depth += 1
        }
        return nil
    }
    
    private func mapTraitsToObjectType(_ traits: UIAccessibilityTraits) -> ObjectType {
        if traits.contains(.header) { return .heading }
        if traits.contains(.button) { return .button }
        if traits.contains(.image) { return .image }
        if traits.contains(.staticText) { return .paragraph }
        if traits.contains(.link) { return .button }
        if traits.contains(.searchField) { return .textField }
        if traits.contains(.adjustable) { return .pageControl }
        return .unknown
    }
    
    // MARK: - Export to CSV
    
    func exportToCSV(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else { return nil }
        let csvContent = generateCSVContent(entries: flowEntries)
        let fileName = generateFileName(flow: flow)
        return saveToFile(content: csvContent, fileName: fileName)
    }
    
    func exportMathCSV(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else { return nil }
        let mathEntries = flowEntries.filter { $0.objectType == ObjectType.mathEquation.rawValue }
        guard !mathEntries.isEmpty else { return nil }
        let csvContent = generateCSVContent(entries: mathEntries)
        return saveToFile(content: csvContent, fileName: insertSuffix("_math", intoFileName: generateFileName(flow: flow)))
    }
    
    func exportGraphicCSV(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else { return nil }
        let graphicEntries = flowEntries.filter { $0.objectType == ObjectType.svg.rawValue }
        guard !graphicEntries.isEmpty else { return nil }
        let csvContent = generateCSVContent(entries: graphicEntries)
        return saveToFile(content: csvContent, fileName: insertSuffix("_graphic", intoFileName: generateFileName(flow: flow)))
    }
    
    func exportAllFlows() -> [URL] {
        var urls: [URL] = []
        for flow in 1...3 {
            if let url = exportToCSV(flow: flow) { urls.append(url) }
            if let url = exportMathCSV(flow: flow) { urls.append(url) }
            if let url = exportGraphicCSV(flow: flow) { urls.append(url) }
        }
        return urls
    }
    
    func exportCurrentFlow() -> [URL] {
        var urls: [URL] = []
        let flow = currentFlow
        if let url = exportToCSV(flow: flow) { urls.append(url) }
        if let url = exportMathCSV(flow: flow) { urls.append(url) }
        if let url = exportGraphicCSV(flow: flow) { urls.append(url) }
        return urls
    }
    
    // MARK: - Export to Excel (XLSX)
    
    func exportCurrentFlowAsExcel() -> URL? { exportFlowAsExcel(flow: currentFlow) }

    func exportFlowAsExcel(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else { return nil }
        let documentGroups = groupEntriesByDocument(flowEntries)
        return createExcelFileWithDocumentTabs(flow: flow, overallEntries: flowEntries, documentGroups: documentGroups)
    }

    func exportAllFlowsAsExcel() -> [URL] {
        var urls: [URL] = []
        for flow in 1...3 {
            if let url = exportFlowAsExcel(flow: flow) { urls.append(url) }
        }
        return urls
    }
    
    // MARK: - Export to PDF
    
    func exportFlowAsPDF(flow: Int) -> URL? {
        guard let flowEntries = entries[flow], !flowEntries.isEmpty else { return nil }
        let documentGroups = groupEntriesByDocument(flowEntries)
        return generatePDF(flow: flow, overallEntries: flowEntries, documentGroups: documentGroups)
    }
    
    func exportAllFlowsAsPDF() -> [URL] {
        var urls: [URL] = []
        for flow in 1...3 {
            if let url = exportFlowAsPDF(flow: flow) { urls.append(url) }
        }
        return urls
    }
    
    // MARK: - PDF Generation
    
    private func generatePDF(
        flow: Int,
        overallEntries: [InteractionLogEntry],
        documentGroups: [(String, [InteractionLogEntry])]
    ) -> URL? {
        let flowName = Self.flowName(for: flow)
        let flowDisplay = Self.flowDisplayName(for: flow)
        
        let pageWidth: CGFloat = 792   // US Letter landscape
        let pageHeight: CGFloat = 612
        let margin: CGFloat = 30
        let lineHeight: CGFloat = 11
        let headerHeight: CGFloat = 20
        let sectionTitleHeight: CGFloat = 30
        
        let columns: [(String, CGFloat)] = [
            ("Time", 50), ("Trial", 46), ("Event", 74), ("Object", 56),
            ("Label", 145), ("X", 30), ("Y", 30), ("Condition", 56),
            ("Screen", 90), ("Rotor", 50), ("Info", 105)
        ]
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7),
            .foregroundColor: UIColor.white
        ]
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 6.5),
            .foregroundColor: UIColor.black
        ]
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor(red: 0.11, green: 0.39, blue: 0.44, alpha: 1)
        ]
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: UIColor.gray
        ]
        
        let tealColor = UIColor(red: 0.11, green: 0.39, blue: 0.44, alpha: 1)
        let altRowColor = UIColor(white: 0.96, alpha: 1)
        
        let rowsPerPage = Int((pageHeight - margin * 2 - headerHeight - sectionTitleHeight - 20) / lineHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        let data = renderer.pdfData { context in
            
            var pageNumber = 0
            
            func drawTableHeader(y: CGFloat) {
                var x = margin
                tealColor.setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: headerHeight)).fill()
                for (title, width) in columns {
                    (title as NSString).draw(in: CGRect(x: x + 2, y: y + 4, width: width - 4, height: 12), withAttributes: headerAttrs)
                    x += width
                }
            }
            
            func drawRow(entry: InteractionLogEntry, y: CGFloat, rowIdx: Int) {
                let values = [
                    entry.timeStamp, entry.trialTime, entry.touchEvent, entry.objectType,
                    String(entry.objectLabel.prefix(35)),
                    String(entry.touchX), String(entry.touchY),
                    entry.condition, String(entry.screenName.prefix(18)),
                    entry.rotorFunction, String(entry.additionalInfo.prefix(22))
                ]
                if rowIdx % 2 == 0 {
                    altRowColor.setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: lineHeight)).fill()
                }
                var x = margin
                for (i, (_, width)) in columns.enumerated() {
                    let val = i < values.count ? values[i] : ""
                    (val as NSString).draw(in: CGRect(x: x + 2, y: y + 1, width: width - 4, height: lineHeight), withAttributes: cellAttrs)
                    x += width
                }
            }
            
            func drawFooter() {
                pageNumber += 1
                let footerText = "\(flowDisplay) | Page \(pageNumber)"
                (footerText as NSString).draw(
                    at: CGPoint(x: pageWidth - margin - 120, y: pageHeight - margin + 4),
                    withAttributes: footerAttrs
                )
            }
            
            // Helper: draw a section (section title + entries table)
            func drawSection(title: String, sectionEntries: [InteractionLogEntry]) {
                var rowIndex = 0
                
                while rowIndex < sectionEntries.count {
                    context.beginPage()
                    
                    // Section title
                    (title as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: sectionAttrs)
                    let countText = "(\(sectionEntries.count) entries)"
                    (countText as NSString).draw(at: CGPoint(x: margin + 300, y: margin + 2), withAttributes: footerAttrs)
                    
                    let tableY = margin + sectionTitleHeight
                    drawTableHeader(y: tableY)
                    
                    var y = tableY + headerHeight
                    var rowsOnThisPage = 0
                    
                    while rowIndex < sectionEntries.count && rowsOnThisPage < rowsPerPage {
                        drawRow(entry: sectionEntries[rowIndex], y: y, rowIdx: rowIndex)
                        y += lineHeight
                        rowIndex += 1
                        rowsOnThisPage += 1
                    }
                    
                    drawFooter()
                }
            }
            
            // --- Page 1+: Overall (all entries) ---
            drawSection(title: "\(flowDisplay) — Overall", sectionEntries: overallEntries)
            
            // --- Subsequent pages: one section per document ---
            for (idx, group) in documentGroups.enumerated() {
                let docTitle = "\(idx + 1). \(group.0)"
                drawSection(title: docTitle, sectionEntries: group.1)
            }
        }
        
        // Save file
        guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let logsDir = docsDir.appendingPathComponent("InteractionLogs", isDirectory: true)
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        let df = DateFormatter(); df.dateFormat = "MMdd_HHmmss"
        let url = logsDir.appendingPathComponent("SA_\(flowName)_\(df.string(from: Date())).pdf")
        
        do { try data.write(to: url); return url }
        catch { print("[PDF Export] Failed: \(error)"); return nil }
    }
    
    // MARK: - Document Grouping (shared by Excel + PDF)
    
    private func groupEntriesByDocument(_ entries: [InteractionLogEntry]) -> [(String, [InteractionLogEntry])] {
        var groups: [(String, [InteractionLogEntry])] = []
        var currentDoc: String? = nil
        var currentBuf: [InteractionLogEntry] = []
        
        for entry in entries {
            if entry.touchEvent == TouchEventType.documentOpen.rawValue {
                if let doc = currentDoc, !currentBuf.isEmpty {
                    groups.append((doc, currentBuf)); currentBuf = []
                }
                currentDoc = entry.objectLabel
                currentBuf.append(entry)
            } else if entry.touchEvent == TouchEventType.documentClose.rawValue {
                currentBuf.append(entry)
                if let doc = currentDoc { groups.append((doc, currentBuf)); currentBuf = [] }
                currentDoc = nil
            } else {
                currentBuf.append(entry)
            }
        }
        if let doc = currentDoc, !currentBuf.isEmpty { groups.append((doc, currentBuf)) }
        return groups
    }
    
    // MARK: - Excel Generation (with document tabs)

    private func createExcelFileWithDocumentTabs(
        flow: Int,
        overallEntries: [InteractionLogEntry],
        documentGroups: [(String, [InteractionLogEntry])]
    ) -> URL? {
        let baseName = generateFileName(flow: flow)
        let excelFileName = baseName.replacingOccurrences(of: ".csv", with: ".xlsx")
        
        guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let logsDir = docsDir.appendingPathComponent("InteractionLogs", isDirectory: true)
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        struct SheetDef { let name: String; let entries: [InteractionLogEntry] }
        var sheets: [SheetDef] = [SheetDef(name: "Overall", entries: overallEntries)]
        
        for (idx, group) in documentGroups.enumerated() {
            var tabName = group.0
                .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "?", with: "").replacingOccurrences(of: "[", with: "(")
                .replacingOccurrences(of: "]", with: ")")
            if tabName.count > 28 { tabName = String(tabName.prefix(25)) + "..." }
            sheets.append(SheetDef(name: String("\(idx + 1)_\(tabName)".prefix(31)), entries: group.1))
        }
        
        let n = sheets.count
        
        // Write worksheet XMLs
        let wsDir = tempDir.appendingPathComponent("xl/worksheets")
        try? fileManager.createDirectory(at: wsDir, withIntermediateDirectories: true)
        for (i, sheet) in sheets.enumerated() {
            let xml = generateSheetXML(entries: sheet.entries, sheetName: sheet.name)
            try? xml.write(to: wsDir.appendingPathComponent("sheet\(i+1).xml"), atomically: true, encoding: .utf8)
        }
        
        // workbook.xml
        let sheetTags = sheets.enumerated().map { i, s in
            "<sheet name=\"\(escapeXML(s.name))\" sheetId=\"\(i+1)\" r:id=\"rId\(i+1)\"/>"
        }.joined(separator: "\n")
        let wbXML = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n<workbookPr/><bookViews><workbookView xWindow=\"0\" yWindow=\"0\" windowWidth=\"28800\" windowHeight=\"16560\"/></bookViews>\n<sheets>\(sheetTags)</sheets>\n<calcPr calcId=\"171027\"/>\n</workbook>"
        let xlDir = tempDir.appendingPathComponent("xl")
        try? fileManager.createDirectory(at: xlDir, withIntermediateDirectories: true)
        try? wbXML.write(to: xlDir.appendingPathComponent("workbook.xml"), atomically: true, encoding: .utf8)
        
        // workbook.xml.rels
        var rels = sheets.enumerated().map { i, _ in
            "<Relationship Id=\"rId\(i+1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i+1).xml\"/>"
        }
        rels.append("<Relationship Id=\"rId\(n+1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>")
        rels.append("<Relationship Id=\"rId\(n+2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/>")
        let wbRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n\(rels.joined(separator: "\n"))\n</Relationships>"
        let wbRelsDir = tempDir.appendingPathComponent("xl/_rels")
        try? fileManager.createDirectory(at: wbRelsDir, withIntermediateDirectories: true)
        try? wbRels.write(to: wbRelsDir.appendingPathComponent("workbook.xml.rels"), atomically: true, encoding: .utf8)
        
        // [Content_Types].xml
        let overrides = sheets.enumerated().map { i, _ in
            "<Override PartName=\"/xl/worksheets/sheet\(i+1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }.joined(separator: "\n")
        let ctXML = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>\n<Default Extension=\"xml\" ContentType=\"application/xml\"/>\n<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>\n<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>\n<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>\n\(overrides)\n<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>\n<Override PartName=\"/xl/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>\n</Types>"
        try? ctXML.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        
        // styles, theme, root rels, docProps
        try? generateStylesXML().write(to: xlDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)
        let themeDir = xlDir.appendingPathComponent("theme")
        try? fileManager.createDirectory(at: themeDir, withIntermediateDirectories: true)
        try? generateThemeXML().write(to: themeDir.appendingPathComponent("theme1.xml"), atomically: true, encoding: .utf8)
        let rootRelsDir = tempDir.appendingPathComponent("_rels")
        try? fileManager.createDirectory(at: rootRelsDir, withIntermediateDirectories: true)
        try? generateRootRelsXML().write(to: rootRelsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)
        let dpDir = tempDir.appendingPathComponent("docProps")
        try? fileManager.createDirectory(at: dpDir, withIntermediateDirectories: true)
        try? generateCorePropsXML(flow: flow).write(to: dpDir.appendingPathComponent("core.xml"), atomically: true, encoding: .utf8)
        
        let sheetNames = sheets.map { "<vt:lpstr>\(escapeXML($0.name))</vt:lpstr>" }.joined(separator: "\n")
        let appXML = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">\n<Application>Education</Application>\n<HeadingPairs><vt:vector size=\"2\" baseType=\"variant\"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>\(n)</vt:i4></vt:variant></vt:vector></HeadingPairs>\n<TitlesOfParts><vt:vector size=\"\(n)\" baseType=\"lpstr\">\n\(sheetNames)\n</vt:vector></TitlesOfParts>\n</Properties>"
        try? appXML.write(to: dpDir.appendingPathComponent("app.xml"), atomically: true, encoding: .utf8)
        
        let excelURL = logsDir.appendingPathComponent(excelFileName)
        if createZipArchive(from: tempDir, to: excelURL) { return excelURL }
        return nil
    }
    
    // MARK: - Sheet XML
    
    private func generateSheetXML(entries: [InteractionLogEntry], sheetName: String) -> String {
        let rowCount = max(1, entries.count + 1)
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        xml += "\n<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
        xml += "\n<dimension ref=\"A1:K\(rowCount)\"/>"
        xml += "\n<sheetViews><sheetView workbookViewId=\"0\"/></sheetViews>"
        xml += "\n<sheetFormatPr defaultRowHeight=\"15\"/>"
        xml += "\n<sheetData>"
        
        let headers = InteractionLogEntry.csvHeader.split(separator: ",")
        xml += "\n<row r=\"1\">"
        for (index, header) in headers.enumerated() {
            xml += inlineStringCell(col: index + 1, row: 1, value: String(header))
        }
        xml += "</row>"
        
        for (rowIndex, entry) in entries.enumerated() {
            let rowNum = rowIndex + 2
            xml += "\n<row r=\"\(rowNum)\">"
            let values = [entry.timeStamp, entry.trialTime, entry.touchEvent, entry.objectType, entry.objectLabel, String(entry.touchX), String(entry.touchY), entry.condition, entry.screenName, entry.rotorFunction, entry.additionalInfo]
            for (colIndex, value) in values.enumerated() {
                xml += inlineStringCell(col: colIndex + 1, row: rowNum, value: value)
            }
            xml += "</row>"
        }
        
        xml += "\n</sheetData>\n</worksheet>"
        return xml
    }

    private func inlineStringCell(col: Int, row: Int, value: String) -> String {
        let ref = "\(columnLetter(for: col))\(row)"
        return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escapeXML(value))</t></is></c>"
    }
    
    // MARK: - Helper XML generators
    
    private func generateStylesXML() -> String {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n<fonts count=\"1\"><font><sz val=\"11\"/><color rgb=\"FF000000\"/><name val=\"Calibri\"/><family val=\"2\"/></font></fonts>\n<fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills>\n<borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders>\n<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>\n<cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/></cellXfs>\n<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>\n<dxfs count=\"0\"/>\n<tableStyles count=\"0\" defaultTableStyle=\"TableStyleMedium9\" defaultPivotStyle=\"PivotStyleLight16\"/>\n</styleSheet>"
    }
    
    private func generateThemeXML() -> String {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"Office Theme\">\n<a:themeElements>\n<a:clrScheme name=\"Office\"><a:dk1><a:sysClr val=\"windowText\" lastClr=\"000000\"/></a:dk1><a:lt1><a:sysClr val=\"window\" lastClr=\"FFFFFF\"/></a:lt1><a:dk2><a:srgbClr val=\"1F497D\"/></a:dk2><a:lt2><a:srgbClr val=\"EEECE1\"/></a:lt2><a:accent1><a:srgbClr val=\"4F81BD\"/></a:accent1><a:accent2><a:srgbClr val=\"C0504D\"/></a:accent2><a:accent3><a:srgbClr val=\"9BBB59\"/></a:accent3><a:accent4><a:srgbClr val=\"8064A2\"/></a:accent4><a:accent5><a:srgbClr val=\"4BACC6\"/></a:accent5><a:accent6><a:srgbClr val=\"F79646\"/></a:accent6><a:hlink><a:srgbClr val=\"0000FF\"/></a:hlink><a:folHlink><a:srgbClr val=\"800080\"/></a:folHlink></a:clrScheme>\n<a:fontScheme name=\"Office\"><a:majorFont><a:latin typeface=\"Calibri\"/></a:majorFont><a:minorFont><a:latin typeface=\"Calibri\"/></a:minorFont></a:fontScheme>\n<a:fmtScheme name=\"Office\"><a:fillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w=\"9525\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:prstDash val=\"solid\"/></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>\n</a:themeElements>\n</a:theme>"
    }
    
    private func generateRootRelsXML() -> String {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>\n<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>\n<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>\n</Relationships>"
    }

    private func generateCorePropsXML(flow: Int) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let title = escapeXML("Study Export - \(Self.flowDisplayName(for: flow))")
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n<dc:title>\(title)</dc:title>\n<dc:creator>Education</dc:creator>\n<cp:lastModifiedBy>Education</cp:lastModifiedBy>\n<dcterms:created xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:created>\n<dcterms:modified xsi:type=\"dcterms:W3CDTF\">\(now)</dcterms:modified>\n</cp:coreProperties>"
    }
    
    private func columnLetter(for column: Int) -> String {
        var result = ""; var num = column
        while num > 0 { num -= 1; result = String(Character(UnicodeScalar(65 + (num % 26))!)) + result; num /= 26 }
        return result
    }
    
    private func escapeXML(_ text: String) -> String {
        let sanitized: String = {
            var scalars = String.UnicodeScalarView()
            for s in text.unicodeScalars {
                let v = s.value
                let ok = v == 0x9 || v == 0xA || v == 0xD || (v >= 0x20 && v <= 0xD7FF) || (v >= 0xE000 && v <= 0xFFFD) || (v >= 0x10000 && v <= 0x10FFFF)
                if ok { scalars.append(s) }
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
    
    private func createZipArchive(from sourceDir: URL, to destination: URL) -> Bool {
        do {
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            guard let archive = Archive(url: destination, accessMode: .create) else { return false }
            guard let enumerator = fileManager.enumerator(at: sourceDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return false }
            for case let fileURL as URL in enumerator {
                let rv = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard rv.isRegularFile == true else { continue }
                try archive.addEntry(with: fileURL.path.replacingOccurrences(of: sourceDir.path + "/", with: ""), relativeTo: sourceDir)
            }
            return true
        } catch { return false }
    }
    
    private func generateCSVContent(entries: [InteractionLogEntry]) -> String {
        var content = InteractionLogEntry.csvHeader + "\n"
        for entry in entries { content += entry.csvRow + "\n" }
        return content
    }
    
    private func insertSuffix(_ suffix: String, intoFileName fileName: String) -> String {
        guard let dotIndex = fileName.lastIndex(of: ".") else { return fileName + suffix }
        return String(fileName[..<dotIndex]) + suffix + String(fileName[dotIndex...])
    }
    
    private func generateFileName(flow: Int) -> String {
        let df = DateFormatter(); df.dateFormat = "MMdd_HHmmss"
        return "SA_\(Self.flowName(for: flow))_\(df.string(from: Date())).csv"
    }
    
    private func saveToFile(content: String, fileName: String) -> URL? {
        guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let logsDir = docsDir.appendingPathComponent("InteractionLogs", isDirectory: true)
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let fileURL = logsDir.appendingPathComponent(fileName)
        do { try content.write(to: fileURL, atomically: true, encoding: .utf8); return fileURL }
        catch { return nil }
    }
    
    // MARK: - Data Management
    
    func clearData(for flow: Int) {
        entries[flow] = []; screenDurations[flow] = [:]
        if flow == currentFlow { entryCount = 0 }
    }
    
    func clearAllData() {
        entries = [1: [], 2: [], 3: []]; screenDurations = [1: [:], 2: [:], 3: [:]]
        entryCount = 0
    }
    
    func getEntryCount(for flow: Int) -> Int { entries[flow]?.count ?? 0 }
    func getAllEntries(for flow: Int) -> [InteractionLogEntry] { entries[flow] ?? [] }
    
    private func formatTrialTime(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let minutes = Int(interval) / 60; let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    func logInteraction(_ event: TouchEventType, objectType: ObjectType, label: String, location: CGPoint = .zero, additionalInfo: String = "") -> some View {
        self.onAppear { }
    }
    func trackScreen(_ screenName: String) -> some View {
        self.onAppear { InteractionLogger.shared.setCurrentScreen(screenName) }
    }
}

// MARK: - Gesture Logging Modifier

struct InteractionLoggingModifier: ViewModifier {
    let objectType: ObjectType
    let label: String
    @State private var touchStartLocation: CGPoint = .zero
    @State private var touchStartTime: Date = Date()
    
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if value.translation == .zero {
                        touchStartLocation = value.location; touchStartTime = Date()
                        InteractionLogger.shared.log(event: .touchDown, objectType: objectType, label: label, location: value.location)
                    } else {
                        InteractionLogger.shared.log(event: .touchMove, objectType: objectType, label: label, location: value.location)
                    }
                }
                .onEnded { value in
                    let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                    let duration = Date().timeIntervalSince(touchStartTime)
                    InteractionLogger.shared.log(event: .touchUp, objectType: objectType, label: label, location: value.location)
                    if distance < 10 && duration < 0.3 {
                        InteractionLogger.shared.log(event: .tap, objectType: objectType, label: label, location: value.location)
                    } else if distance < 10 && duration >= 0.5 {
                        InteractionLogger.shared.log(event: .longPress, objectType: objectType, label: label, location: value.location)
                    } else if distance >= 50 {
                        let horizontal = abs(value.translation.width) > abs(value.translation.height)
                        let event: TouchEventType = horizontal ? (value.translation.width > 0 ? .swipeRight : .swipeLeft) : (value.translation.height > 0 ? .swipeDown : .swipeUp)
                        InteractionLogger.shared.log(event: event, objectType: objectType, label: label, location: value.location)
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
