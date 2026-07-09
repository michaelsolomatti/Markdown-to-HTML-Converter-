// MarkdownConverter.java
import java.io.*;
import java.util.*;
import java.util.regex.*;

public class MarkdownConverter {
    private boolean inCodeBlock = false;
    private String codeLang = "";
    private boolean inList = false;
    private String listType = "";
    private boolean inBlockquote = false;

    private String escapeHtml(String s) {
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }

    private String processInlineFormatting(String text) {
        text = text.replaceAll("\\*\\*(.+?)\\*\\*", "<strong>$1</strong>");
        text = text.replaceAll("__(.+?)__", "<strong>$1</strong>");
        text = text.replaceAll("\\*(.+?)\\*", "<em>$1</em>");
        text = text.replaceAll("_(.+?)_", "<em>$1</em>");
        text = text.replaceAll("~~(.+?)~~", "<del>$1</del>");
        text = text.replaceAll("!\\[([^\\]]*)\\]\\(([^)]+)\\)", "<img src=\"$2\" alt=\"$1\">");
        text = text.replaceAll("\\[([^\\]]+)\\]\\(([^)]+)\\)", "<a href=\"$2\">$1</a>");
        text = text.replaceAll("(?i)(https?://[^\\s<>\"']+)", "<a href=\"$1\">$1</a>");
        return text;
    }

    private String convertInline(String text) {
        String[] parts = text.split("`");
        for (int i = 0; i < parts.length; i++) {
            if (i % 2 == 0) {
                parts[i] = processInlineFormatting(parts[i]);
            } else {
                parts[i] = "<code>" + escapeHtml(parts[i]) + "</code>";
            }
        }
        return String.join("", parts);
    }

    private String closeBlocks() {
        StringBuilder sb = new StringBuilder();
        if (inBlockquote) {
            sb.append("</blockquote>");
            inBlockquote = false;
        }
        if (inList) {
            sb.append("</").append(listType).append(">");
            inList = false;
            listType = "";
        }
        return sb.toString();
    }

    private String convertLine(String line) {
        if (line == null || line.isEmpty()) {
            return closeBlocks() + "\n";
        }
        String trimmed = line.replaceFirst("^\\s+", "");
        int indent = line.length() - trimmed.length();

        // Code fence
        if (trimmed.startsWith("```")) {
            if (!inCodeBlock) {
                inCodeBlock = true;
                codeLang = trimmed.substring(3).trim();
                return codeLang.isEmpty() ? "<pre><code>\n" : "<pre><code class=\"language-" + codeLang + "\">\n";
            } else {
                inCodeBlock = false;
                return "</code></pre>\n";
            }
        }
        if (inCodeBlock) {
            return escapeHtml(line) + "\n";
        }

        // Headings
        if (trimmed.startsWith("#")) {
            int level = 0;
            while (level < trimmed.length() && trimmed.charAt(level) == '#') level++;
            if (level > 6) level = 6;
            String headingText = trimmed.substring(level).trim();
            return closeBlocks() + "<h" + level + ">" + convertInline(headingText) + "</h" + level + ">";
        }

        // Horizontal rule
        if (trimmed.matches("^(---|___|\\*\\*\\*)\\s*$")) {
            return closeBlocks() + "<hr>";
        }

        // Blockquotes
        if (trimmed.startsWith(">")) {
            String content = trimmed.substring(1).trim();
            if (!inBlockquote) {
                inBlockquote = true;
                return "<blockquote>" + convertLine(content);
            }
            return convertLine(content);
        }
        if (inBlockquote) {
            inBlockquote = false;
            return "</blockquote>" + convertLine(line);
        }

        // Lists
        Matcher listMatch = Pattern.compile("^(\\s*)([\\-\\*\\+]|\\d+\\.)\\s+(.*)").matcher(trimmed);
        if (listMatch.find()) {
            String marker = listMatch.group(2);
            String content = listMatch.group(3);
            boolean isOrdered = marker.endsWith(".");
            String listType = isOrdered ? "ol" : "ul";
            if (!inList) {
                inList = true;
                this.listType = listType;
                return "<" + listType + ">\n<li>" + convertInline(content) + "</li>";
            } else {
                if (!this.listType.equals(listType)) {
                    String closing = "</" + this.listType + ">";
                    this.listType = listType;
                    return closing + "<" + listType + ">\n<li>" + convertInline(content) + "</li>";
                }
                return "<li>" + convertInline(content) + "</li>";
            }
        }
        if (inList) {
            inList = false;
            String closing = "</" + listType + ">";
            listType = "";
            return closing + convertLine(line);
        }

        // Table (simplified)
        if (trimmed.contains("|") && trimmed.matches("^\\s*\\|?\\s*[-:]+\\s*\\|")) {
            return closeBlocks() + "<p>TABLE: " + convertInline(trimmed) + "</p>";
        }

        // Paragraph
        return closeBlocks() + "<p>" + convertInline(trimmed) + "</p>";
    }

    public String convert(String markdown) {
        String[] lines = markdown.split("\n");
        StringBuilder sb = new StringBuilder();
        for (String line : lines) {
            sb.append(convertLine(line));
        }
        sb.append(closeBlocks());
        return sb.toString();
    }

    public static void main(String[] args) throws IOException {
        MarkdownConverter converter = new MarkdownConverter();
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        System.out.println("=== Markdown to HTML Converter ===");
        while (true) {
            System.out.println("\n1. Convert text input");
            System.out.println("2. Convert from file");
            System.out.println("3. Exit");
            System.out.print("Choose: ");
            String choice = reader.readLine().trim();
            switch (choice) {
                case "1":
                    System.out.println("Enter Markdown (end with empty line):");
                    List<String> lines = new ArrayList<>();
                    while (true) {
                        String line = reader.readLine();
                        if (line.isEmpty()) break;
                        lines.add(line);
                    }
                    String text = String.join("\n", lines);
                    String html = converter.convert(text);
                    System.out.println("\nHTML output:\n" + html);
                    break;
                case "2":
                    System.out.print("Enter file path: ");
                    String fname = reader.readLine().trim();
                    try (BufferedReader fr = new BufferedReader(new FileReader(fname))) {
                        StringBuilder sb = new StringBuilder();
                        String line;
                        while ((line = fr.readLine()) != null) sb.append(line).append("\n");
                        html = converter.convert(sb.toString());
                        System.out.println("\nHTML output:\n" + html);
                    } catch (FileNotFoundException e) {
                        System.out.println("File not found.");
                    }
                    break;
                case "3":
                    System.out.println("Goodbye!");
                    return;
                default:
                    System.out.println("Invalid choice.");
            }
        }
    }
}
