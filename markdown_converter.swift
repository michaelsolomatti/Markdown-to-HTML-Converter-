// markdown_converter.swift
import Foundation

class MarkdownConverter {
    var inCodeBlock = false
    var codeLang = ""
    var inList = false
    var listType = ""
    var inBlockquote = false

    func escapeHtml(_ s: String) -> String {
        return s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
    }

    func processInlineFormatting(_ text: String) -> String {
        var result = text
        // Bold
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: "__(.+?)__", with: "<strong>$1</strong>", options: .regularExpression)
        // Italic
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: "_(.+?)_", with: "<em>$1</em>", options: .regularExpression)
        // Strikethrough
        result = result.replacingOccurrences(of: "~~(.+?)~~", with: "<del>$1</del>", options: .regularExpression)
        // Images
        result = result.replacingOccurrences(of: "!\\[([^\\]]*)\\]\\(([^)]+)\\)", with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)
        // Links
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        // Auto-links
        result = result.replacingOccurrences(of: "(?<![\"'])(https?://[^\\s<>\"']+)", with: "<a href=\"$1\">$1</a>", options: .regularExpression)
        return result
    }

    func convertInline(_ text: String) -> String {
        let parts = text.split(separator: "`", maxSplits: .max, omittingEmptySubsequences: false)
        var result = ""
        for (i, part) in parts.enumerated() {
            if i % 2 == 0 {
                result += processInlineFormatting(String(part))
            } else {
                result += "<code>" + escapeHtml(String(part)) + "</code>"
            }
        }
        return result
    }

    func closeBlocks() -> String {
        var out = ""
        if inBlockquote {
            out += "</blockquote>"
            inBlockquote = false
        }
        if inList {
            out += "</\(listType)>"
            inList = false
            listType = ""
        }
        return out
    }

    func convertLine(_ line: String) -> String {
        if line.isEmpty {
            return closeBlocks() + "\n"
        }
        let trimmed = String(line.drop(while: { $0.isWhitespace }))
        // let indent = line.count - trimmed.count

        // Code fence
        if trimmed.hasPrefix("```") {
            if !inCodeBlock {
                inCodeBlock = true
                codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                return codeLang.isEmpty ? "<pre><code>\n" : "<pre><code class=\"language-\(codeLang)\">\n"
            } else {
                inCodeBlock = false
                return "</code></pre>\n"
            }
        }
        if inCodeBlock {
            return escapeHtml(line) + "\n"
        }

        // Headings
        if trimmed.hasPrefix("#") {
            var level = 0
            while level < trimmed.count && trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == "#" {
                level += 1
            }
            if level > 6 { level = 6 }
            let headingText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            return closeBlocks() + "<h\(level)>\(convertInline(headingText))</h\(level)>"
        }

        // Horizontal rule
        if let _ = trimmed.range(of: "^(---|___|\\*\\*\\*)\\s*$", options: .regularExpression) {
            return closeBlocks() + "<hr>"
        }

        // Blockquotes
        if trimmed.hasPrefix(">") {
            let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            if !inBlockquote {
                inBlockquote = true
                return "<blockquote>" + convertLine(content)
            }
            return convertLine(content)
        }
        if inBlockquote {
            inBlockquote = false
            return "</blockquote>" + convertLine(line)
        }

        // Lists
        let listPattern = try! NSRegularExpression(pattern: "^(\\s*)([\\-\\*\\+]|\\d+\\.)\\s+(.*)")
        if let match = listPattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            let marker = String(trimmed[Range(match.range(at: 2), in: trimmed)!])
            let content = String(trimmed[Range(match.range(at: 3), in: trimmed)!])
            let isOrdered = marker.hasSuffix(".")
            let listType = isOrdered ? "ol" : "ul"
            if !inList {
                inList = true
                self.listType = listType
                return "<\(listType)>\n<li>\(convertInline(content))</li>"
            } else {
                if self.listType != listType {
                    let closing = "</\(self.listType)>"
                    self.listType = listType
                    return closing + "<\(listType)>\n<li>\(convertInline(content))</li>"
                }
                return "<li>\(convertInline(content))</li>"
            }
        }
        if inList {
            inList = false
            let closing = "</\(listType)>"
            listType = ""
            return closing + convertLine(line)
        }

        // Table (simplified)
        if trimmed.contains("|") && trimmed.range(of: "^\\s*\\|?\\s*[-:]+\\s*\\|", options: .regularExpression) != nil {
            return closeBlocks() + "<p>TABLE: \(convertInline(trimmed))</p>"
        }

        // Paragraph
        return closeBlocks() + "<p>\(convertInline(trimmed))</p>"
    }

    func convert(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var result = ""
        for line in lines {
            result += convertLine(line)
        }
        result += closeBlocks()
        return result
    }
}

func main() {
    let converter = MarkdownConverter()
    print("=== Markdown to HTML Converter ===")
    while true {
        print("\n1. Convert text input")
        print("2. Convert from file")
        print("3. Exit")
        print("Choose: ", terminator: "")
        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
        switch choice {
        case "1":
            print("Enter Markdown (end with empty line):")
            var lines: [String] = []
            while true {
                guard let line = readLine() else { break }
                if line.isEmpty { break }
                lines.append(line)
            }
            let text = lines.joined(separator: "\n")
            let html = converter.convert(text)
            print("\nHTML output:\n\(html)")
        case "2":
            print("Enter file path: ", terminator: "")
            guard let fname = readLine()?.trimmingCharacters(in: .whitespaces) else { break }
            do {
                let content = try String(contentsOfFile: fname, encoding: .utf8)
                let html = converter.convert(content)
                print("\nHTML output:\n\(html)")
            } catch {
                print("File not found or error: \(error.localizedDescription)")
            }
        case "3":
            print("Goodbye!")
            return
        default:
            print("Invalid choice.")
        }
    }
}

main()
