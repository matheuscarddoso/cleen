import Foundation

/// Placeholder text in the classic Latin, starting with "Lorem ipsum dolor sit amet".
public enum LoremIpsum {
    private static let opening = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    private static let vocabulary = """
    a ac accumsan ad adipiscing aenean aliquam aliquet amet ante aptent arcu at auctor augue bibendum blandit \
    commodo condimentum congue consectetur consequat conubia convallis cras cubilia curabitur curae cursus dapibus \
    diam dictum dictumst dignissim dis dolor donec dui duis efficitur egestas eget eleifend elementum elit enim erat \
    eros est et etiam eu euismod ex facilisi faucibus felis fermentum feugiat finibus fringilla fusce gravida \
    habitant hac hendrerit iaculis id imperdiet in inceptos integer interdum ipsum justo lacinia lacus laoreet \
    lectus leo libero ligula litora lobortis lorem luctus maecenas magna magnis malesuada massa mattis mauris \
    maximus metus mi molestie mollis montes morbi mus nam nascetur natoque nec neque netus nibh nisi nisl non nostra \
    nulla nullam nunc odio orci ornare parturient pellentesque penatibus per pharetra phasellus placerat platea \
    porta porttitor posuere potenti praesent pretium primis proin pulvinar purus quam quis quisque rhoncus ridiculus \
    risus rutrum sagittis sapien scelerisque sed sem semper senectus sit sociosqu sodales sollicitudin suscipit \
    suspendisse taciti tellus tempor tempus tincidunt torquent tortor tristique turpis ullamcorper ultrices \
    ultricies urna ut varius vehicula vel velit venenatis vestibulum vitae vivamus viverra volutpat vulputate
    """.split(separator: " ").map(String.init)

    public static func words(_ count: Int, using generator: inout some RandomNumberGenerator) -> String {
        let opening = Self.opening.dropLast().replacingOccurrences(of: ",", with: "").split(separator: " ").map(String.init)
        var words = Array(opening.prefix(count))
        while words.count < count { words.append(vocabulary.randomElement(using: &generator)!) }
        return words.joined(separator: " ")
    }

    public static func sentences(_ count: Int, using generator: inout some RandomNumberGenerator) -> String {
        guard count > 0 else { return "" }
        var sentences = [opening]
        while sentences.count < count { sentences.append(sentence(using: &generator)) }
        return sentences.joined(separator: " ")
    }

    public static func paragraphs(_ count: Int, using generator: inout some RandomNumberGenerator) -> String {
        guard count > 0 else { return "" }
        var paragraphs: [String] = []
        for index in 0..<count {
            let length = Int.random(in: 4...7, using: &generator)
            var sentences = index == 0 ? [opening] : []
            while sentences.count < length { sentences.append(sentence(using: &generator)) }
            paragraphs.append(sentences.joined(separator: " "))
        }
        return paragraphs.joined(separator: "\n\n")
    }

    public static func words(_ count: Int) -> String { var g = SystemRandomNumberGenerator(); return words(count, using: &g) }
    public static func sentences(_ count: Int) -> String { var g = SystemRandomNumberGenerator(); return sentences(count, using: &g) }
    public static func paragraphs(_ count: Int) -> String { var g = SystemRandomNumberGenerator(); return paragraphs(count, using: &g) }

    /// 6–14 words, a comma now and then, capitalized, with a period.
    private static func sentence(using generator: inout some RandomNumberGenerator) -> String {
        let length = Int.random(in: 6...14, using: &generator)
        var words = (0..<length).map { _ in vocabulary.randomElement(using: &generator)! }
        if length > 8 { words[Int.random(in: 3...(length - 4), using: &generator)] += "," }
        words[0] = words[0].prefix(1).uppercased() + words[0].dropFirst()
        return words.joined(separator: " ") + "."
    }
}
