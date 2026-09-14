//
//  WinLibrary.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// Where a win's picture comes from.
///
/// Two cases, because a real install has both: photographs the user took, and
/// the seeded stickers that keep the grid from being empty on a fresh simulator.
/// A single `String` couldn't tell them apart, which is why the old `asset`
/// field was a filename and an asset-catalog name at the same time.
enum WinPhoto: Codable, Hashable {
    /// A sticker in the asset catalog — seed data.
    case bundled(String)
    /// A JPEG in the wins directory, named by the win's id.
    case captured(String)
}

/// One proof photo.
struct Win: Identifiable, Hashable, Codable {
    let id: UUID
    let photo: WinPhoto
    /// The habit's own sticker, carried rather than looked up by name — the
    /// name changes, the icon shouldn't have to follow.
    let icon: String
    let habit: String
    let date: Date

    init(id: UUID = UUID(), photo: WinPhoto, icon: String, habit: String, date: Date) {
        self.id = id
        self.photo = photo
        self.icon = icon
        self.habit = habit
        self.date = date
    }
}

/// The wins on disk: a JSON index beside a directory of JPEGs.
///
/// The photographs are files rather than blobs in the index because they're the
/// only large thing this app stores — a hundred wins is tens of megabytes, and
/// nothing should have to decode all of it to draw one row.
enum WinLibrary {
    private static let indexName = "wins.json"
    private static let directoryName = "Wins"

    private static var root: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }

    private static var photosDirectory: URL? {
        guard let root else { return nil }
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func photoURL(_ filename: String) -> URL? {
        photosDirectory?.appendingPathComponent(filename)
    }

    // MARK: - Index

    static func load() -> [Win] {
        guard let url = root?.appendingPathComponent(indexName),
              let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let wins = (try? decoder.decode([Win].self, from: data)) ?? []
        // Newest first, the order every surface draws them in.
        return wins.sorted { $0.date > $1.date }
    }

    static func save(_ wins: [Win]) {
        guard let url = root?.appendingPathComponent(indexName) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(wins) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Photos

    /// Writes the capture and returns the record to add.
    ///
    /// JPEG at 0.85 rather than PNG: these are camera frames, where PNG buys
    /// nothing but roughly ten times the file size.
    static func add(_ image: UIImage, habit: String, icon: String, date: Date = .now) -> Win? {
        let id = UUID()
        let filename = "\(id.uuidString).jpg"
        guard let url = photoURL(filename),
              let data = image.jpegData(compressionQuality: 0.85),
              (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return Win(id: id, photo: .captured(filename), icon: icon, habit: habit, date: date)
    }

    /// Deletes the file behind a win, if it has one. Seeded stickers have
    /// nothing to delete.
    static func removePhoto(for win: Win) {
        guard case .captured(let filename) = win.photo,
              let url = photoURL(filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// A win's picture, from wherever it lives.
///
/// One view so the tile, the strip and the detail cover can't disagree about
/// how a photo is loaded — they were all writing `Image(win.asset)`, which only
/// ever worked because every win was a sticker.
struct WinPhotoView: View {
    let photo: WinPhoto
    /// Stickers are artwork on a white field and want their margins; a
    /// photograph should fill its frame.
    var bundledPadding: CGFloat = Theme.Spacing.m

    var body: some View {
        switch photo {
        case .bundled(let name):
            Image(name)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(bundledPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LightSheet.bg)
        case .captured(let filename):
            if let url = WinLibrary.photoURL(filename),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // The index outlived the file. Rare, but a missing photo should
                // read as a gap rather than a crash.
                LightSheet.field
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 22))
                            .foregroundStyle(LightSheet.badge)
                    }
            }
        }
    }
}

#if DEBUG
extension WinLibrary {
    /// Seeds the wall on a fresh install so the grid isn't empty while the
    /// capture path is still being built. Debug only.
    static func seedIfEmpty(now: Date = .now) {
        guard load().isEmpty else { return }
        let entries: [(String, String, Int)] = [
            ("FoxHabitRead", "Read", 0),
            ("FoxHabitGym", "Hit the gym", 0),
            ("FoxHabitHealthyMeal", "Eat a healthy meal", 1),
            ("FoxHabitRun", "Go for a run", 1),
            ("FoxHabitStudy", "Study", 2),
            ("FoxHabitMakeBed", "Make your bed", 2),
            ("FoxHabitWalk", "Go for a walk", 3),
            ("FoxHabitMeditate", "Meditate", 3),
            ("FoxHabitCleanRoom", "Clean your room", 4),
            ("FoxHabitJournal", "Write in your journal", 4),
            ("FoxHabitDeepWork", "Deep Work", 5),
            ("FoxHabitTouchGrass", "Touch grass", 6),
        ]
        save(entries.map { asset, habit, daysAgo in
            Win(photo: .bundled(asset), icon: asset, habit: habit,
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now)
        })
    }
}
#endif
