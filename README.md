# 📝 Markdown to HTML Converter – Multi‑Language Edition

A powerful **Markdown to HTML converter** that transforms plain Markdown text into clean, semantic HTML.  
Supports headings, paragraphs, lists (ordered/unordered/nested), blockquotes, code blocks, inline code, links, images, tables, horizontal rules, and inline HTML escaping.  
Built in **7 programming languages** – perfect for learning, documentation, or web integration.

## ✨ Features
- **Block elements** – headings (`#` to `######`), paragraphs, blockquotes (`>`), code blocks (fenced with triple backticks, with optional language), horizontal rules (`---`, `___`, `***`).
- **Inline formatting** – bold (`**` or `__`), italic (`*` or `_`), strikethrough (`~~`), inline code (`` ` ``).
- **Lists** – ordered (`1.`) and unordered (`-`, `*`, `+`) lists with nesting support (proper indentation).
- **Links and images** – `[text](url)` and `![alt](url)` – with title support.
- **Automatic links** – plain URLs become clickable links.
- **Tables** – simple pipe‑separated tables with header separation (`|---|---|`), alignment (left/right/center).
- **Task lists** – `- [ ]` and `- [x]` become unchecked/checked checkboxes.
- **HTML escaping** – special characters (`<`, `>`, `&`, `"`) are properly escaped.
- **File and interactive modes** – read from file or enter text interactively.

## 🗂 Languages & Files
| Language          | File                         |
|-------------------|------------------------------|
| Python            | `markdown_converter.py`      |
| Go                | `markdown_converter.go`      |
| JavaScript        | `markdown_converter.js`      |
| C#                | `MarkdownConverter.cs`       |
| Java              | `MarkdownConverter.java`     |
| Ruby              | `markdown_converter.rb`      |
| Swift             | `markdown_converter.swift`   |

## 🚀 How to Run
Each file is standalone – run it with the appropriate interpreter/compiler:

| Language | Command |
|----------|---------|
| Python   | `python markdown_converter.py` |
| Go       | `go run markdown_converter.go` |
| JavaScript | `node markdown_converter.js` |
| C#       | `dotnet run` (or `csc MarkdownConverter.cs`) |
| Java     | `javac MarkdownConverter.java && java MarkdownConverter` |
| Ruby     | `ruby markdown_converter.rb` |
| Swift    | `swift markdown_converter.swift` |

## 📊 Example Session
=== Markdown to HTML Converter ===

Convert text input

Convert from file

Exit
Choose: 1

Enter Markdown (end with empty line):

Hello, world!
This is a bold and italic text.

Item 1

Item 2
Link

HTML output:

<h1>Hello, world!</h1> <p>This is a <strong>bold</strong> and <em>italic</em> text.</p> <ul> <li>Item 1</li> <li>Item 2</li> </ul> <p><a href="https://example.com">Link</a></p> ```
🔧 Technical Details
Parser – state‑based line‑by‑line processing with support for block and inline rules.

No external dependencies – pure language standard libraries.

Unicode‑aware – works with any characters (UTF‑8).

Extensible – easy to add new syntax rules.

🤝 Contributing
Add support for more Markdown extensions (footnotes, definition lists, math) – PRs welcome!

📜 License
MIT – use freely.
