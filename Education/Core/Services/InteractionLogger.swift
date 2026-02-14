//
//  InteractionLogger.swift
//  Education
//
//  Export: CSV with 3 sections (Overall, Graphics, Math) in one file.

import Foundation
import UIKit
import SwiftUI
import Combine

// MARK: - Event Types

enum TouchEventType: String {
    case touchDown = "Touch Down"; case touchMove = "Touch Move"; case touchUp = "Touch Up"
    case tap = "Tap"; case doubleTap = "Double Tap"; case longPress = "Long Press"
    case swipeLeft = "Swipe Left"; case swipeRight = "Swipe Right"
    case swipeUp = "Swipe Up"; case swipeDown = "Swipe Down"
    case threeFingerSwipe = "3-Finger Swipe"; case twoFingerSwipe = "2-Finger Swipe"
    case pinch = "Pinch"; case pan = "Pan"
    case voFocus = "VO Focus"; case voActivate = "VO Activate"; case voEscape = "VO Escape"
    case voScroll = "VO Scroll"; case voRotorChange = "VO Rotor Change"
    case voMagicTap = "VO Magic Tap"; case voAnnouncement = "VO Announcement"
    case pageChange = "Page Change"; case screenTransition = "Screen Transition"
    case mathModeEnter = "Math Mode Enter"; case mathModeExit = "Math Mode Exit"
    case mathNavigate = "Math Navigate"; case mathLevelChange = "Math Level Change"
    case uploadStart = "Upload Start"; case uploadConfirm = "Upload Confirm"; case uploadComplete = "Upload Complete"
    case tabChange = "Tab Change"; case menuOpen = "Menu Open"; case menuClose = "Menu Close"
    case documentOpen = "Document Open"; case documentClose = "Document Close"
    case sessionStart = "Session Start"; case sessionEnd = "Session End"
    case screenDurationSummary = "Screen Duration"; case idleTime = "Idle Time"
}

enum ObjectType: String {
    case button = "Button"; case tab = "Tab"; case card = "Card"; case listRow = "List Row"
    case mathEquation = "Math Equation"; case heading = "Heading"; case paragraph = "Paragraph"
    case image = "Image"; case svg = "SVG"; case background = "Background"
    case navigationBar = "Navigation Bar"; case uploadArea = "Upload Area"
    case fileCard = "File Card"; case processingCard = "Processing Card"; case banner = "Banner"
    case pageControl = "Page Control"; case textField = "Text Field"; case menu = "Menu"
    case dialog = "Dialog"; case scrollView = "Scroll View"; case webView = "Web View"
    case document = "Document"; case session = "Session"; case unknown = "Unknown"
}

enum RotorFunction: String {
    case none = "None"; case headings = "Headings"; case links = "Links"
    case formControls = "Form Controls"; case containers = "Containers"
    case characters = "Characters"; case words = "Words"; case lines = "Lines"
    case mathNavigation = "Math Navigation"; case adjustValue = "Adjust Value"
}

// MARK: - Log Entry

struct InteractionLogEntry: Codable {
    let timeStamp: String; let trialTime: String; let touchEvent: String
    let objectType: String; let objectLabel: String
    let touchX: Double; let touchY: Double
    let condition: String; let screenName: String
    let rotorFunction: String; let additionalInfo: String

    var csvRow: String {
        "\(timeStamp),\(trialTime),\(touchEvent),\(objectType),\"\(objectLabel.replacingOccurrences(of: "\"", with: "\"\""))\",\(touchX),\(touchY),\(condition),\(screenName),\(rotorFunction),\"\(additionalInfo.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    static var csvHeader: String {
        "Time Stamp,Trial Time,Touch Event,Object Type,Object Label,Touch X,Touch Y,Condition,Screen Name,Rotor Function,Additional Info"
    }
}

// MARK: - Logger

final class InteractionLogger: ObservableObject {
    static let shared = InteractionLogger()

    @Published private(set) var isLogging = false
    @Published private(set) var currentFlow = 1
    @Published private(set) var entryCount = 0

    private var sessionStartTime: Date?
    private var entries: [Int: [InteractionLogEntry]] = [1: [], 2: [], 3: []]
    private var currentRotorFunction: RotorFunction = .none
    private var currentScreenName = "Unknown"
    private var screenDurations: [Int: [String: TimeInterval]] = [1: [:], 2: [:], 3: [:]]
    private var currentScreenEntryTime: Date?
    private var lastInteractionTime: Date?
    private let idleThreshold: TimeInterval = 5.0
    private var currentDocumentTitle: String?
    private var documentOpenTime: Date?
    private var lastLoggedEvent: (event: String, label: String, time: Date)?

    private let dateFormatter: DateFormatter = {
        let d = DateFormatter(); d.dateFormat = "HH:mm:ss.S"; return d
    }()
    private let fm = FileManager.default
    private let logQueue = DispatchQueue(label: "com.stemalley.logger", qos: .utility)

    private init() { setupObservers() }

    static func flowName(for f: Int) -> String {
        [1: "Practice", 2: "Scenario1", 3: "Scenario2"][f] ?? "Flow\(f)"
    }
    static func flowDisplayName(for f: Int) -> String {
        [1: "Practice Scenario", 2: "Scenario 1", 3: "Scenario 2"][f] ?? "Flow \(f)"
    }
    static func flowConditionLabel(for f: Int) -> String {
        [1: "Practice Scenario", 2: "Scenario 1", 3: "Scenario 2"][f] ?? "Flow \(f)"
    }

    // MARK: - Session

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
            let vo = UIAccessibility.isVoiceOverRunning ? "ON" : "OFF"
            self.logInternal(event: .sessionStart, objectType: .session, label: "Session Started", location: .zero, additionalInfo: "\(Self.flowDisplayName(for: flow)) | VO: \(vo) | \(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)")
        }
    }

    func endSession() {
        guard isLogging else { return }
        recordScreenDuration()
        if let d = currentDocumentTitle { logDocumentClose(title: d) }
        if let dur = screenDurations[currentFlow] {
            for (s, d) in dur.sorted(by: { $0.key < $1.key }) {
                log(event: .screenDurationSummary, objectType: .session, label: s, location: .zero, additionalInfo: "Duration: \(String(format: "%.1f", d))s")
            }
        }
        let total: String
        if let s = sessionStartTime { let sec = Date().timeIntervalSince(s); total = "\(Int(sec)/60)m \(Int(sec)%60)s" } else { total = "?" }
        log(event: .sessionEnd, objectType: .session, label: "Session Ended", location: .zero, additionalInfo: "\(Self.flowDisplayName(for: currentFlow)) | Duration: \(total) | Entries: \(entryCount)")
        isLogging = false
    }

    func setCurrentScreen(_ name: String) {
        let prev = currentScreenName
        if prev != name { recordScreenDuration() }
        currentScreenName = name; currentScreenEntryTime = Date()
        if prev != name && isLogging {
            log(event: .screenTransition, objectType: .background, label: name, location: .zero, additionalInfo: "From: \(prev)")
        }
    }

    private func recordScreenDuration() {
        guard let t = currentScreenEntryTime else { return }
        if screenDurations[currentFlow] == nil { screenDurations[currentFlow] = [:] }
        screenDurations[currentFlow]?[currentScreenName, default: 0] += Date().timeIntervalSince(t)
    }

    func logDocumentClose(title: String) {
        guard currentDocumentTitle != nil else { return }
        let dur = documentOpenTime.map { String(format: "%.1f", Date().timeIntervalSince($0)) + "s" } ?? "?"
        log(event: .documentClose, objectType: .document, label: title, location: .zero, additionalInfo: "Duration: \(dur)")
        currentDocumentTitle = nil; documentOpenTime = nil
    }

    func logDocumentOpen(title: String) {
        if currentDocumentTitle == title { return }
        if let p = currentDocumentTitle { logDocumentClose(title: p) }
        currentDocumentTitle = title; documentOpenTime = Date()
        log(event: .documentOpen, objectType: .document, label: title, location: .zero, additionalInfo: "Opened")
    }

    // MARK: - Log

    func log(event: TouchEventType, objectType: ObjectType, label: String, location: CGPoint, rotorFunction: RotorFunction? = nil, additionalInfo: String = "") {
        logQueue.async { [weak self] in
            self?.logInternal(event: event, objectType: objectType, label: label, location: location, rotorFunction: rotorFunction, additionalInfo: additionalInfo)
        }
    }

    private func logInternal(event: TouchEventType, objectType: ObjectType, label: String, location: CGPoint, rotorFunction: RotorFunction? = nil, additionalInfo: String = "") {
        guard isLogging, let start = sessionStartTime else { return }
        let now = Date()
        if let last = lastLoggedEvent, last.event == event.rawValue, last.label == label, now.timeIntervalSince(last.time) < 0.1 { return }
        lastLoggedEvent = (event.rawValue, label, now)

        let ts = dateFormatter.string(from: now)
        let tt = formatTrialTime(from: start, to: now)

        if let lt = lastInteractionTime, now.timeIntervalSince(lt) >= idleThreshold {
            let idle = InteractionLogEntry(timeStamp: ts, trialTime: tt, touchEvent: "Idle Time", objectType: "Background", objectLabel: "Idle", touchX: 0, touchY: 0, condition: Self.flowConditionLabel(for: currentFlow), screenName: currentScreenName, rotorFunction: "None", additionalInfo: "Idle \(String(format: "%.1f", now.timeIntervalSince(lt)))s")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.entries[self.currentFlow, default: []].append(idle)
            }
        }
        lastInteractionTime = now

        let entry = InteractionLogEntry(timeStamp: ts, trialTime: tt, touchEvent: event.rawValue, objectType: objectType.rawValue, objectLabel: label, touchX: round(location.x*10)/10, touchY: round(location.y*10)/10, condition: Self.flowConditionLabel(for: currentFlow), screenName: currentScreenName, rotorFunction: (rotorFunction ?? currentRotorFunction).rawValue, additionalInfo: additionalInfo)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entries[self.currentFlow, default: []].append(entry)
            self.entryCount = self.entries[self.currentFlow]?.count ?? 0
        }
    }

    // Convenience
    func logTap(objectType: ObjectType, label: String, location: CGPoint = .zero, additionalInfo: String = "") { log(event: .tap, objectType: objectType, label: label, location: location, additionalInfo: additionalInfo) }
    func logDoubleTap(objectType: ObjectType, label: String, location: CGPoint = .zero, additionalInfo: String = "") { log(event: .doubleTap, objectType: objectType, label: label, location: location, additionalInfo: additionalInfo) }
    func logSwipe(direction: TouchEventType, objectType: ObjectType = .background, label: String = "", additionalInfo: String = "") { log(event: direction, objectType: objectType, label: label, location: .zero, additionalInfo: additionalInfo) }
    func logVoiceOverFocus(objectType: ObjectType, label: String, additionalInfo: String = "") { log(event: .voFocus, objectType: objectType, label: label, location: .zero, additionalInfo: additionalInfo) }
    func logVoiceOverActivate(objectType: ObjectType, label: String, additionalInfo: String = "") { log(event: .voActivate, objectType: objectType, label: label, location: .zero, additionalInfo: additionalInfo) }
    func setRotorFunction(_ r: RotorFunction) {
        if currentRotorFunction != r {
            let p = currentRotorFunction; currentRotorFunction = r
            log(event: .voRotorChange, objectType: .background, label: r.rawValue, location: .zero, additionalInfo: "From \(p.rawValue)")
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(voChanged), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(announceDone(_:)), name: UIAccessibility.announcementDidFinishNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(elementFocused(_:)), name: UIAccessibility.elementFocusedNotification, object: nil)
    }

    @objc private func voChanged() { log(event: .voFocus, objectType: .background, label: "VoiceOver \(UIAccessibility.isVoiceOverRunning ? "On" : "Off")", location: .zero) }

    @objc private func announceDone(_ n: Notification) {
        if let a = n.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String {
            log(event: .voAnnouncement, objectType: .background, label: String(a.prefix(100)), location: .zero)
        }
    }

    @objc private func elementFocused(_ n: Notification) {
        guard let ui = n.userInfo, let el = ui[UIAccessibility.focusedElementUserInfoKey] else { return }
        var label = "Unknown"; var ot: ObjectType = .unknown
        if let o = el as? NSObject {
            if let l = o.accessibilityLabel, !l.isEmpty { label = l }
            else if let v = o.accessibilityValue, !v.isEmpty { label = v }
            else if let v = o as? UIView, let i = v.accessibilityIdentifier, !i.isEmpty { label = i }
            let t = o.accessibilityTraits
            if t.contains(.header) { ot = .heading }
            else if t.contains(.button) { ot = .button }
            else if t.contains(.image) { ot = .image }
            else if t.contains(.staticText) { ot = .paragraph }
        }
        log(event: .voFocus, objectType: ot, label: String(label.prefix(100)), location: .zero, additionalInfo: "VO focused")
    }

    // MARK: - Export: Multi-Section CSV (replaces broken XLSX)
    //
    // Single CSV with 3 sections separated by header rows:
    //   === OVERALL ===
    //   === GRAPHICS ===
    //   === MATH ===
    // Opens correctly in Excel, Sheets, Numbers.

    func exportFlowAsExcel(flow: Int) -> URL? {
        exportFlowAsMultiSectionCSV(flow: flow)
    }

    func exportAllFlowsAsExcel() -> [URL] {
        (1...3).compactMap { exportFlowAsMultiSectionCSV(flow: $0) }
    }

    private func exportFlowAsMultiSectionCSV(flow: Int) -> URL? {
        guard let all = entries[flow], !all.isEmpty else { return nil }
        let graphics = all.filter { $0.objectType == ObjectType.svg.rawValue }
        let math = all.filter { $0.objectType == ObjectType.mathEquation.rawValue }

        var lines: [String] = []

        lines.append("=== OVERALL INTERACTIONS (\(all.count) entries) ===")
        lines.append(InteractionLogEntry.csvHeader)
        lines.append(contentsOf: all.map { $0.csvRow })
        lines.append("")

        lines.append("=== GRAPHICS INTERACTIONS (\(graphics.count) entries) ===")
        lines.append(InteractionLogEntry.csvHeader)
        lines.append(contentsOf: graphics.map { $0.csvRow })
        lines.append("")

        lines.append("=== MATH INTERACTIONS (\(math.count) entries) ===")
        lines.append(InteractionLogEntry.csvHeader)
        lines.append(contentsOf: math.map { $0.csvRow })

        let content = lines.joined(separator: "\n")
        return saveCSV(content, name: "SA_\(Self.flowName(for: flow))_\(ts()).csv")
    }

    // MARK: - Export: Simple CSV (one section per file)

    func exportToCSV(flow: Int) -> URL? {
        guard let e = entries[flow], !e.isEmpty else { return nil }
        return saveCSV(csv(e), name: "SA_\(Self.flowName(for: flow))_\(ts()).csv")
    }
    func exportAllFlows() -> [URL] { (1...3).compactMap { exportToCSV(flow: $0) } }

    // MARK: - Export: PDF

    func exportFlowAsPDF(flow: Int) -> URL? {
        guard let all = entries[flow], !all.isEmpty else { return nil }
        return generatePDF(flow: flow, entries: all)
    }
    func exportAllFlowsAsPDF() -> [URL] { (1...3).compactMap { exportFlowAsPDF(flow: $0) } }

    private func generatePDF(flow: Int, entries: [InteractionLogEntry]) -> URL? {
        let pw: CGFloat = 792; let ph: CGFloat = 612; let m: CGFloat = 30; let lh: CGFloat = 11; let hh: CGFloat = 20
        let cols: [(String, CGFloat)] = [("Time",50),("Trial",46),("Event",74),("Object",56),("Label",145),("X",30),("Y",30),("Cond",56),("Screen",90),("Rotor",50),("Info",105)]
        let hAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: UIColor.white]
        let cAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: UIColor.black]
        let teal = UIColor(red: 0.11, green: 0.39, blue: 0.44, alpha: 1)
        let rpp = Int((ph - m*2 - hh - 30) / lh)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pw, height: ph))
        let data = renderer.pdfData { ctx in
            var ri = 0; var pg = 0
            while ri < entries.count {
                ctx.beginPage(); pg += 1
                let title = "\(Self.flowDisplayName(for: flow)) — \(entries.count) entries"
                (title as NSString).draw(at: CGPoint(x: m, y: m), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12)])
                ("Page \(pg)" as NSString).draw(at: CGPoint(x: pw - m - 50, y: ph - m + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: UIColor.gray])
                let ty = m + 22; var x = m; teal.setFill()
                UIBezierPath(rect: CGRect(x: m, y: ty, width: pw - m*2, height: hh)).fill()
                for (t, w) in cols { (t as NSString).draw(in: CGRect(x: x+2, y: ty+4, width: w-4, height: 12), withAttributes: hAttr); x += w }
                var y = ty + hh
                for _ in 0..<rpp {
                    guard ri < entries.count else { break }
                    let e = entries[ri]
                    if ri % 2 == 0 { UIColor(white: 0.96, alpha: 1).setFill(); UIBezierPath(rect: CGRect(x: m, y: y, width: pw - m*2, height: lh)).fill() }
                    let vals = [e.timeStamp, e.trialTime, e.touchEvent, e.objectType, String(e.objectLabel.prefix(35)), String(e.touchX), String(e.touchY), e.condition, String(e.screenName.prefix(18)), e.rotorFunction, String(e.additionalInfo.prefix(22))]
                    x = m; for (i, (_, w)) in cols.enumerated() { (vals[i] as NSString).draw(in: CGRect(x: x+2, y: y+1, width: w-4, height: lh), withAttributes: cAttr); x += w }
                    y += lh; ri += 1
                }
            }
        }
        guard let dir = makeLogsDir() else { return nil }
        let url = dir.appendingPathComponent("SA_\(Self.flowName(for: flow))_\(ts()).pdf")
        do { try data.write(to: url); return url } catch { return nil }
    }

    // MARK: - Data

    func clearData(for f: Int) { entries[f] = []; screenDurations[f] = [:]; if f == currentFlow { entryCount = 0 } }
    func clearAllData() { entries = [1:[],2:[],3:[]]; screenDurations = [1:[:],2:[:],3:[:]]; entryCount = 0 }
    func getEntryCount(for f: Int) -> Int { entries[f]?.count ?? 0 }
    func getAllEntries(for f: Int) -> [InteractionLogEntry] { entries[f] ?? [] }

    // MARK: - Helpers

    private func formatTrialTime(from s: Date, to e: Date) -> String {
        let i = e.timeIntervalSince(s)
        return String(format: "%02d:%02d.%d", Int(i)/60, Int(i)%60, Int((i.truncatingRemainder(dividingBy: 1))*10))
    }
    private func ts() -> String { let d = DateFormatter(); d.dateFormat = "MMdd_HHmmss"; return d.string(from: Date()) }
    private func makeLogsDir() -> URL? {
        guard let d = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let l = d.appendingPathComponent("InteractionLogs")
        try? fm.createDirectory(at: l, withIntermediateDirectories: true)
        return l
    }
    private func csv(_ entries: [InteractionLogEntry]) -> String {
        InteractionLogEntry.csvHeader + "\n" + entries.map { $0.csvRow }.joined(separator: "\n")
    }
    private func saveCSV(_ content: String, name: String) -> URL? {
        guard let d = makeLogsDir() else { return nil }
        let u = d.appendingPathComponent(name)
        try? content.write(to: u, atomically: true, encoding: .utf8)
        return u
    }
}

// MARK: - View Extensions

extension View {
    func logInteraction(_ event: TouchEventType, objectType: ObjectType, label: String, location: CGPoint = .zero, additionalInfo: String = "") -> some View {
        self.onAppear {}
    }
    func trackScreen(_ screenName: String) -> some View {
        self.onAppear { InteractionLogger.shared.setCurrentScreen(screenName) }
    }
}

struct InteractionLoggingModifier: ViewModifier {
    let objectType: ObjectType; let label: String
    @State private var touchStart: CGPoint = .zero; @State private var touchTime = Date()
    func body(content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                if v.translation == .zero {
                    touchStart = v.location; touchTime = Date()
                    InteractionLogger.shared.log(event: .touchDown, objectType: objectType, label: label, location: v.location)
                }
            }
            .onEnded { v in
                let d = sqrt(pow(v.translation.width,2)+pow(v.translation.height,2))
                InteractionLogger.shared.log(event: .touchUp, objectType: objectType, label: label, location: v.location)
                if d < 10 && Date().timeIntervalSince(touchTime) < 0.3 {
                    InteractionLogger.shared.log(event: .tap, objectType: objectType, label: label, location: v.location)
                } else if d >= 50 {
                    let h = abs(v.translation.width) > abs(v.translation.height)
                    InteractionLogger.shared.log(event: h ? (v.translation.width > 0 ? .swipeRight : .swipeLeft) : (v.translation.height > 0 ? .swipeDown : .swipeUp), objectType: objectType, label: label, location: v.location)
                }
            })
    }
}

extension View {
    func logTouches(objectType: ObjectType, label: String) -> some View {
        modifier(InteractionLoggingModifier(objectType: objectType, label: label))
    }
}
