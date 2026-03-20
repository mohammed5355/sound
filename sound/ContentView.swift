import SwiftUI
import Combine
import AVFoundation
import PhotosUI

// MARK: - Library Track Model
struct LibraryTrack: Identifiable, Codable {
    let id: UUID
    let name: String
    let duration: Double
    let dateAdded: Date
    let filePath: String  // Now stores only the file name, not the full path

    init(id: UUID = UUID(), name: String, duration: Double, filePath: String) {
        self.id = id
        self.name = name
        self.duration = duration
        self.dateAdded = Date()
        self.filePath = filePath
    }

    func getURL() -> URL? {
        // Reconstruct full path at runtime
        return LibraryFileManager.shared.getURL(for: filePath)
    }
}

// MARK: - File Manager Helper
class LibraryFileManager {
    static let shared = LibraryFileManager()

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var libraryDirectory: URL {
        var libraryDir = documentsDirectory.appendingPathComponent("Library", isDirectory: true)
        if !FileManager.default.fileExists(atPath: libraryDir.path) {
            try? FileManager.default.createDirectory(at: libraryDir, withIntermediateDirectories: true)
            // Exclude from iCloud backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? libraryDir.setResourceValues(resourceValues)
        }
        return libraryDir
    }

    func getURL(for fileName: String) -> URL {
        return libraryDirectory.appendingPathComponent(fileName)
    }

    func copyToLibrary(url: URL) -> String? {
        let fileName = UUID().uuidString + "_" + url.lastPathComponent
        var destination = libraryDirectory.appendingPathComponent(fileName)

        // If file already exists at destination, return the file name
        if FileManager.default.fileExists(atPath: destination.path) {
            return fileName
        }

        do {
            // For iCloud files, ensure they're downloaded first
            if url.isFileURL {
                let resourceValues = try url.resourceValues(forKeys: [.isUbiquitousItemKey])
                if resourceValues.isUbiquitousItem == true {
                    // Trigger download from iCloud
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                }
            }

            // Copy file to local storage
            try FileManager.default.copyItem(at: url, to: destination)

            // Exclude from iCloud backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try destination.setResourceValues(resourceValues)

            return fileName
        } catch {
            return nil
        }
    }

    func deleteFile(at fileName: String) {
        let fullPath = libraryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fullPath)
    }

    func fileExists(at fileName: String) -> Bool {
        let fullPath = libraryDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fullPath.path)
    }

    func saveDataToLibrary(data: Data, fileName: String) -> String? {
        let uniqueFileName = UUID().uuidString + "_" + fileName
        var destination = libraryDirectory.appendingPathComponent(uniqueFileName)

        do {
            try data.write(to: destination)

            // Exclude from iCloud backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try destination.setResourceValues(resourceValues)

            return uniqueFileName
        } catch {
            return nil
        }
    }
}

// MARK: - Library Manager
class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    private let key = "savedLibrary"

    @Published var tracks: [LibraryTrack] = []

    private init() {
        load()
    }

    func addTrackFromLocalFile(name: String, duration: Double, localPath: String, allowDuplicate: Bool = false) {
        // Check if already exists by name (unless duplicates are allowed)
        if !allowDuplicate && tracks.contains(where: { $0.name == name }) { return }

        let track = LibraryTrack(name: name, duration: duration, filePath: localPath)
        tracks.insert(track, at: 0)
        save()
    }

    func replaceTrack(name: String, duration: Double, localPath: String) {
        // Find and remove the existing track with the same name
        if let index = tracks.firstIndex(where: { $0.name == name }) {
            tracks.remove(at: index)
        }

        // Add the new track at the top
        let track = LibraryTrack(name: name, duration: duration, filePath: localPath)
        tracks.insert(track, at: 0)
        save()
    }

    func deleteTrack(at offsets: IndexSet) {
        for index in offsets {
            let track = tracks[index]
            LibraryFileManager.shared.deleteFile(at: track.filePath)
        }
        tracks.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LibraryTrack].self, from: data) else { return }
        tracks = decoded
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var player = AudioPlayerManager()
    @StateObject private var library = LibraryManager.shared
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                if selectedTab == 0 {
                    PlayerView(player: player, library: library)
                } else {
                    LibraryView(player: player, library: library, selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom Bottom Navigation
            HStack(spacing: 0) {
                // Player Tab
                Button(action: { selectedTab = 0 }) {
                    VStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("المشغل")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == 0 ? .white : Color(hex: "757575"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(selectedTab == 0 ? Color(hex: "1E88E5") : Color.clear)
                    )
                }

                // Library Tab
                Button(action: { selectedTab = 1 }) {
                    VStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20, weight: .semibold))
                        Text("المكتبة")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == 1 ? .white : Color(hex: "757575"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(selectedTab == 1 ? Color(hex: "1E88E5") : Color.clear)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(
                Color.white
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -5)
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Player View
struct PlayerView: View {
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var library: LibraryManager

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 8) {
                    if player.fileName.isEmpty {
                        Text("اختر مقطعاً")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "757575"))
                    } else {
                        Text(player.fileName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "212121"))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 16) {

                        // MARK: - Progress Section Card
                        VStack(spacing: 16) {
                            // Progress Slider with larger thumb
                            NewProgressSlider(
                                value: $player.currentTime,
                                duration: player.duration,
                                onSeek: { player.seekTo($0) }
                            )
                            .frame(height: 32)

                            // RTL Time Display: remaining on left, elapsed on right
                            HStack {
                                // Remaining time (left in RTL = right visually)
                                Text("-\(player.formatTime(max(0, player.duration - player.currentTime)))")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(Color(hex: "757575"))

                                Spacer()

                                // Elapsed time (right in RTL = left visually)
                                Text(player.formatTime(player.currentTime))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(Color(hex: "757575"))
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                        // MARK: - A-B Loop Section Card
                        VStack(spacing: 16) {
                            Text("تكرار المقطع")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "212121"))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // RTL: A on right, B on left, toggle in center
                            HStack(spacing: 12) {
                                // B Button (left side in RTL layout)
                                NewLoopPointButton(
                                    label: "B",
                                    time: player.loopB,
                                    isActive: player.loopB != nil,
                                    format: player.formatTime
                                ) {
                                    player.setB()
                                    hapticFeedback()
                                }

                                // Toggle in center
                                Button(action: {
                                    if player.loopA != nil && player.loopB != nil {
                                        player.loopEnabled.toggle()
                                        hapticFeedback()
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: player.loopEnabled ? "repeat.1" : "repeat")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(player.loopA != nil && player.loopB != nil ? Color(hex: "1E88E5") : Color(hex: "BDBDBD"))
                                            .frame(width: 56, height: 56)
                                            .background(
                                                Circle()
                                                    .fill(player.loopEnabled && player.loopA != nil && player.loopB != nil ? Color(hex: "1E88E5").opacity(0.12) : Color(hex: "F5F5F7"))
                                            )
                                        Text(player.loopEnabled ? "مفعل" : "إيقاف")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(hex: "757575"))
                                    }
                                }

                                // A Button (right side in RTL layout)
                                NewLoopPointButton(
                                    label: "A",
                                    time: player.loopA,
                                    isActive: player.loopA != nil,
                                    format: player.formatTime
                                ) {
                                    player.setA()
                                    hapticFeedback()
                                }
                            }

                            // Clear Button
                            Button(action: {
                                player.clearLoop()
                                hapticFeedback()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("مسح")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color(hex: "757575"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "F5F5F7"))
                                .cornerRadius(20)
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                        // MARK: - Speed Control Card
                        NewControlCard(
                            icon: "speedometer",
                            title: "السرعة",
                            value: player.speed,
                            format: { String(format: "%.2fx", $0) },
                            color: Color(hex: "1E88E5"),
                            onDecrease: { player.speed = max(0.5, player.speed - 0.01); player.applySpeed() },
                            onIncrease: { player.speed = min(2.0, player.speed + 0.01); player.applySpeed() },
                            onReset: { player.speed = 1.0; player.applySpeed() },
                            sliderBinding: $player.speed,
                            onSliderChange: { player.applySpeed() }
                        )

                        // MARK: - Pitch Control Card
                        NewControlCard(
                            icon: "waveform.path",
                            title: "الطبقة",
                            value: player.pitch,
                            format: { String(format: "%.2fx", $0) },
                            color: Color(hex: "FF7043"),
                            onDecrease: { player.pitch = max(0.5, player.pitch - 0.01); player.applyPitch() },
                            onIncrease: { player.pitch = min(2.0, player.pitch + 0.01); player.applyPitch() },
                            onReset: { player.pitch = 1.0; player.applyPitch() },
                            sliderBinding: $player.pitch,
                            onSliderChange: { player.applyPitch() }
                        )

                        // Extra spacing for bottom controls and nav
                        Color.clear.frame(height: 140)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }

            // MARK: - Bottom Playback Controls
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    // Repeat Button
                    Button(action: { player.repeatEnabled.toggle(); hapticFeedback() }) {
                        Image(systemName: "repeat")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(player.repeatEnabled ? .white : Color(hex: "757575"))
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(player.repeatEnabled ? Color(hex: "1E88E5") : Color(hex: "F5F5F7"))
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                    // Backward Button
                    Button(action: { player.seek(-5); hapticFeedback() }) {
                        Image(systemName: "gobackward.5")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: "1E88E5"))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color(hex: "F5F5F7")))
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                    // Play/Pause Button (large central)
                    Button(action: { player.togglePlay(); hapticFeedback() }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .offset(x: player.isPlaying ? 0 : 4)
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(Color(hex: "1E88E5")))
                    }
                    .shadow(color: Color(hex: "1E88E5").opacity(0.35), radius: 12, x: 0, y: 6)

                    // Forward Button
                    Button(action: { player.seek(5); hapticFeedback() }) {
                        Image(systemName: "goforward.5")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: "1E88E5"))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color(hex: "F5F5F7")))
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                    // Speed quick toggle
                    Button(action: {
                        if player.speed == 1.0 {
                            player.speed = 1.5
                        } else if player.speed == 1.5 {
                            player.speed = 2.0
                        } else {
                            player.speed = 1.0
                        }
                        player.applySpeed()
                        hapticFeedback()
                    }) {
                        Text(player.speed == 1.0 ? "1×" : String(format: "%.1f×", player.speed))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(player.speed != 1.0 ? .white : Color(hex: "757575"))
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(player.speed != 1.0 ? Color(hex: "1E88E5") : Color(hex: "F5F5F7"))
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                }
                .padding(.bottom, 90)
            }
        }
    }

    func hapticFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Library View
struct LibraryView: View {
    @ObservedObject var player: AudioPlayerManager
    @ObservedObject var library: LibraryManager
    @Binding var selectedTab: Int
    @State private var showDeleteConfirmation = false
    @State private var trackToDelete: LibraryTrack?
    @State private var deleteOffsets: IndexSet?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showRenameAlert = false
    @State private var showDuplicateAlert = false
    @State private var pendingTrackName = ""
    @State private var pendingTrackData: Data?
    @State private var pendingTrackDuration: Double = 0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("المكتبة")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "212121"))

                    Spacer()

                    PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "1E88E5"))
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        if let newItem = newItem {
                            loadMediaFromPhotos(item: newItem)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                if library.tracks.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 64))
                            .foregroundColor(Color(hex: "BDBDBD"))
                        Text("لا توجد ملفات في المكتبة")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "757575"))
                        Text("اضغط + لإضافة مقطع من الصور")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "9E9E9E"))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(library.tracks) { track in
                            NewLibraryTrackRow(track: track, formatTime: player.formatTime) {
                                guard let url = track.getURL() else { return }
                                player.loadFile(url: url, library: nil, saveToLibrary: false, customName: track.name)
                                selectedTab = 0
                            }
                        }
                        .onDelete { offsets in
                            // Store offsets and show confirmation
                            deleteOffsets = offsets
                            if let firstIndex = offsets.first {
                                trackToDelete = library.tracks[firstIndex]
                            }
                            showDeleteConfirmation = true
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .alert("تسمية المقطع", isPresented: $showRenameAlert) {
            TextField("اسم المقطع", text: $pendingTrackName)
            Button("إلغاء", role: .cancel) {
                pendingTrackData = nil
                pendingTrackName = ""
                selectedPhotoItem = nil
            }
            Button("حفظ") {
                savePendingTrack()
            }
        } message: {
            Text("أدخل اسماً للمقطع قبل حفظه في المكتبة")
        }
        .alert("حذف المقطع", isPresented: $showDeleteConfirmation) {
            Button("إلغاء", role: .cancel) {
                deleteOffsets = nil
                trackToDelete = nil
            }
            Button("حذف", role: .destructive) {
                if let offsets = deleteOffsets {
                    library.deleteTrack(at: offsets)
                    hapticFeedback()
                }
                deleteOffsets = nil
                trackToDelete = nil
            }
        } message: {
            if let track = trackToDelete {
                Text("هل أنت متأكد من حذف \"\(track.name)\"؟\nسيتم حذف الملف من الجهاز.")
            } else {
                Text("هل أنت متأكد من الحذف؟")
            }
        }
        .alert("اسم مكرر", isPresented: $showDuplicateAlert) {
            Button("إلغاء", role: .cancel) {
                clearPendingTrack()
            }
            Button("إضافة كجديد") {
                addAsNewTrack()
            }
            Button("استبدال") {
                replaceExistingTrack()
            }
        } message: {
            Text("يوجد مقطع بنفس الاسم \"\(pendingTrackName)\". ماذا تريد أن تفعل؟")
        }
    }

    func loadMediaFromPhotos(item: PhotosPickerItem) {
        Task {
            do {
                // Load the video data
                if let data = try await item.loadTransferable(type: Data.self) {
                    // Save to temp location to get duration
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try data.write(to: tempURL)

                    // Get duration
                    var duration: Double = 0
                    if let audioFile = try? AVAudioFile(forReading: tempURL) {
                        duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
                    }

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)

                    // Store pending data and show rename alert
                    await MainActor.run {
                        pendingTrackData = data
                        pendingTrackDuration = duration
                        pendingTrackName = item.itemIdentifier ?? "مقطع جديد"
                        showRenameAlert = true
                    }
                }
            } catch {
            }
        }
    }

    func savePendingTrack() {
        guard let data = pendingTrackData else { return }

        // Check if name already exists
        if library.tracks.contains(where: { $0.name == pendingTrackName }) {
            showDuplicateAlert = true
            return
        }

        // Save data to library with the user's chosen name
        let localPath = LibraryFileManager.shared.saveDataToLibrary(data: data, fileName: pendingTrackName)

        if let path = localPath {
            library.addTrackFromLocalFile(name: pendingTrackName, duration: pendingTrackDuration, localPath: path, allowDuplicate: false)
            hapticFeedback()
        }

        // Clear pending state
        clearPendingTrack()
    }

    func addAsNewTrack() {
        guard let data = pendingTrackData else { return }

        // Save data to library with the user's chosen name (allow duplicate)
        let localPath = LibraryFileManager.shared.saveDataToLibrary(data: data, fileName: pendingTrackName)

        if let path = localPath {
            library.addTrackFromLocalFile(name: pendingTrackName, duration: pendingTrackDuration, localPath: path, allowDuplicate: true)
            hapticFeedback()
        }

        clearPendingTrack()
    }

    func replaceExistingTrack() {
        guard let data = pendingTrackData else { return }

        // Find and delete the existing track's file
        if let existingTrack = library.tracks.first(where: { $0.name == pendingTrackName }) {
            LibraryFileManager.shared.deleteFile(at: existingTrack.filePath)
        }

        // Save data to library with the user's chosen name
        let localPath = LibraryFileManager.shared.saveDataToLibrary(data: data, fileName: pendingTrackName)

        if let path = localPath {
            library.replaceTrack(name: pendingTrackName, duration: pendingTrackDuration, localPath: path)
            hapticFeedback()
        }

        clearPendingTrack()
    }

    func clearPendingTrack() {
        pendingTrackData = nil
        pendingTrackName = ""
        pendingTrackDuration = 0
        selectedPhotoItem = nil
    }

    func hapticFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Library Track Row
struct LibraryTrackRow: View {
    let track: LibraryTrack
    let formatTime: (Double) -> String
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Play Button
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "2563EB"))
                    .cornerRadius(20)
            }

            // Track Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "1e293b"))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formatTime(track.duration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "64748b"))

                    Text("•")
                        .foregroundColor(Color(hex: "cbd5e1"))

                    Text(formatDate(track.dateAdded))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "94a3b8"))
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - New Library Track Row (Redesigned)
struct NewLibraryTrackRow: View {
    let track: LibraryTrack
    let formatTime: (Double) -> String
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Play Button
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .offset(x: 2)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color(hex: "1E88E5")))
            }
            .shadow(color: Color(hex: "1E88E5").opacity(0.25), radius: 6, x: 0, y: 3)

            // Track Info
            VStack(alignment: .leading, spacing: 6) {
                Text(track.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "212121"))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formatTime(track.duration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "757575"))

                    Text("•")
                        .foregroundColor(Color(hex: "BDBDBD"))

                    Text(formatDate(track.dateAdded))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9E9E9E"))
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "BDBDBD"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(hex: "F5F5F7"))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Progress Slider
struct ProgressSlider: View {
    @Binding var value: Double
    let duration: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "e2e8f0"))
                    .frame(height: 6)

                // Progress
                let progress = duration > 0 ? max(0, min(1, value / duration)) : 0
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "2563EB"))
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: 6)

                // Thumb
                Circle()
                    .fill(Color(hex: "2563EB"))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    )
                    .offset(x: geometry.size.width * CGFloat(progress) - 9)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Double(drag.location.x / geometry.size.width) * duration
                        value = max(0, min(newValue, duration))
                    }
                    .onEnded { drag in
                        let newValue = Double(drag.location.x / geometry.size.width) * duration
                        onSeek(max(0, min(newValue, duration)))
                    }
            )
        }
        .frame(height: 24)
        .environment(\.layoutDirection, .leftToRight)
        .scaleEffect(x: -1)
    }
}

// MARK: - New Progress Slider (Redesigned)
struct NewProgressSlider: View {
    @Binding var value: Double
    let duration: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track - thicker for easier touch
                Capsule()
                    .fill(Color(hex: "E0E0E0"))
                    .frame(height: 8)

                // Progress
                let progress = duration > 0 ? max(0, min(1, value / duration)) : 0
                Capsule()
                    .fill(Color(hex: "1E88E5"))
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: 8)

                // Large circular thumb for easy grabbing
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "1E88E5"), lineWidth: 3)
                    )
                    .overlay(
                        Circle()
                            .fill(Color(hex: "1E88E5"))
                            .frame(width: 10, height: 10)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .offset(x: geometry.size.width * CGFloat(progress) - 14)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Double(drag.location.x / geometry.size.width) * duration
                        value = max(0, min(newValue, duration))
                    }
                    .onEnded { drag in
                        let newValue = Double(drag.location.x / geometry.size.width) * duration
                        onSeek(max(0, min(newValue, duration)))
                    }
            )
        }
        .frame(height: 32)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Control Row
struct ControlRow: View {
    let icon: String
    let title: String
    let value: Double
    let format: (Double) -> String
    let color: Color
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onReset: () -> Void
    @Binding var sliderBinding: Double
    let onSliderChange: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "475569"))
                Button(action: { onReset(); haptic() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                Spacer()
                Text(format(value))
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                Button(action: { onDecrease(); haptic() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                }

                Slider(value: $sliderBinding, in: 0.5...2.0, step: 0.01)
                    .accentColor(color)
                    .onChange(of: sliderBinding) { _, _ in onSliderChange() }

                Button(action: { onIncrease(); haptic() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }

    func haptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - New Control Card (Redesigned)
struct NewControlCard: View {
    let icon: String
    let title: String
    let value: Double
    let format: (Double) -> String
    let color: Color
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onReset: () -> Void
    @Binding var sliderBinding: Double
    let onSliderChange: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header row
            HStack {
                // Icon with colored background
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12))
                    .cornerRadius(10)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "212121"))

                Spacer()

                // Reset button
                Button(action: { onReset(); haptic() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "757575"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(8)
                }

                // Value display
                Text(format(value))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.12))
                    .cornerRadius(8)
            }

            // Slider row
            HStack(spacing: 16) {
                // Decrease button
                Button(action: { onDecrease(); haptic() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(12)
                }

                // Slider
                Slider(value: $sliderBinding, in: 0.5...2.0, step: 0.01)
                    .accentColor(color)
                    .onChange(of: sliderBinding) { _, _ in onSliderChange() }

                // Increase button
                Button(action: { onIncrease(); haptic() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "F5F5F7"))
                        .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color(hex: "F5F5F7"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    func haptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Loop Point Button
struct LoopPointButton: View {
    let label: String
    let time: Double?
    let isActive: Bool
    let format: (Double) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isActive ? .white : Color(hex: "2563EB"))
                Text(time != nil ? format(time!) : "--:--.-")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .white : Color(hex: "64748b"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color(hex: "2563EB") : Color(hex: "f1f5f9"))
            .cornerRadius(12)
        }
    }
}

// MARK: - New Loop Point Button (Redesigned)
struct NewLoopPointButton: View {
    let label: String
    let time: Double?
    let isActive: Bool
    let format: (Double) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Label circle
                Text(label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isActive ? .white : Color(hex: "1E88E5"))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isActive ? Color(hex: "1E88E5") : Color.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "1E88E5"), lineWidth: isActive ? 0 : 2)
                    )
                    .shadow(color: isActive ? Color(hex: "1E88E5").opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)

                // Time display
                Text(time != nil ? format(time!) : "--:--.-")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(isActive ? Color(hex: "1E88E5") : Color(hex: "757575"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Audio Manager
class AudioPlayerManager: NSObject, ObservableObject {
    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var pitchControl = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    private var timer: Timer?

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var fileName = ""
    @Published var speed: Double = 1.0
    @Published var pitch: Double = 1.0
    @Published var loopA: Double? = nil
    @Published var loopB: Double? = nil
    @Published var loopEnabled: Bool = true
    @Published var repeatEnabled: Bool = false

    override init() {
        super.init()
        setupAudioSession()
        setupEngine()
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch { }
        #endif
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(pitchControl)
        engine.connect(playerNode, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
    }

    func loadFile(url: URL, library: LibraryManager? = nil, saveToLibrary: Bool = true, customName: String? = nil) {
        // Start accessing security-scoped resource FIRST
        let hasAccess = url.startAccessingSecurityScopedResource()

        var localURL: URL
        var localFileName: String

        if saveToLibrary {
            // Copy file to local storage WHILE we have security access
            guard let copiedFileName = LibraryFileManager.shared.copyToLibrary(url: url) else {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
                return
            }
            localFileName = copiedFileName
            localURL = LibraryFileManager.shared.getURL(for: copiedFileName)

            // Stop accessing security-scoped resource AFTER copy
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }

            // Add to library with file name (not full path)
            let trackName = url.lastPathComponent
            if !library!.tracks.contains(where: { $0.name == trackName }) {
                // Get duration from local file
                if let audioFile = try? AVAudioFile(forReading: localURL) {
                    let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
                    library?.addTrackFromLocalFile(name: trackName, duration: duration, localPath: localFileName)
                }
            }
        } else {
            // Loading from library - file is already local
            localURL = url
        }

        // Check if file is readable
        let isReadable = FileManager.default.isReadableFile(atPath: localURL.path)

        if !isReadable {
            // Fix file permissions
            do {
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: localURL.path)
            } catch { }
        }

        // Now load the LOCAL file with AVAudioFile
        do {
            playerNode.stop()
            audioFile = try AVAudioFile(forReading: localURL)
            fileName = customName ?? localURL.lastPathComponent
            duration = Double(audioFile!.length) / audioFile!.fileFormat.sampleRate
            currentTime = 0
            loopA = nil
            loopB = nil
            loopEnabled = true
            scheduleFile()
            startTimer()
            // Auto-start playback after loading
            if !engine.isRunning { try? engine.start() }
            playerNode.play()
            isPlaying = true
        } catch { }
    }

    private func scheduleFile() {
        guard let file = audioFile else { return }
        playerNode.scheduleFile(file, at: nil)
    }

    func togglePlay() {
        if isPlaying {
            playerNode.pause()
            isPlaying = false
        } else if audioFile != nil {
            if currentTime >= duration {
                playerNode.stop()
                currentTime = 0
                scheduleFile()
                if !engine.isRunning { try? engine.start() }
                playerNode.play()
                isPlaying = true
            } else {
                if !engine.isRunning { try? engine.start() }
                playerNode.play()
                isPlaying = true
            }
        }
    }

    func seekTo(_ time: Double) {
        guard let file = audioFile else { return }
        let sampleTime = AVAudioFramePosition(time * file.fileFormat.sampleRate)
        let remainingFrames = AVAudioFrameCount(max(0, file.length - sampleTime))
        playerNode.stop()
        if remainingFrames > 0 {
            playerNode.scheduleSegment(file, startingFrame: sampleTime, frameCount: remainingFrames, at: nil)
            if isPlaying { playerNode.play() }
        }
        currentTime = time
    }

    func seek(_ seconds: Double) {
        seekTo(max(0, min(currentTime + seconds, duration)))
    }

    func applySpeed() {
        pitchControl.rate = Float(speed)
    }

    func applyPitch() {
        pitchControl.pitch = Float(log2(pitch) * 1200)
    }

    func setA() {
        loopA = currentTime
    }

    func setB() {
        if loopA != nil && currentTime > loopA! {
            loopB = currentTime
            loopEnabled = true
        }
    }

    func clearLoop() {
        loopA = nil
        loopB = nil
        loopEnabled = true
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            DispatchQueue.main.async {
                self.currentTime = min(self.currentTime + (0.05 * self.speed), self.duration)

                // Check for A-B loop
                if self.loopEnabled,
                   let a = self.loopA,
                   let b = self.loopB,
                   self.currentTime >= b {
                    self.seekTo(a)
                    return
                }

                // Check for track end
                if self.currentTime >= self.duration {
                    if self.repeatEnabled {
                        // Repeat: replay from beginning
                        self.seekTo(0)
                        self.playerNode.stop()
                        self.scheduleFile()
                        if !self.engine.isRunning { try? self.engine.start() }
                        self.playerNode.play()
                    } else {
                        // No repeat: stop and reset
                        self.playerNode.stop()
                        self.isPlaying = false
                        self.currentTime = 0
                    }
                }
            }
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let dec = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", m, s, dec)
    }
}

#Preview {
    ContentView()
}
