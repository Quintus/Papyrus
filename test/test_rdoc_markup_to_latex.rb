gem "rdoc"
require "rdoc/markup/formatter_test_case"
require "minitest/autorun"
require_relative "../lib/rdoc/markup/to_latex"

class TestRDocMarkupToLaTeX < RDoc::Markup::FormatterTestCase

  add_visitor_tests
  
  def setup
    super
    @to = RDoc::Markup::ToLaTeX.new
  end

  def start_accepting
    assert_empty(@to.result)
    assert_nil(@to.list_in_progress)
  end
  
  def end_accepting
    assert_equal("hi", @to.end_accepting)
  end
  
  def accept_blank_line
    assert_equal("\n\n", @to.result)
  end

  def accept_document
    assert_equal("hello\n", @to.result)
  end

  def accept_heading
    assert_equal("\\microsection*{Hello}\n", @to.result)
  end

  def accept_heading_1
    assert_equal("\\section{Hello}\n", @to.result)
  end

  def accept_heading_2
    assert_equal("\\subsection{Hello}\n", @to.result)
  end

  def accept_heading_3
    assert_equal("\\subsubsection{Hello}\n", @to.result)
  end

  def accept_heading_4
    assert_equal("\\subsubsubsection{Hello}\n", @to.result)
  end

  def accept_heading_b
    assert_equal("\\section{\\textbf{Hello}}\n", @to.result)
  end

  def accept_heading_suppressed_crossref
    assert_equal("\\section{Hello}\n", @to.result)
  end

  def accept_paragraph
    assert_equal("hi\n", @to.result)
  end

  def accept_paragraph_b
    assert_equal("reg \\textbf{bold words} reg\n", @to.result)
  end

  def accept_paragraph_i
    assert_equal("reg \\textit{italic words} reg\n", @to.result)
  end

  def accept_paragraph_plus
    assert_equal("reg \\texttt{teletype} reg\n", @to.result)
  end

  def accept_paragraph_star
    assert_equal("reg \\textbf{bold} reg\n", @to.result)
  end

  def accept_paragraph_underscore
    assert_equal("reg \\textit{italic} reg\n", @to.result)
  end

  def accept_verbatim
    assert_equal("\\begin{Verbatim}\nhi\n  world\n\\end{Verbatim}\n", @to.result)
  end

  def accept_raw
    raw = <<-RAW.rstrip
<table>
<tr><th>Name<th>Count
<tr><td>a<td>1
<tr><td>b<td>2
</table>
    RAW
    assert_equal(raw, @to.result)

    #raw2 = "$f(x) = \\frac{1}{2}x^2 + 42$"
  end
  
  def accept_rule
    assert_equal("\\par\\noindent\\rule{\\textwidth}{4pt}\\par\n", @to.result)
  end

  def list_nested
    expected=<<-EX
\\begin{itemize}
\\item l1
\\begin{itemize}
\\item l1.1
\\end{itemize}
\\item l2
\\end{itemize}
    EX
    assert_equal(expected, @to.result)
  end

  def list_verbatim
    expected=<<-EX
\\begin{itemize}
\\item list stuff

\\begin{Verbatim}
* list
  with

  second

  1. indented
  2. numbered

  third

* second
\\end{Verbatim}
\\end{itemize}
    EX
    assert_equal(expected, @to.result)
  end

  def accept_list_start_bullet
    assert_equal("\\begin{itemize}\n", @to.result)
  end

  def accept_list_start_label
    assert_equal("\\begin{description}\n", @to.result)
  end

  def accept_list_start_lalpha
    assert_equal("\\begin{lalphaenum}\n", @to.result)
  end

  def accept_list_start_ualpha
    assert_equal("\\begin{ualphaenum}\n", @to.result)
  end

  def accept_list_start_note
    assert_equal("\\begin{description}\n", @to.result)
  end

  def accept_list_start_number
    assert_equal("\\begin{enumerate}\n", @to.result)
  end
  
  def accept_list_item_start_bullet
    assert_equal("\\begin{itemize}\n\\item ", @to.result)
  end

  def accept_list_item_start_label
    assert_equal("\\begin{description}\n\\item[cat] ", @to.result)
  end

  def accept_list_item_start_lalpha
    assert_equal("\\begin{lalphaenum}\n\\item ", @to.result)
  end

  def accept_list_item_start_ualpha
    assert_equal("\\begin{ualphaenum}\n\\item ", @to.result)
  end
  
  def accept_list_item_start_note
    assert_equal("\\begin{description}\n\\item[cat:] ", @to.result)
  end

  def accept_list_item_start_note_2
    assert_equal("\\begin{description}\n\\item[\texttt{teletype}] teletype description\n\\end{description}", @to.result)
  end
  
  def accept_list_item_start_number
    assert_equal("\\begin{enumerate}\n\\item ", @to.result)
  end

  def accept_list_end_bullet
    assert_equal("\\begin{itemize}\n\\end{itemize}\n", @to.result)
  end

  def accept_list_end_label
    assert_equal("\\begin{description}\n\\end{description}\n", @to.result)
  end

  def accept_list_end_lalpha
    assert_equal("\\begin{lalphaenum}\n\\end{lalphaenum}\n", @to.result)
  end

  def accept_list_end_ualpha
    assert_equal("\\begin{ualphaenum}\n\\end{ualphaenum}\n", @to.result)
  end

  def accept_list_end_number
    assert_equal("\\begin{enumerate}\n\\end{enumerate}\n", @to.result)
  end

  def accept_list_end_note
    assert_equal("\\begin{description}\n\\end{description}\n", @to.result)
  end

  def accept_list_item_end_bullet
  end

  def accept_list_item_end_label
  end

  def accept_list_item_end_lalpha
  end

  def accept_list_item_end_ualpha
  end

  def accept_list_item_end_number
  end

  def accept_list_item_end_note
  end
  
end
