module CodeHelper
  CHANGE_MARKS = { "added" => "A", "changed" => "M", "deleted" => "D" }

  # The file's lines as highlighted HTML, one string per line.
  def highlighted_lines(source)
    lexer = Rouge::Lexer.guess(filename: source.path, source: source.content) rescue Rouge::Lexers::PlainText
    lexer = Rouge::Lexers::ERB if source.path.end_with?(".erb") # guess picks HTML for .html.erb
    formatter = Rouge::Formatters::HTML.new
    lines = [ [] ]
    lexer.lex(source.content).each do |token, value|
      value.split(/(\n)/).each do |part|
        if part == "\n" then lines << []
        elsif !part.empty? then lines.last << [ token, part ]
        end
      end
    end
    lines.pop if lines.last.empty? && source.content.end_with?("\n")
    lines.map { |tokens| formatter.format(tokens).html_safe }
  end

  def change_mark(status)
    tag.span(CHANGE_MARKS.fetch(status), class: "change-mark change-#{status}", title: status.capitalize) if status
  end

  # The file's name, then its folder, which gives way first when space runs out.
  def file_label(path)
    folder, _, name = path.rpartition("/")
    tag.span(class: "truncate") { safe_join([ name, (tag.span(folder, class: "folder") if folder.present?) ].compact, " ") }
  end

  # Folders first, then files, each alphabetically.
  def sorted_tree(node)
    node.sort_by { |name, child| [ child.is_a?(Hash) ? 0 : 1, name.downcase ] }
  end

  def folder_open?(prefix, path)
    path.to_s.start_with?("#{prefix}/")
  end
end
