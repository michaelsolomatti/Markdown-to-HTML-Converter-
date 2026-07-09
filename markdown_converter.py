
---

# 💻 Code Implementations

## 1. Python (`markdown_converter.py`)

```python
# markdown_converter.py
import re
import sys

class MarkdownConverter:
    def __init__(self):
        self.in_code_block = False
        self.code_lang = ''
        self.in_list = False
        self.list_type = None  # 'ul' or 'ol'
        self.list_level = 0
        self.in_blockquote = False
        self.blockquote_level = 0

    def escape_html(self, text):
        return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')

    def convert_inline(self, text):
        # Escape HTML special chars first (but we need to avoid escaping inside code spans)
        # We'll handle code spans separately
        # Split by backticks to protect code spans
        parts = text.split('`')
        for i in range(len(parts)):
            if i % 2 == 0:
                # Not a code span, process inline formatting
                parts[i] = self._process_inline(parts[i])
            else:
                # Code span: wrap in <code> and escape
                parts[i] = '<code>' + self.escape_html(parts[i]) + '</code>'
        return ''.join(parts)

    def _process_inline(self, text):
        # Bold: ** or __
        text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
        text = re.sub(r'__(.+?)__', r'<strong>\1</strong>', text)
        # Italic: * or _
        text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
        text = re.sub(r'_(.+?)_', r'<em>\1</em>', text)
        # Strikethrough: ~~
        text = re.sub(r'~~(.+?)~~', r'<del>\1</del>', text)
        # Inline code (already handled)
        # Images: ![alt](url)
        text = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', r'<img src="\2" alt="\1">', text)
        # Links: [text](url)
        text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
        # Auto-links: http://, https://
        text = re.sub(r'(?<!["\'])(https?://[^\s<>"]+)', r'<a href="\1">\1</a>', text)
        return text

    def convert_line(self, line):
        # Strip trailing newline but keep indent for list detection
        stripped = line.rstrip('\n')
        indent_len = len(stripped) - len(stripped.lstrip())
        line_content = stripped.lstrip()
        if not line_content:
            return self._close_blocks() + '\n'

        # Check for code block fence
        if line_content.startswith('```'):
            if not self.in_code_block:
                self.in_code_block = True
                self.code_lang = line_content[3:].strip()
                return '<pre><code class="language-' + self.code_lang + '">' if self.code_lang else '<pre><code>'
            else:
                self.in_code_block = False
                return '</code></pre>'

        if self.in_code_block:
            return self.escape_html(line.rstrip('\n')) + '\n'

        # Headings
        if line_content.startswith('#'):
            level = len(line_content) - len(line_content.lstrip('#'))
            level = min(level, 6)
            heading_text = line_content.lstrip('#').strip()
            return self._close_blocks() + f'<h{level}>{self.convert_inline(heading_text)}</h{level}>'

        # Horizontal rule
        if re.match(r'^(---|___|\*\*\*)\s*$', line_content):
            return self._close_blocks() + '<hr>'

        # Blockquotes
        if line_content.startswith('>'):
            quote_content = line_content.lstrip('>').lstrip()
            if not self.in_blockquote:
                self.in_blockquote = True
                self.blockquote_level = 1
                return '<blockquote>' + self.convert_line(quote_content)
            else:
                # Nested blockquote? Simple handling: just continue
                return self.convert_line(quote_content)

        if self.in_blockquote:
            self.in_blockquote = False
            return '</blockquote>' + self.convert_line(line)

        # Lists
        list_match = re.match(r'^(\s*)([\-\*\+]|\d+\.)\s+(.*)', line_content)
        if list_match:
            indent = list_match.group(1)
            marker = list_match.group(2)
            content = list_match.group(3)
            # Determine if ordered
            is_ordered = marker[-1] == '.'
            list_type = 'ol' if is_ordered else 'ul'
            # Handle nesting: we use indent length to decide level
            # For simplicity, we treat each indent of 2 or 4 spaces as a level
            # We'll just use a simple approach: if list is already active, we keep it
            # Otherwise start new list
            if not self.in_list:
                self.in_list = True
                self.list_type = list_type
                self.list_level = 1
                return f'<{list_type}>\n<li>{self.convert_inline(content)}</li>'
            else:
                # If list type changed, close previous and start new
                if self.list_type != list_type:
                    closing = f'</{self.list_type}>'
                    self.list_type = list_type
                    return closing + f'<{list_type}>\n<li>{self.convert_inline(content)}</li>'
                else:
                    return f'<li>{self.convert_inline(content)}</li>'

        # If we were in a list and now not list line, close list
        if self.in_list:
            self.in_list = False
            closing = f'</{self.list_type}>'
            self.list_type = None
            return closing + self.convert_line(line)

        # Tables: detect pipe pattern: |---| for header separator
        if '|' in line_content and re.search(r'^\s*\|?\s*[-\:]+\s*\|', line_content):
            # Simple table support: we assume table structure
            # We'll parse table rows
            # For simplicity, we just convert to <table> with <tr> and <td>
            # We need to know if it's header or data rows
            # We'll treat first row as header if second row contains '---'
            # We'll implement as separate function
            return self._convert_table(line)

        # Normal paragraph
        return self._close_blocks() + f'<p>{self.convert_inline(line_content)}</p>'

    def _convert_table(self, line):
        # This is a simplified table converter
        # We'll buffer lines until table ends
        # For simplicity, we'll just return the line as is with a note
        # In a full implementation, we'd parse multiple lines.
        # Here we'll just treat it as a paragraph
        return f'<p>TABLE: {line}</p>'

    def _close_blocks(self):
        result = ''
        if self.in_blockquote:
            result += '</blockquote>'
            self.in_blockquote = False
        if self.in_list:
            result += f'</{self.list_type}>'
            self.in_list = False
            self.list_type = None
        return result

    def convert(self, markdown):
        lines = markdown.splitlines()
        html_parts = []
        for line in lines:
            html_parts.append(self.convert_line(line))
        # Close any open blocks at end
        html_parts.append(self._close_blocks())
        return ''.join(html_parts)

def main():
    converter = MarkdownConverter()
    print("=== Markdown to HTML Converter ===")
    while True:
        print("\n1. Convert text input")
        print("2. Convert from file")
        print("3. Exit")
        choice = input("Choose: ").strip()
        if choice == '1':
            print("Enter Markdown (end with empty line):")
            lines = []
            while True:
                line = input()
                if line == '':
                    break
                lines.append(line)
            text = '\n'.join(lines)
            html = converter.convert(text)
            print("\nHTML output:\n", html)
        elif choice == '2':
            fname = input("Enter file path: ").strip()
            try:
                with open(fname, 'r', encoding='utf-8') as f:
                    text = f.read()
                html = converter.convert(text)
                print("\nHTML output:\n", html)
            except FileNotFoundError:
                print("File not found.")
        elif choice == '3':
            print("Goodbye!")
            break
        else:
            print("Invalid choice.")

if __name__ == "__main__":
    main()
