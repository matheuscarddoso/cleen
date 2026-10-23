#!/usr/bin/env swift
// Compares the keys the compiler extracted (.stringsdata files) with a .strings table.
//   swift scripts/strings-check.swift <stringsdata dir> <Localizable.strings> [--json <out.json>]
import Foundation

let arguments = CommandLine.arguments
let directory = URL(filePath: arguments[1])
let table = URL(filePath: arguments[2])
let writesJSON = arguments.count > 3 && arguments[3] == "--json"

var used: [String: String] = [:]
for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
where file.pathExtension == "stringsdata" {
    let data = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any] ?? [:]
    let source = (data["source"] as? String).map { URL(filePath: $0).lastPathComponent } ?? file.lastPathComponent
    for case let entries as [[String: Any]] in (data["tables"] as? [String: Any] ?? [:]).values {
        for entry in entries {
            if let key = entry["key"] as? String, !key.trimmingCharacters(in: .whitespaces).isEmpty { used[key] = used[key] ?? source }
        }
    }
}

let translated = (try? PropertyListSerialization.propertyList(from: Data(contentsOf: table), format: nil)) as? [String: String] ?? [:]
let missing = used.keys.filter { translated[$0] == nil }.sorted()
let unused = translated.keys.filter { used[$0] == nil }.sorted()

print("\(used.count) strings in use, \(translated.count) translated, \(missing.count) missing, \(unused.count) unused")
for key in missing { print("missing  \(used[key]!)  \(key)") }
for key in unused { print("unused   \(key)") }

if writesJSON, arguments.count > 4 {
    let object = Dictionary(uniqueKeysWithValues: missing.map { ($0, "") })
    let json = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: URL(filePath: arguments[4]))
    print("wrote \(arguments[4])")
}
