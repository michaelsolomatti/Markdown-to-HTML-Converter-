// markdown_converter.js
const readline = require('readline');
const fs = require('fs');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function ask(question) {
    return new Promise(resolve => rl.question(question, resolve));
}

class MarkdownConverter {
    constructor() {
        this.inCodeBlock = false;
        this.codeLang = '';
        this.inList = false;
        this.listType = '';
        this.inBlockquote = false;
    }

    escapeHTML(text) {
        return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    processInlineFormatting(text) {
        // Bold
        text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        text = text.replace(/__(.+?)__/g, '<strong>$1</strong>');
        // Italic
        text = text.replace(/\*(.+?)\*/g, '<em>$1</em>');
        text = text.replace(/_(.+?)_/g, '<em>$1</em>');
        // Strikethrough
        text = text.replace(/~~(.+?)~~/g, '<del>$1</del>');
        // Images
        text = text.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img src="$2" alt="$1">');
        // Links
        text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
        // Auto-links
        text = text.replace(/(?<!["'])(https?:\/\/[^\s<>"']+)/g, '<a href="$1">$1</a>');
        return text;
    }

    convertInline(text) {
        const parts = text.split('`');
        for (let i = 0; i < parts.length; i++) {
            if (i % 2 === 0) {
                parts[i] = this.processInlineFormatting(parts[i]);
            } else {
                parts[i] = '<code>' + this.escapeHTML(parts[i]) + '</code>';
            }
        }
        return parts.join('');
    }

    closeBlocks() {
        let out = '';
        if (this.inBlockquote) {
            out += '</blockquote>';
            this.inBlockquote = false;
        }
        if (this.inList) {
            out += `</${this.listType}>`;
            this.inList = false;
            this.listType = '';
        }
        return out;
    }

    convertLine(line) {
        if (line === '') {
            return this.closeBlocks() + '\n';
        }
        const trimmed = line.trimLeft();
        const indent = line.length - trimmed.length;

        // Code fence
        if (trimmed.startsWith('```')) {
            if (!this.inCodeBlock) {
                this.inCodeBlock = true;
                this.codeLang = trimmed.slice(3).trim();
                return this.codeLang ? `<pre><code class="language-${this.codeLang}">\n` : '<pre><code>\n';
            } else {
                this.inCodeBlock = false;
                return '</code></pre>\n';
            }
        }
        if (this.inCodeBlock) {
            return this.escapeHTML(line) + '\n';
        }

        // Headings
        if (trimmed.startsWith('#')) {
            let level = 0;
            while (level < trimmed.length && trimmed[level] === '#') level++;
            if (level > 6) level = 6;
            const headingText = trimmed.slice(level).trim();
            return this.closeBlocks() + `<h${level}>${this.convertInline(headingText)}</h${level}>`;
        }

        // Horizontal rule
        if (/^(---|___|\*\*\*)\s*$/.test(trimmed)) {
            return this.closeBlocks() + '<hr>';
        }

        // Blockquotes
        if (trimmed.startsWith('>')) {
            const content = trimmed.slice(1).trimLeft();
            if (!this.inBlockquote) {
                this.inBlockquote = true;
                return '<blockquote>' + this.convertLine(content);
            }
            return this.convertLine(content);
        }
        if (this.inBlockquote) {
            this.inBlockquote = false;
            return '</blockquote>' + this.convertLine(line);
        }

        // Lists
        const listMatch = trimmed.match(/^(\s*)([\-\*\+]|\d+\.)\s+(.*)/);
        if (listMatch) {
            const marker = listMatch[2];
            const content = listMatch[3];
            const isOrdered = marker.endsWith('.');
            const listType = isOrdered ? 'ol' : 'ul';
            if (!this.inList) {
                this.inList = true;
                this.listType = listType;
                return `<${listType}>\n<li>${this.convertInline(content)}</li>`;
            } else {
                if (this.listType !== listType) {
                    const closing = `</${this.listType}>`;
                    this.listType = listType;
                    return closing + `<${listType}>\n<li>${this.convertInline(content)}</li>`;
                }
                return `<li>${this.convertInline(content)}</li>`;
            }
        }
        if (this.inList) {
            this.inList = false;
            const closing = `</${this.listType}>`;
            this.listType = '';
            return closing + this.convertLine(line);
        }

        // Table (simplified)
        if (trimmed.includes('|') && /^\s*\|?\s*[-\:]+\s*\|/.test(trimmed)) {
            return this.closeBlocks() + `<p>TABLE: ${this.convertInline(trimmed)}</p>`;
        }

        // Paragraph
        return this.closeBlocks() + `<p>${this.convertInline(trimmed)}</p>`;
    }

    convert(markdown) {
        const lines = markdown.split('\n');
        let result = '';
        for (const line of lines) {
            result += this.convertLine(line);
        }
        result += this.closeBlocks();
        return result;
    }
}

async function main() {
    const converter = new MarkdownConverter();
    console.log("=== Markdown to HTML Converter ===");
    while (true) {
        console.log("\n1. Convert text input");
        console.log("2. Convert from file");
        console.log("3. Exit");
        const choice = await ask("Choose: ");
        switch (choice.trim()) {
            case '1': {
                console.log("Enter Markdown (end with empty line):");
                const lines = [];
                while (true) {
                    const line = await ask("");
                    if (line === '') break;
                    lines.push(line);
                }
                const text = lines.join('\n');
                const html = converter.convert(text);
                console.log("\nHTML output:\n", html);
                break;
            }
            case '2': {
                const fname = await ask("Enter file path: ");
                try {
                    const data = fs.readFileSync(fname, 'utf8');
                    const html = converter.convert(data);
                    console.log("\nHTML output:\n", html);
                } catch (e) {
                    console.log("File not found or error.");
                }
                break;
            }
            case '3':
                console.log("Goodbye!");
                rl.close();
                return;
            default:
                console.log("Invalid choice.");
        }
    }
}

main().catch(console.error);
