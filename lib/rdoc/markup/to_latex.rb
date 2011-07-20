# -*- coding: utf-8 -*-

require "rdoc/markup/formatter"
require "rdoc/markup/inline"

#This is an RDoc Converter/Formatter that turns the RDoc
#markup into LaTeX code. It’s intended for use with
#the RDoc::Generator::PDF_LaTeX class, but if you like you
#can use it on it’s own (but note this class absolutely
#depends on RDoc’s parser). To use it, you first have
#to instanciate this class, and then call the #convert method
#on it with the text you want to convert:
#
#  f = RDoc::Markup::ToLaTeX.new
#  f.convert("A *bold* and +typed+ text.")
#
#Should result in:
#
#  A \textbf{bold} and \texttt{typed} text.
#
#If for any reason you want to just escape LaTeX control characters,
#you may do so by calling the #escape method. See it’s documentation
#for an example.
class RDoc::Markup::ToLaTeX < RDoc::Markup::Formatter
  include RDoc::Text

  #Maps RDoc’s list types to the corresponding LaTeX ones.
  #TODO: There are some missing here!
  LIST_TYPE2LATEX = {
    :BULLET => ["\\begin{itemize}", "\\end{itemize}"],
    :LABEL => ["\\begin{description}", "\\end{description}"], 
    :NUMBER => ["\\begin{enumerate}", "\\end{enumerate}"]
  }.freeze

  #LaTeX heading commands. 0 is nil as there is no zeroth heading.
  LATEX_HEADINGS = [nil,                #Dummy, no hash needed with this
                    "\\headingI{%s}",   #h1
                    "\\headingII{%s}",  #h2
                    "\\headingIII{%s}", #h3
                    "\\headingIV{%s}",  #h4
                    "%s",               #No h5
                    "%s"].freeze        #No h6

  #Characters that need to be escaped for LaTeX and their
  #corresponding escape sequences.
  LATEX_SPECIAL_CHARS = {
    /\\/  => "\\textbackslash{}",
    /\$/  => "\\$",
    /#/   => "\\#",
    /%/   => "\\%", 
    /\^/  => "\\^", 
    /&/   => "\\&",
    /_/   => "\\_",
    /(?<!textbackslash){/   => "\\{",
    /(?<!textbackslash{)}/   => "\\}",
    /~/   => "\\~",
    /LaTeX/ => "\\LaTeX{}"
  }.freeze

  #Instanciates this formatter.
  def initialize
    super
    init_tags
  end

  def init_tags
    add_tag(:BOLD, "\\textbf{", "}")
    add_tag(:TT, "\\texttt{", "}")
    add_tag(:EM, "\\textit{", "}")
  end
  
  ########################################
  # Visitor
  ########################################

  #First method called.
  def start_accepting
    @result = ""
  end

  #Last method called. Supposed to return the result string.
  def end_accepting
    @result
  end

  #Adds par’s text plus newline to the result.
  def accept_paragraph(par)
    @result << to_latex(par.text) << "\n"
  end

  #Puts ver’s text between \begin{verbatim} and \end{verbatim}
  def accept_verbatim(ver)
    @result << "\\begin{verbatim}\n" << ver.text << "\n\\end{verbatim}\n"
  end

  #Adds a \rule. The rule’s height is <tt>rule.weight</tt> pt, the
  #rule’s with \textwidth.
  def accept_rule(rule)
    @result << "\\rule{\\textwidth}{" << rule.weight << "pt}\n"
  end

  #Adds \begin{<list type}.
  def accept_list_start(list)
    @result << LIST_TYPE2LATEX[list.type][0] << "\n"
  end

  #Adds \end{list_type}.
  def accept_list_end(list)
    @result << LIST_TYPE2LATEX[list.type][1] << "\n"
  end

  #Adds \item[label_if_necessary].
  def accept_list_item_start(item)
    if item.label
      @result << "\\item[#{escape(item.label)}] " #Newline done by ending method
    else
      @result << "\\item " #Newline done by ending method
    end
  end

  #Adds the terminating newline for an item.
  def accept_list_item_end(item)
    @result << "\n"
  end

  #Adds \\, a line break.
  def accept_blank_line(line)
    @result << "\\\\"
  end

  #Adds a fitting \section, \subsection, etc. for the heading.
  def accept_heading(head)
    @result << sprintf(LATEX_HEADINGS[head.level], escape(head.text)) << "\n"
  end

  #Writes the raw thing as-is into the document. 
  def accept_raw(raw)
    @result << escape(raw.parts.join("\n"))
  end

  #Escapes all LaTeX control characters from a string.
  #==Parameter
  #[str] The string to remove the characters from.
  #==Return value
  #A new string with many backslashes. :-)
  #==Example
  #  f = RDoc::Markup::ToLaTeX.new
  #  str = "I paid 20$ to buy the_item #15."
  #  puts f.escape(str) #=> I paid 20\$ to buy the\_item \#15.
  def escape(str)
    result = str.dup
    LATEX_SPECIAL_CHARS.each_pair do |regexp, escape_seq|
      result.gsub!(regexp, escape_seq)
    end
    result
  end

  #Converts +item+ to LaTeX text. 
  def to_latex(item)
    #This method’s code has purely been guessed by looking
    #at the caller stack for RDoc::Markup::ToHtml and examining
    #it’s code. The RDoc team should really document better
    #how to write a formatter!
    tokens = @am.flow(escape(item)) #See superclass for @am
    tokens.map!{|t| t.kind_of?(String) ? t.gsub("_", "\\_") : t} #HACK: RDoc removes the backslashes before the underscores!!
    convert_flow(tokens) #See superclass for @am
  end
  
end

