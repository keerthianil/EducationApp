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
        // Escape quotes in strings for CSV
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
            }
            
            self.logInternal(
                event: .screenTransition,
                objectType: .background,
                label: "Session Started",
                location: .zero,
                additionalInfo: "Flow \(flow) session began at \(Date())"
            )
        }
        
        print("[InteractionLogger] Session started for Flow \(flow)")
    }
    
    func endSession() {
        guard isLogging else { return }
        
        log(
            event: .screenTransition,
            objectType: .background,
            label: "Session Ended",
            location: .zero,
            additionalInfo: "Flow \(currentFlow) session ended"
        )
        
        isLogging = false
        print("[InteractionLogger] Session ended for Flow \(currentFlow) with \(entryCount) entries")
    }
    
    func setCurrentScreen(_ screenName: String) {
        let previousScreen = currentScreenName
        currentScreenName = screenName
        
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
    
    func logTap(
        objectType: ObjectType,
        label: String,
        location: CGPoint = .zero,
        additionalInfo: String = ""
    ) {
        log(
            event: .tap,
            objectType: objectType,
            label: label,
            location: location,
            additionalInfo: additionalInfo
        )
    }
    
    func logDoubleTap(
        objectType: ObjectType,
        label: String,
        location: CGPoint = .zero,
        additionalInfo: String = ""
    ) {
        log(
            event: .doubleTap,
            objectType: objectType,
            label: label,
            location: location,
            additionalInfo: additionalInfo
        )
    }
    
    func logVoiceOverFocus(
        objectType: ObjectType,
        label: String,
        additionalInfo: String = ""
    ) {
        log(
            event: .voFocus,
            objectType: objectType,
            label: label,
            location: .zero,
            additionalInfo: additionalInfo
        )
    }
    
    func logVoiceOverActivate(
        objectType: ObjectType,
        label: String,
        additionalInfo: String = ""
    ) {
        log(
            event: .voActivate,
            objectType: objectType,
            label: label,
            location: .zero,
            additionalInfo: additionalInfo
        )
    }
    
    func logSwipe(
        direction: TouchEventType,
        objectType: ObjectType = .background,
        label: String = "",
        additionalInfo: String = ""
    ) {
        log(
            event: direction,
            objectType: objectType,
            label: label,
            location: .zero,
            additionalInfo: additionalInfo
        )
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
    
    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnnouncementFinished),
            name: UIAccessibility.announcementDidFinishNotification,
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
    
    private func generateFileName(flow: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        return "StemAlly_Flow\(flow)_\(timestamp).csv"
    }
    
    private func saveToFile(content: String, fileName: String) -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let logsDirectory = documentsDirectory.appendingPathComponent("InteractionLogs", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
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
        if flow == currentFlow {
            entryCount = 0
        }
    }
    
    func clearAllData() {
        entries = [1: [], 2: [], 3: []]
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
        self.onAppear {
            // Can be used for automatic logging on appear if needed
        }
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
                        let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
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
                            // Determine swipe direction
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
