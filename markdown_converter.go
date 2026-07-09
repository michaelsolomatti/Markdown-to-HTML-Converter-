// markdown_converter.go
package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"
)

type Converter struct {
	inCodeBlock   bool
	codeLang      string
	inList        bool
	listType      string // "ul" or "ol"
	inBlockquote  bool
}

func NewConverter() *Converter {
	return &Converter{}
}

func (c *Converter) escapeHTML(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, `"`, "&quot;")
	return s
}

func (c *Converter) convertInline(text string) string {
	// Split by backticks for code spans
	parts := strings.Split(text, "`")
	for i := range parts {
		if i%2 == 0 {
			// Not a code span
			parts[i] = c.processInlineFormatting(parts[i])
		} else {
			// Code span
			parts[i] = "<code>" + c.escapeHTML(parts[i]) + "</code>"
		}
	}
	return strings.Join(parts, "")
}

func (c *Converter) processInlineFormatting(text string) string {
	// Bold
	re := regexp.MustCompile(`\*\*(.+?)\*\*`)
	text = re.ReplaceAllString(text, "<strong>$1</strong>")
	re = regexp.MustCompile(`__(.+?)__`)
	text = re.ReplaceAllString(text, "<strong>$1</strong>")
	// Italic
	re = regexp.MustCompile(`\*(.+?)\*`)
	text = re.ReplaceAllString(text, "<em>$1</em>")
	re = regexp.MustCompile(`_(.+?)_`)
	text = re.ReplaceAllString(text, "<em>$1</em>")
	// Strikethrough
	re = regexp.MustCompile(`~~(.+?)~~`)
	text = re.ReplaceAllString(text, "<del>$1</del>")
	// Images
	re = regexp.MustCompile(`!\[([^\]]*)\]\(([^)]+)\)`)
	text = re.ReplaceAllString(text, `<img src="$2" alt="$1">`)
	// Links
	re = regexp.MustCompile(`\[([^\]]+)\]\(([^)]+)\)`)
	text = re.ReplaceAllString(text, `<a href="$2">$1</a>`)
	// Auto-links
	re = regexp.MustCompile(`(?i)(https?://[^\s<>"']+)`)
	text = re.ReplaceAllString(text, `<a href="$1">$1</a>`)
	return text
}

func (c *Converter) closeBlocks() string {
	var out string
	if c.inBlockquote {
		out += "</blockquote>"
		c.inBlockquote = false
	}
	if c.inList {
		out += "</" + c.listType + ">"
		c.inList = false
		c.listType = ""
	}
	return out
}

func (c *Converter) convertLine(line string) string {
	if line == "" {
		return c.closeBlocks() + "\n"
	}
	trimmed := strings.TrimLeft(line, " \t")
	indent := len(line) - len(trimmed)

	// Code block fence
	if strings.HasPrefix(trimmed, "```") {
		if !c.inCodeBlock {
			c.inCodeBlock = true
			c.codeLang = strings.TrimSpace(trimmed[3:])
			if c.codeLang != "" {
				return `<pre><code class="language-` + c.codeLang + `">` + "\n"
			}
			return "<pre><code>\n"
		} else {
			c.inCodeBlock = false
			return "</code></pre>\n"
		}
	}
	if c.inCodeBlock {
		return c.escapeHTML(line) + "\n"
	}

	// Headings
	if strings.HasPrefix(trimmed, "#") {
		level := 0
		for level < len(trimmed) && trimmed[level] == '#' {
			level++
		}
		if level > 6 {
			level = 6
		}
		headingText := strings.TrimSpace(trimmed[level:])
		return c.closeBlocks() + fmt.Sprintf("<h%d>%s</h%d>", level, c.convertInline(headingText), level)
	}

	// Horizontal rule
	if matched, _ := regexp.MatchString(`^(---|___|\*\*\*)\s*$`, trimmed); matched {
		return c.closeBlocks() + "<hr>"
	}

	// Blockquotes
	if strings.HasPrefix(trimmed, ">") {
		content := strings.TrimSpace(strings.TrimPrefix(trimmed, ">"))
		if !c.inBlockquote {
			c.inBlockquote = true
			return "<blockquote>" + c.convertLine(content)
		}
		return c.convertLine(content)
	}
	if c.inBlockquote {
		c.inBlockquote = false
		return "</blockquote>" + c.convertLine(line)
	}

	// Lists
	listMatch := regexp.MustCompile(`^(\s*)([\-\*\+]|\d+\.)\s+(.*)`).FindStringSubmatch(trimmed)
	if listMatch != nil {
		marker := listMatch[2]
		content := listMatch[3]
		isOrdered := strings.HasSuffix(marker, ".")
		listType := "ol"
		if !isOrdered {
			listType = "ul"
		}
		if !c.inList {
			c.inList = true
			c.listType = listType
			return "<" + listType + ">\n<li>" + c.convertInline(content) + "</li>"
		} else {
			if c.listType != listType {
				closing := "</" + c.listType + ">"
				c.listType = listType
				return closing + "<" + listType + ">\n<li>" + c.convertInline(content) + "</li>"
			}
			return "<li>" + c.convertInline(content) + "</li>"
		}
	}
	if c.inList {
		c.inList = false
		closing := "</" + c.listType + ">"
		c.listType = ""
		return closing + c.convertLine(line)
	}

	// Table (simplified)
	if strings.Contains(trimmed, "|") && regexp.MustCompile(`^\s*\|?\s*[-\:]+\s*\|`).MatchString(trimmed) {
		// For simplicity, just treat as paragraph
		return c.closeBlocks() + "<p>TABLE: " + c.convertInline(trimmed) + "</p>"
	}

	// Paragraph
	return c.closeBlocks() + "<p>" + c.convertInline(trimmed) + "</p>"
}

func (c *Converter) Convert(markdown string) string {
	lines := strings.Split(markdown, "\n")
	var out strings.Builder
	for _, line := range lines {
		out.WriteString(c.convertLine(line))
	}
	out.WriteString(c.closeBlocks())
	return out.String()
}

func main() {
	converter := NewConverter()
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("=== Markdown to HTML Converter ===")
	for {
		fmt.Println("\n1. Convert text input")
		fmt.Println("2. Convert from file")
		fmt.Println("3. Exit")
		fmt.Print("Choose: ")
		scanner.Scan()
		choice := strings.TrimSpace(scanner.Text())
		switch choice {
		case "1":
			fmt.Println("Enter Markdown (end with empty line):")
			var lines []string
			for {
				scanner.Scan()
				line := scanner.Text()
				if line == "" {
					break
				}
				lines = append(lines, line)
			}
			text := strings.Join(lines, "\n")
			html := converter.Convert(text)
			fmt.Println("\nHTML output:\n", html)
		case "2":
			fmt.Print("Enter file path: ")
			scanner.Scan()
			fname := strings.TrimSpace(scanner.Text())
			data, err := os.ReadFile(fname)
			if err != nil {
				fmt.Println("File not found.")
				continue
			}
			html := converter.Convert(string(data))
			fmt.Println("\nHTML output:\n", html)
		case "3":
			fmt.Println("Goodbye!")
			return
		default:
			fmt.Println("Invalid choice.")
		}
	}
}
