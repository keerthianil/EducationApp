//
//  InteractionLogger.swift
//  Education
//
//  Data logging service for user interaction tracking
//  Logs gestures, events, and accessibility interactions per flow
//

import Foundation
import UIKit
import SwiftUI
import Combine

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
    
    func exportAllFlows() -> [URL] {
        var urls: [URL] = []
        for flow in 1...3 {
            if let url = exportToCSV(flow: flow) {
                urls.append(url)
            }
        }
        return urls
    }
    
    private func generateCSVContent(entries: [InteractionLogEntry]) -> String {
        var content = InteractionLogEntry.csvHeader + "\n"
        for entry in entries {
            content += entry.csvRow + "\n"
        }
        return content
    }
    
    // Short but meaningful: SA_F1_0208_1430.csv
    private func generateFileName(flow: Int) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMdd_HHmm"
        let ts = df.string(from: sessionStartTime ?? Date())
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
