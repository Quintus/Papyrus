# -*- coding: utf-8 -*-
=begin
This file is part of RDoc PDF LaTeX.

RDoc PDF LaTeX is a RDoc plugin for generating PDF files.
Copyright © 2011  Pegasus Alpha

RDoc PDF LaTeX is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

RDoc PDF LaTeX is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with RDoc PDF LaTeX; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
=end

gem "rdoc"
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
#Some parts of this class are heavily inspired by RDoc’s own
#code, namely:
#* ::new
#* #handle_special_TIDYLINK
#
#See each method’s descriptions for more details.
#
#==How to write a formatter
#RDoc offers an easy to adapt visitor pattern for creating new formatters.
#"Easy" to a certain extend, as soon as you get into inline formatting
#RDoc’s documentation lacks some serious information. Nevertheless, I'll
#describe the process of formatting here, even if I reiterate some of the
#concepts the documentation for class RDoc::Markup::Formatter mentions.
#
#First, you have to derive your class from RDoc::Markup::Formatter and
#then obscurely have to include the RDoc::Text module, because this one
#is responsible for parsing inline markup.
#
#Assuming you already wrote a generator making use of your
#formatter (because without writing a generator, writing
#a formatter is a somewhat nonsense undertaking as noone
#instanciates the class), I continue on how RDoc interacts
#with your formatter class.
#
#So, somewhere in your generator you call the ::new method of
#your formatter (preferably inside the YourGenerator#formatter
#method, but I assume you know this as it belongs to writing
#generators and not formatters). Ensure that this method takes
#at least one argument called +markup+, which defaults to a +nil+
#value! Till now I didn’t really find out what it’s for, but
#the RDoc::Markup::Formatter::new method expects it, so we
#should obey it. All other arguments are up to your choice,
#just ensure that you call +super+ inside your +initialize+ method
#with the +markup+ parameter as it’s sole argument.
#
#The next task for your +initialize+ is to tell RDoc how to cope
#with the three inline formatting sequences: Bold, italic
#and teletypd text. Call the +add_tag+ inherited from
#the Formatter class and pass it one of the following
#symbols along with how you want to transform the given
#sequence:
#
#* <tt>:BOLD</tt>
#* <tt>:EM</tt>
#* <tt>:TT</tt>
#
#If you want to add so-called "specials" to your formatter (and you’re likely
#to, as hyperlinks are such specials), you have to dig around in RDoc’s
#own formatters, namely RDoc::Markup::ToHtml, and find out that there’s
#an instance variable called @markup that allows you to do this. Call
#it’s +add_special+ method with a regular expression that finds your special
#and a name for it as a symbol. RDoc itself uses the following specials:
#
#  @markup.add_special(/((link:|https?:|mailto:|ftp:|www\.)\S+\w)/, :HYPERLINK)
#  @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\.\S+?\])/, :TIDYLINK)
#
#If you add a special, you have to provide a <tt>handle_special_YOURSPECIAL</tt> method
#in your formatter, where YOURSPECIAL corresponds to the symbol you previously
#passed to the +add_special+ method. This method gets passed a RDoc::Special object, from
#which you just need to know the +text+ method that retrieves the text your regular
#expression matched. Apply whatever you want, and return a string RDoc will incorporate
#into the result.
#
#During the formatting process RDoc calls various methods on your
#formatter, the full list can be seen in the documentation for the
#class RDoc::Markup::Formatter. Note that *those* methods should _not_
#return a string--in fact, RDoc ignores their return values. You are
#expected to keep track of your formatted text, e.g. create an instance
#variable @result in your +initialize+ method and fill it with text
#in the methods called by RDoc. 
#
#When everything has been processed, RDoc calls the +end_accepting+ method
#on your formatter instance. It’s return value is expected to be the complete
#parsing result, so if you used a string instance variable @result as
#I recommended above, you should return it’s value from that method.
#
#=== Inline formatting
#This isn’t as hard as I explained earlier, but you have to know what
#to do, otherwise you’ll be stuck with paragraphs being treated as
#paragraphs as a whole, but no inline formatting happens. So, to
#achieve this, you have to define a method that initiates the
#inline formatting process, RDoc’s HTML formatter’s method
#is RDoc::Markup::HTML#to_html, so you may choose a name
#fitting that name scheme (I did for this formatter as
#well, but the +to_latex+ method is private). You then call
#this method inside your +accept_paragraph+ method with the
#paragraph’s text as it’s argument. The content of the method
#cannot be known if you didn’t dig around in RDoc’s formatter
#sources--it’s the following:
#
#  convert_flow(@am.flow(paragraph_text_here))
#
#So, what does this do? It uses the superclass’s (undocumented) instance
#variable @am, which is an instance of RDoc::AttributeFormatter that
#is responsible for keeping track of which inline text attributes to
#apply where. It has this magic method called +flow+ which takes
#one argument: The text of the paragraph you want to format. It tokenizes
#the paragraph into little pieces of some RDoc tokens and plain strings
#and returns them as an array (yes, this was the inline parsing process).
#We then take that token array and pass it directly to the +convert_flow+
#method (inhertied from the Formatter class) which knows how to handle
#the token sequence and comes back to your formatter instance each time
#it wants to format something, bold or teletyped text for instance
#(remember? You defined that with +add_tag+). If you want to format plain
#text without any special markup as well (I had to for the LaTeX formatter,
#because for LaTeX several characters have to be escaped even in
#nonformatted text, e.g. the underscore) you have to provide the method
#+convert_string+. It will get passed all strings that don’t have any
#markup applied; it’s return value will be in the final result.
class RDoc::Markup::ToLaTeX < RDoc::Markup::Formatter
  include RDoc::Text

  #Maps RDoc’s list types to the corresponding LaTeX ones.
  LIST_TYPE2LATEX = {
    :BULLET => ["\\begin{itemize}", "\\end{itemize}"],
    :NUMBER => ["\\begin{enumerate}", "\\end{enumerate}"],
    :LABEL  => ["\\begin{description}", "\\end{description}"],
    :UALPHA => ["\\begin{ualphaenum}", "\\end{ualphaenum}"],
    :LALPHA => ["\\begin{lalphaenum}", "\\end{lalphaenum}"],
    :NOTE   => ["\\begin{description}", "\\end{description}"]
  }.freeze

  #LaTeX heading commands. 0 is nil as there is no zeroth heading.
  LATEX_HEADINGS = [nil,                         #Dummy, no hash needed with this
                    "\\section{%s}",             #h1
                    "\\subsection{%s}",          #h2
                    "\\subsubsection{%s}",       #h3
                    "\\subsubsubsection{%s}",    #h4
                    "\\microsection*{%s}",       #h5
                    "\\paragraph*{%s.} ",        #h6
                    "\\subparagraph*{%s}",       #Needed??
                    "%s", "%s", "%s", "%s", "%s", "%s"].freeze #Everything below is just ignored.

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
    /\.{3}/ => "\\ldots",
    /~/     => "\\~",
    /©/     => "\\copyright{}",
    /LaTeX/ => "\\LaTeX{}"
  }.freeze

  #Level relative to which headings are produced from this
  #formatter. E.g., if this is 1, and the user requests a level
  #2 heading, he actually gets a level 3 one.
  attr_reader :heading_level
  #Contains everything processed so far as a string.
  attr_reader :result
  alias res result
  #The innermost type of list we’re currently in or +nil+
  #if we don’t process a list at the moment.
  attr_reader :list_in_progress
  
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
  #the code for more details.
  def initialize(heading_level = 0, markup = nil)
    super(markup)
    
    @heading_level = heading_level
    @result = ""
    @list_in_progress = nil
    
    #Copied from RDoc 3.8, adds link capabilities
    @markup.add_special(/((link:|https?:|mailto:|ftp:|www\.)\S+\w)/, :HYPERLINK)
    @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\.\S+?\])/, :TIDYLINK)

    #Add definitions for inline markup
    add_tag(:BOLD, "\\textbf{", "}")
    add_tag(:TT, "\\verb~", "~")
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
    @result << "\\begin{Verbatim}\n" << ver.text.chomp << "\n\\end{Verbatim}\n"
  end

  #Adds a \rule. The rule’s height is <tt>rule.weight</tt> pt, the
  #rule’s width \textwidth.
  def accept_rule(rule)
    @result << "\\par\\noindent\\rule{\\textwidth}{" << rule.weight.to_s << "pt}\\par\n"
  end

  #Adds \begin{<list type>}.
  def accept_list_start(list)
    @list_in_progress = list.type
    @result << LIST_TYPE2LATEX[list.type][0] << "\n"
  end

  #Adds \end{list_type}.
  def accept_list_end(list)
    @result << LIST_TYPE2LATEX[list.type][1] << "\n"
    @list_in_progress = nil
  end

  #Adds \item[label_if_necessary].
  def accept_list_item_start(item)
    if item.label
      
      if @list_in_progress == :NOTE
        @result << "\\item[#{to_latex_suppress_crossref(item.label)}:] " #Newline done by ending paragraph
      else
        @result << "\\item[#{to_latex_suppress_crossref(item.label)}] " #Newline done by ending paragraph
      end
    else
      @result << "\\item " #Newline done by ending method
    end
  end

  #Adds a terminating \n for a list item if this is necessary
  #(usually the newline is automatically created by processing
  #the list paragraph).
  def accept_list_item_end(item)
    @result << "\n" unless @result.end_with?("\n")
  end

  #Termiantes a paragraph by inserting two newlines.
  def accept_blank_line(line)
    @result.chomp!
    @result << "\n\n"
  end

  #Adds a fitting \section, \subsection, etc. for the heading.
  def accept_heading(head)
    @result << sprintf(LATEX_HEADINGS[@heading_level + head.level], to_latex_suppress_crossref(head.text)) << "\n"
  end

  #Writes the raw thing as-is into the document. 
  def accept_raw(raw)
    @result << raw.parts.join("\n")
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
  
  #Method copied from RDoc project and slightly modified.
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

  #LaTeX doesn't like excessive cross-references in certain
  #playes, e.g. headings. To allow for inline formatting without
  #cross-references, this method exists. It’s exactly the same
  #as #to_latex, except it’ll never rely on subclasses such
  #as ToLaTeX_Crossref.
  def to_latex_suppress_crossref(item)
    RDoc::Markup::ToLaTeX.new(@heading_level).instance_eval do
      convert_flow(@am.flow(item))
    end
  end

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

