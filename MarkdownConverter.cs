// MarkdownConverter.cs
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

class MarkdownConverter
{
    private bool inCodeBlock = false;
    private string codeLang = "";
    private bool inList = false;
    private string listType = "";
    private bool inBlockquote = false;

    private string EscapeHtml(string s)
    {
        return s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("\"", "&quot;");
    }

    private string ProcessInlineFormatting(string text)
    {
        // Bold
        text = Regex.Replace(text, @"\*\*(.+?)\*\*", "<strong>$1</strong>");
        text = Regex.Replace(text, @"__(.+?)__", "<strong>$1</strong>");
        // Italic
        text = Regex.Replace(text, @"\*(.+?)\*", "<em>$1</em>");
        text = Regex.Replace(text, @"_(.+?)_", "<em>$1</em>");
        // Strikethrough
        text = Regex.Replace(text, @"~~(.+?)~~", "<del>$1</del>");
        // Images
        text = Regex.Replace(text, @"!\[([^\]]*)\]\(([^)]+)\)", "<img src=\"$2\" alt=\"$1\">");
        // Links
        text = Regex.Replace(text, @"\[([^\]]+)\]\(([^)]+)\)", "<a href=\"$2\">$1</a>");
        // Auto-links
        text = Regex.Replace(text, @"(?i)(https?://[^\s<>""']+)", "<a href=\"$1\">$1</a>");
        return text;
    }

    private string ConvertInline(string text)
    {
        var parts = text.Split('`');
        for (int i = 0; i < parts.Length; i++)
        {
            if (i % 2 == 0)
                parts[i] = ProcessInlineFormatting(parts[i]);
            else
                parts[i] = "<code>" + EscapeHtml(parts[i]) + "</code>";
        }
        return string.Join("", parts);
    }

    private string CloseBlocks()
    {
        string result = "";
        if (inBlockquote)
        {
            result += "</blockquote>";
            inBlockquote = false;
        }
        if (inList)
        {
            result += "</" + listType + ">";
            inList = false;
            listType = "";
        }
        return result;
    }

    private string ConvertLine(string line)
    {
        if (string.IsNullOrEmpty(line))
            return CloseBlocks() + "\n";
        string trimmed = line.TrimStart();
        int indent = line.Length - trimmed.Length;

        // Code fence
        if (trimmed.StartsWith("```"))
        {
            if (!inCodeBlock)
            {
                inCodeBlock = true;
                codeLang = trimmed.Substring(3).Trim();
                return string.IsNullOrEmpty(codeLang) ? "<pre><code>\n" : $"<pre><code class=\"language-{codeLang}\">\n";
            }
            else
            {
                inCodeBlock = false;
                return "</code></pre>\n";
            }
        }
        if (inCodeBlock)
            return EscapeHtml(line) + "\n";

        // Headings
        if (trimmed.StartsWith("#"))
        {
            int level = 0;
            while (level < trimmed.Length && trimmed[level] == '#') level++;
            if (level > 6) level = 6;
            string headingText = trimmed.Substring(level).Trim();
            return CloseBlocks() + $"<h{level}>{ConvertInline(headingText)}</h{level}>";
        }

        // Horizontal rule
        if (Regex.IsMatch(trimmed, @"^(---|___|\*\*\*)\s*$"))
            return CloseBlocks() + "<hr>";

        // Blockquotes
        if (trimmed.StartsWith(">"))
        {
            string content = trimmed.Substring(1).TrimStart();
            if (!inBlockquote)
            {
                inBlockquote = true;
                return "<blockquote>" + ConvertLine(content);
            }
            return ConvertLine(content);
        }
        if (inBlockquote)
        {
            inBlockquote = false;
            return "</blockquote>" + ConvertLine(line);
        }

        // Lists
        var listMatch = Regex.Match(trimmed, @"^(\s*)([\-\*\+]|\d+\.)\s+(.*)");
        if (listMatch.Success)
        {
            string marker = listMatch.Groups[2].Value;
            string content = listMatch.Groups[3].Value;
            bool isOrdered = marker.EndsWith(".");
            string listType = isOrdered ? "ol" : "ul";
            if (!inList)
            {
                inList = true;
                this.listType = listType;
                return $"<{listType}>\n<li>{ConvertInline(content)}</li>";
            }
            else
            {
                if (this.listType != listType)
                {
                    string closing = "</" + this.listType + ">";
                    this.listType = listType;
                    return closing + $"<{listType}>\n<li>{ConvertInline(content)}</li>";
                }
                return $"<li>{ConvertInline(content)}</li>";
            }
        }
        if (inList)
        {
            inList = false;
            string closing = "</" + listType + ">";
            listType = "";
            return closing + ConvertLine(line);
        }

        // Table (simplified)
        if (trimmed.Contains("|") && Regex.IsMatch(trimmed, @"^\s*\|?\s*[-\:]+\s*\|"))
            return CloseBlocks() + $"<p>TABLE: {ConvertInline(trimmed)}</p>";

        // Paragraph
        return CloseBlocks() + $"<p>{ConvertInline(trimmed)}</p>";
    }

    public string Convert(string markdown)
    {
        var lines = markdown.Split('\n');
        var sb = new StringBuilder();
        foreach (var line in lines)
            sb.Append(ConvertLine(line));
        sb.Append(CloseBlocks());
        return sb.ToString();
    }

    static void Main()
    {
        var converter = new MarkdownConverter();
        Console.WriteLine("=== Markdown to HTML Converter ===");
        while (true)
        {
            Console.WriteLine("\n1. Convert text input");
            Console.WriteLine("2. Convert from file");
            Console.WriteLine("3. Exit");
            Console.Write("Choose: ");
            string choice = Console.ReadLine()?.Trim() ?? "";
            switch (choice)
            {
                case "1":
                    Console.WriteLine("Enter Markdown (end with empty line):");
                    var lines = new List<string>();
                    while (true)
                    {
                        string line = Console.ReadLine() ?? "";
                        if (line == "") break;
                        lines.Add(line);
                    }
                    string text = string.Join("\n", lines);
                    string html = converter.Convert(text);
                    Console.WriteLine("\nHTML output:\n" + html);
                    break;
                case "2":
                    Console.Write("Enter file path: ");
                    string fname = Console.ReadLine()?.Trim() ?? "";
                    try
                    {
                        string content = File.ReadAllText(fname);
                        html = converter.Convert(content);
                        Console.WriteLine("\nHTML output:\n" + html);
                    }
                    catch
                    {
                        Console.WriteLine("File not found or error.");
                    }
                    break;
                case "3":
                    Console.WriteLine("Goodbye!");
                    return;
                default:
                    Console.WriteLine("Invalid choice.");
                    break;
            }
        }
    }
}
