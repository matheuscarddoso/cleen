import Foundation
import ObjectiveC

/// The emoji list, read from what macOS already ships instead of a bundled database.
///
/// The system picker's data lives in two private frameworks: EmojiFoundation knows the
/// categories in Apple's order and each emoji's localized name, and CoreEmoji's resources
/// hold the per-language search keywords. They're reached through the Objective-C runtime,
/// checking every class and selector first, so an OS update that moves them degrades to a
/// plain Unicode list (with Portuguese names when CoreEmoji's name table is still there)
/// instead of crashing. Slow-ish (tens of milliseconds): call it once, off the main thread.
public enum EmojiLibrary {
    /// `locale` picks the names and keywords ("pt_BR", "en"); by default, the language
    /// Cleen is running in.
    public static func load(locale: String = currentLocale) -> [EmojiSection] {
        // The frameworks hand back autoreleased objects; a background queue has no pool
        // of its own to drain them.
        autoreleasepool {
            if let sections = loadFromSystemPicker(locale: locale), !sections.isEmpty {
                return sections
            }
            return [EmojiSection(category: .all, items: unicodeFallback(locale: locale))]
        }
    }

    /// The app's language as CoreEmoji names its folders: "pt-BR" → "pt_BR".
    public static var currentLocale: String {
        (Bundle.main.preferredLocalizations.first ?? "pt-BR").replacingOccurrences(of: "-", with: "_")
    }

    // MARK: System picker

    private static let coreEmojiResources = "/System/Library/PrivateFrameworks/CoreEmoji.framework/Versions/A/Resources"

    /// EmojiFoundation's category lists (class methods returning the emoji in Apple's
    /// order), mapped to ours. `emojiTokensForLocaleData:` would be the obvious door,
    /// but on macOS 26 it hands back an empty list.
    private static let categoryLists: [(selector: String, category: EmojiCategory)] = [
        ("PeopleEmoji", .people),
        ("NatureEmoji", .nature),
        ("FoodAndDrinkEmoji", .food),
        ("ActivityEmoji", .activity),
        ("TravelAndPlacesEmoji", .travel),
        ("ObjectsEmoji", .objects),
        ("SymbolsEmoji", .symbols),
        ("FlagsEmoji", .flags),
    ]

    private static func loadFromSystemPicker(locale: String) -> [EmojiSection]? {
        guard dlopen("/System/Library/PrivateFrameworks/EmojiFoundation.framework/EmojiFoundation", RTLD_LAZY) != nil,
              let categoryClass = NSClassFromString("EMFEmojiCategory"),
              let localeDataClass = NSClassFromString("EMFEmojiLocaleData"),
              let tokenClass = NSClassFromString("EMFEmojiToken")
        else { return nil }

        let makeLocaleData = NSSelectorFromString("emojiLocaleDataWithLocaleIdentifier:")
        let makeToken = NSSelectorFromString("emojiTokenWithString:localeData:")
        let nameForType = NSSelectorFromString("nameForType:")
        let emojiIndex = NSSelectorFromString("_emojiIndex")
        guard class_getClassMethod(localeDataClass, makeLocaleData) != nil,
              let localeData = (localeDataClass as AnyObject).perform(makeLocaleData, with: locale)?.takeUnretainedValue()
        else { return nil }
        let canMakeTokens = class_getClassMethod(tokenClass, makeToken) != nil

        // nameForType: takes an integer; 1 is the localized short name, 0 the Unicode name.
        typealias NameIMP = @convention(c) (AnyObject, Selector, Int) -> Unmanaged<AnyObject>?
        typealias IndexIMP = @convention(c) (AnyObject, Selector) -> Int
        let nameIMP = class_getMethodImplementation(tokenClass, nameForType)
            .flatMap { class_getInstanceMethod(tokenClass, nameForType) != nil ? unsafeBitCast($0, to: NameIMP.self) : nil }
        let indexIMP = class_getMethodImplementation(tokenClass, emojiIndex)
            .flatMap { class_getInstanceMethod(tokenClass, emojiIndex) != nil ? unsafeBitCast($0, to: IndexIMP.self) : nil }
        let keywords = indexIMP == nil ? [:] : keywordIndex(locale: locale)
        let appleNames = NSDictionary(contentsOfFile: "\(coreEmojiResources)/\(locale).lproj/AppleName.strings") as? [String: String] ?? [:]

        var sections: [EmojiSection] = []
        for (selectorName, category) in categoryLists {
            let selector = NSSelectorFromString(selectorName)
            guard class_getClassMethod(categoryClass, selector) != nil,
                  let list = (categoryClass as AnyObject).perform(selector)?.takeUnretainedValue() as? [String]
            else { continue }
            var items: [EmojiItem] = []
            items.reserveCapacity(list.count)
            for emoji in list where !emoji.isEmpty {
                let token = canMakeTokens ? (tokenClass as AnyObject).perform(makeToken, with: emoji, with: localeData)?.takeUnretainedValue() : nil
                let localized = token.flatMap { nameIMP?($0, nameForType, 1)?.takeUnretainedValue() as? String }
                let unicode = token.flatMap { nameIMP?($0, nameForType, 0)?.takeUnretainedValue() as? String }
                var terms = token.flatMap { token in indexIMP.flatMap { keywords[$0(token, emojiIndex)] } } ?? []
                // The English Unicode name searches too ("heart", "smile").
                if let unicode { terms.append(unicode) }
                let name = capitalized(localized ?? appleNames[emoji] ?? unicode?.lowercased() ?? emoji)
                items.append(EmojiItem(emoji: emoji, name: name, keywords: terms))
            }
            if !items.isEmpty { sections.append(EmojiSection(category: category, items: items)) }
        }
        return sections
    }

    /// CoreEmoji's search index: emoji index → the words that find it.
    private static func keywordIndex(locale: String) -> [Int: [String]] {
        let path = "\(coreEmojiResources)/\(locale).lproj/document_index.plist"
        guard let documents = NSDictionary(contentsOfFile: path) as? [String: [String: Any]] else { return [:] }
        var index: [Int: [String]] = [:]
        index.reserveCapacity(documents.count)
        for (key, terms) in documents {
            if let id = Int(key) { index[id] = Array(terms.keys) }
        }
        return index
    }

    // MARK: Fallback

    /// Every code point Unicode presents as emoji by default, in code point order.
    static func unicodeFallback(locale: String) -> [EmojiItem] {
        let names = NSDictionary(contentsOfFile: "\(coreEmojiResources)/\(locale).lproj/AppleName.strings") as? [String: String] ?? [:]
        let ranges: [ClosedRange<UInt32>] = [0x231A...0x2B55, 0x1F004...0x1FAFF]
        var items: [EmojiItem] = []
        for range in ranges {
            for value in range {
                guard let scalar = Unicode.Scalar(value), scalar.properties.isEmojiPresentation,
                      !(0x1F1E6...0x1F1FF).contains(value), !(0x1F3FB...0x1F3FF).contains(value)
                else { continue }
                let emoji = String(scalar)
                let unicode = scalar.properties.name?.lowercased()
                let name = names[emoji] ?? names[emoji + "\u{FE0F}"] ?? unicode ?? emoji
                items.append(EmojiItem(emoji: emoji, name: capitalized(name), keywords: unicode.map { [$0] } ?? []))
            }
        }
        return items
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
