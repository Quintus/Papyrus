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
#
#Some parts of this class are copyrighted by the RDoc team:
#* ::new
#* #handle_special_TIDYLINK
#
#See each method’s descriptions for more details.
class RDoc::Markup::ToLaTeX < RDoc::Markup::Formatter
  include RDoc::Text

  #Maps RDoc’s list types to the corresponding LaTeX ones.
  #TODO: There are some missing here!
  LIST_TYPE2LATEX = {
    :BULLET => ["\\begin{itemize}", "\\end{itemize}"],
    :LABEL => ["\\begin{description}", "\\end{description}"], 
    :NUMBER => ["\\begin{enumerate}", "\\end{enumerate}"],
    :NOTE => ["\\begin{description}", "\\end{description}"]
  }.freeze

  #LaTeX heading commands. 0 is nil as there is no zeroth heading.
  LATEX_HEADINGS = [nil,                         #Dummy, no hash needed with this
                    "\\section{%s}",             #h1
                    "\\subsection{%s}",          #h2
                    "\\subsubsection{%s}",       #h3
                    "\\subsubsubsection{%s}",    #h4
                    "\\microsection*{%s}",       #h5
                    "\\paragraph*{%s}. "].freeze #h6

  #Characters that need to be escaped for LaTeX and their
  #corresponding escape sequences. Note the order if important,
  #otherwise some things (especiallaly \ and {}) are escaped
  #twice.
  LATEX_SPECIAL_CHARS = {
    /\\/    => "\\textbackslash{}",
    /\$/    => "\\$",
    /#/     => "\\#",
    /%/     => "\\%",
    /\^/    => "\\^",
    /&/     => "\\\\&", #WTF? \\& in gsub doesn't do anything?! TODO: File Ruby bug when back from vaction...
    /(?<!textbackslash){/  => "\\{",
    /(?<!textbackslash{)}/ => "\\}",
    /_/     => "\\textunderscore{}",
    /~/     => "\\~",
    /©/     => "\\copyright{}",
    /LaTeX/ => "\\LaTeX{}"
  }.freeze

  #Level relative to which headings are produced from this
  #formater. E.g., if this is 1, and the user requests a level
  #2 heading, he actually gets a level 3 one.
  attr_reader :heading_level
  
  #Instanciates this formatter.
  #==Parameters
  #[heading_level] Minimum heading level. Useful for context-based heading;
  #                a value of 1 indicates that all requested level 2 headings
  #                are turned into level 3 ones; a value of 2 would turn them
  #                into level 4 ones.
  #[markup] Parameter expected by the superclass. TODO: What for?
  #==Return value
  #A new instance of this class.
  #==Example
  #  f = RDoc::Formatter::ToLaTeX.new
  #  puts f.convert("Some *bold* text") #=> Some \textbf{bold} text
  #==Remarks
  #Some lines of this method have their origin in the RDoc project. See
  #the code for more details. Copyright by them.
  def initialize(heading_level = 0, markup = nil)
    super(markup)
    
    @heading_level = heading_level
    
    #Copied from RDoc 3.8, adds link capabilities
    @markup.add_special(/((link:|https?:|mailto:|ftp:|www\.)\S+\w)/, :HYPERLINK)
    @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\.\S+?\])/, :TIDYLINK)

    #Add definitions for inline markup
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
    @result << "\\begin{Verbatim}\n" << ver.text << "\n\\end{Verbatim}\n"
  end

  #Adds a \rule. The rule’s height is <tt>rule.weight</tt> pt, the
  #rule’s with \textwidth.
  def accept_rule(rule)
    @result << "\\rule{\\textwidth}{" << rule.weight << "pt}\n"
  end

  #Adds \begin{<list type>}.
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

  #Termiantes a paragraph by inserting two newlines.
  def accept_blank_line(line)
    @result << "\n\n"
  end

  #Adds a fitting \section, \subsection, etc. for the heading.
  def accept_heading(head)
    @result << sprintf(LATEX_HEADINGS[@heading_level + head.level], escape(head.text)) << "\n"
  end

  #Writes the raw thing as-is into the document. 
  def accept_raw(raw)
    @result << escape(raw.parts.join("\n"))
  end

  #Handles raw hyperlinks.
  def handle_special_HYPERLINK(special)
    make_url(special.text)
  end

  #Called for each plaintext string in a paragraph by
  #the #convert_flow method called in #to_latex.
  def convert_string(str)
    escape(str)
  end
  
  #Method copied from RDoc project and slightly modified, 
  #copyright belongs to them. Ruby’s license.
  #
  #Handles hyperlinks of form {text}[url] and text[url].
  def handle_special_TIDYLINK(special)
    text = special.text

    return escape(text) unless text =~ /\{(.*?)\}\[(.*?)\]/ or text =~ /(\S+)\[(.*?)\]/

    label = $1
    url   = $2
    make_url url, escape(label)
  end
  
  #Escapes all LaTeX control characters from a string.
  #==Parameter
  #[str] The string to remove the characters from.
  #==Return value
  #A new string with many backslashes. :-)
  #==Example
  #  f = RDoc::Markup::ToLaTeX.new
  #  str = "I paid 20$ to buy the_item #15."
  #  puts f.escape(str) #=> I paid 20\$ to buy the\textunderscore{}item \#15.
  def escape(str)
    result = str.dup
    LATEX_SPECIAL_CHARS.each_pair do |regexp, escape_seq|
      result.gsub!(regexp, escape_seq)
    end
    result
  end

  private

  #Converts +item+ to LaTeX text. Difference to #escape: It
  #does inline formatting!
  def to_latex(item)
    #This method’s code has purely been guessed by looking
    #at the caller stack for RDoc::Markup::ToHtml#to_html and examining
    #it’s code. The RDoc team should really document better
    #how to write a formatter!
    convert_flow(@am.flow(item)) #See superclass for @am
  end
  
  #Turns +text+ and +url+ into a LaTeX (hyperref) link via \href.
  #If URL doesn’t start with a protocol definition (e.g. <tt>ftp://</tt>),
  #prepend <tt>http://</tt>. If +text+ is nil, the link is displayed
  #raw (but the protocol still is prepended if necessary).
  def make_url(url, text = nil)
    url = "http://#{url}" unless url =~ /^.*?:/
    if text
      "\\href{#{url}}{#{text}}"
    else
      "\\url{#{url}}"
    end
  end
  
end

