# markdown_converter.rb
class MarkdownConverter
  def initialize
    @in_code_block = false
    @code_lang = ''
    @in_list = false
    @list_type = ''
    @in_blockquote = false
  end

  def escape_html(text)
    text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
  end

  def process_inline_formatting(text)
    text.gsub!(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    text.gsub!(/__(.+?)__/, '<strong>\1</strong>')
    text.gsub!(/\*(.+?)\*/, '<em>\1</em>')
    text.gsub!(/_(.+?)_/, '<em>\1</em>')
    text.gsub!(/~~(.+?)~~/, '<del>\1</del>')
    text.gsub!(/!\[([^\]]*)\]\(([^)]+)\)/, '<img src="\2" alt="\1">')
    text.gsub!(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
    text.gsub!(/(?<!["'])(https?:\/\/[^\s<>"']+)/, '<a href="\1">\1</a>')
    text
  end

  def convert_inline(text)
    parts = text.split('`')
    parts.each_with_index do |part, i|
      if i.even?
        parts[i] = process_inline_formatting(part)
      else
        parts[i] = '<code>' + escape_html(part) + '</code>'
      end
    end
    parts.join
  end

  def close_blocks
    out = ''
    if @in_blockquote
      out += '</blockquote>'
      @in_blockquote = false
    end
    if @in_list
      out += "</#{@list_type}>"
      @in_list = false
      @list_type = ''
    end
    out
  end

  def convert_line(line)
    return close_blocks + "\n" if line.nil? || line.empty?
    trimmed = line.lstrip
    indent = line.length - trimmed.length

    # Code fence
    if trimmed.start_with?('```')
      if !@in_code_block
        @in_code_block = true
        @code_lang = trimmed[3..-1].strip
        return @code_lang.empty? ? "<pre><code>\n" : "<pre><code class=\"language-#{@code_lang}\">\n"
      else
        @in_code_block = false
        return "</code></pre>\n"
      end
    end
    if @in_code_block
      return escape_html(line) + "\n"
    end

    # Headings
    if trimmed.start_with?('#')
      level = 0
      while level < trimmed.length && trimmed[level] == '#'
        level += 1
      end
      level = 6 if level > 6
      heading_text = trimmed[level..-1].strip
      return close_blocks + "<h#{level}>#{convert_inline(heading_text)}</h#{level}>"
    end

    # Horizontal rule
    if trimmed =~ /^(---|___|\*\*\*)\s*$/
      return close_blocks + "<hr>"
    end

    # Blockquotes
    if trimmed.start_with?('>')
      content = trimmed[1..-1].lstrip
      if !@in_blockquote
        @in_blockquote = true
        return "<blockquote>" + convert_line(content)
      end
      return convert_line(content)
    end
    if @in_blockquote
      @in_blockquote = false
      return "</blockquote>" + convert_line(line)
    end

    # Lists
    list_match = trimmed.match(/^(\s*)([\-\*\+]|\d+\.)\s+(.*)/)
    if list_match
      marker = list_match[2]
      content = list_match[3]
      is_ordered = marker.end_with?('.')
      list_type = is_ordered ? 'ol' : 'ul'
      if !@in_list
        @in_list = true
        @list_type = list_type
        return "<#{list_type}>\n<li>#{convert_inline(content)}</li>"
      else
        if @list_type != list_type
          closing = "</#{@list_type}>"
          @list_type = list_type
          return closing + "<#{list_type}>\n<li>#{convert_inline(content)}</li>"
        end
        return "<li>#{convert_inline(content)}</li>"
      end
    end
    if @in_list
      @in_list = false
      closing = "</#{@list_type}>"
      @list_type = ''
      return closing + convert_line(line)
    end

    # Table (simplified)
    if trimmed.include?('|') && trimmed =~ /^\s*\|?\s*[-:]+\s*\|/
      return close_blocks + "<p>TABLE: #{convert_inline(trimmed)}</p>"
    end

    # Paragraph
    close_blocks + "<p>#{convert_inline(trimmed)}</p>"
  end

  def convert(markdown)
    lines = markdown.split("\n")
    result = ''
    lines.each { |line| result += convert_line(line) }
    result + close_blocks
  end
end

def main
  converter = MarkdownConverter.new
  puts "=== Markdown to HTML Converter ==="
  loop do
    puts "\n1. Convert text input"
    puts "2. Convert from file"
    puts "3. Exit"
    print "Choose: "
    choice = gets.chomp.strip
    case choice
    when '1'
      puts "Enter Markdown (end with empty line):"
      lines = []
      loop do
        line = gets.chomp
        break if line.empty?
        lines << line
      end
      text = lines.join("\n")
      html = converter.convert(text)
      puts "\nHTML output:\n#{html}"
    when '2'
      print "Enter file path: "
      fname = gets.chomp.strip
      begin
        text = File.read(fname)
        html = converter.convert(text)
        puts "\nHTML output:\n#{html}"
      rescue => e
        puts "Error: #{e.message}"
      end
    when '3'
      puts "Goodbye!"
      break
    else
      puts "Invalid choice."
    end
  end
end

main if __FILE__ == $0
