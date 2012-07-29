# -*- coding: utf-8 -*-
#
# This file is part of Papyrus.
#
# Papyrus is a RDoc plugin for generating PDF files.
# Copyright © 2011, 2012 Pegasus Alpha
#
# Papyrus is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Papyrus is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Papyrus.  If not, see <http://www.gnu.org/licenses/>.

require "fileutils"
require "pathname"
require "open3"
gem "rdoc"
require "prawn"
require "rdoc/rdoc"
require "rdoc/generator"

class RDoc::Generator::Papyrus

  #Generic exception class for this library.
  class PapyrusError < StandardError
  end
  
  RDoc::RDoc.add_generator(self) #Tell RDoc about the new generator

  #Description displayed in RDoc’s help.
  DESCRIPTION = "PDF generator based on Prawn"

  #Root directory of this project.
  ROOT_DIR = Pathname.new(__FILE__).dirname.parent.parent.parent
  
  #The version number.
  VERSION = ROOT_DIR.join("VERSION.txt").read.chomp.freeze
  
  #Directory where the LaTeX template files are stored.
  DATA_DIR = ROOT_DIR + "data"
  #Directory where the internal fonts are stored.
  FONT_DIR = DATA_DIR + "fonts"

  # Number of PDF points to indent method descriptions.
  METHOD_INDENTATION = 40

  # Maximum number of characters a constant’s value is
  # allowed to have *before* the rest of the value is
  # cut off and a "…" is appended (so that the resulting
  # value character count is effectively this value
  # plus 1 (… is a single character)).
  CONSTANT_VALUE_CHAR_COUNT = 20

  class << self

    #Called by RDoc during option processing. Adds commandline
    #switches specific to this generator.
    #==Parameter
    #[options] The yet unparsed RDoc::Options.
    def setup_options(options)
      debug("Teaching new options to RDoc")
      #Define the methods to get and set the options
      options.extend(RDoc::Generator::Papyrus::Options)
    
      options.option_parser.separator ""
      options.option_parser.separator "Papyrus generator options:"
      options.option_parser.separator ""
    
      #Define the options themselves
      options.option_parser.on("--[no-]show-pages", "Enables or disables page", "numbers following hyperlinks (default true).") do |val|
        debug("Found --show-pages: #{val}")
        options.show_pages = val
      end
    
      options.option_parser.on("--inputencoding", "Sets the encoding used for the input files.", "Defaults to '#{RDoc::Generator::Papyrus::Options::DEFAULT_INPUT_ENCODING}'.") do |val|
        debug("Found --inputencoding: #{val}")
        options.inputencoding = val
      end
    
      options.option_parser.on("--[no-]append-source",
                               "If set, the sourcecode of all methods is included", 
                               "as an appendix (warning: HUGE PDF", 
                               "files can be the result! Default: false."){|val| options.append_source = val}
    
    end

    private

    #If RDoc is invoked in debug mode, writes out +str+ using
    #+puts+ (prepending "[papyrus] ") and calls it’s block 
    #if one was given. If RDoc isn’t invoked in debug mode, 
    #does nothing.
    def debug(str = nil)
      if $DEBUG_RDOC
        puts "[papyrus] #{str}" if str
        yield if block_given?
      end
    end

  end

  #Creates a new instance of this class. Automatically called by RDoc.
  #There shouldn’t be any need for you to call this.
  #==Parameter
  #[options] RDoc passes the current RDoc::Options instance here.
  #==Return value
  #The newly created instance.
  def initialize(options)
    #The requiring of the rest of the library *must* be placed here,
    #because otherwise it’s loaded during RDoc’s discovering process,
    #effectively eliminating the possibility to generate anything
    #other than LaTeX output due to the overwrites the
    #RDoc::Generator::LaTeX_Markup module does.
    require_relative "../markup/to_prawn"
    require_relative "../markup/to_prawn_table_cell"
    require_relative "prawn_markup"
    
    @options = options
    @output_dir = Pathname.pwd.expand_path + @options.op_dir
  end

  def generate(top_levels)
    #Prepare all the data needed by all the templates
    doc_title = @options.title

    #Get the rdoc file list and move the "main page file" to the beginning.
    debug("Examining toplevel files")
    @rdoc_files = top_levels.select{|t| t.name =~ /\.rdoc$/i}
    debug("Found #{@rdoc_files.count} toplevels ending in .rdoc that will be processed")
    if @options.main_page #nil if not set, no main page
      main_index = @rdoc_files.index{|t| t.full_name == @options.main_page}
      if main_index #nil if invalid main_page given
        @rdoc_files.unshift(@rdoc_files.slice!(main_index))
        debug("Main page is #{@rdoc_files.first.name}")
      end
    end

    #Get the class, module and methods lists, sorted alphabetically by their full names
    debug("Sorting classes and modules")
    @classes = RDoc::TopLevel.all_classes.sort_by{|klass| klass.full_name}
    @modules = RDoc::TopLevel.all_modules.sort_by{|mod| mod.full_name}
    @classes_and_modules = @classes.concat(@modules).sort_by{|mod| mod.full_name}
    # @methods = @classes_and_modules.map{|mod| mod.method_list}.flatten.sort

    @pdf = nil
    2.times do |i| # Two times for resolving all references
      puts "Constructing PDF..."
      @pdf = Prawn::Document.new

      # Register our font families
      @pdf.font_families.update(RDoc::Markup::ToPrawn::SERIF_FONT_NAME => RDoc::Markup::ToPrawn::SERIF_FONT_SPEC)
      @pdf.font_families.update(RDoc::Markup::ToPrawn::SANS_FONT_NAME  => RDoc::Markup::ToPrawn::SANS_FONT_SPEC)
      @pdf.font_families.update(RDoc::Markup::ToPrawn::MONO_FONT_NAME  => RDoc::Markup::ToPrawn::MONO_FONT_SPEC)
      @pdf.font_families.update(RDoc::Markup::ToPrawn::SERIF_CAPS_FONT_NAME => RDoc::Markup::ToPrawn::SERIF_CAPS_FONT_SPEC)
      @pdf.font("Libertine")
      @pdf.font_size RDoc::Markup::ToPrawn::BASE_FONT_SIZE

      debug "Evaluating toplevel files"
      @rdoc_files.each do |file|
        file.describe_in_pdf(@pdf)
      end

      debug "Evaluating classes and modules"
      @classes_and_modules.each do |classmod|
        document_classmod(classmod)
      end

      if RDoc::Markup::PrawnCrossReferencing.unresolved_pdf_references.empty?
        # No unresolved references. No need for the second run.
        break
      else
        if i.zero?
          # Undefined references found during the first run.
          # This is OK, try to resolve them
          # by generating the document a second time under
          # use of the now completely built-up reference
          # tree.
          puts "Undefined page references found."
          puts "Processing the document a second time to resolve them."

          # Empty the array of undefined references to
          # avoid confusion of references being not resolvable
          # even after the second run.
          RDoc::Markup::PrawnCrossReferencing.unresolved_pdf_references.clear
        else
          # Uh-oh, undefined references in the second run are bad.
          puts "There were undefined page references."
          puts "This may be a bug in Papyrus. File a ticket"
          puts "on our bugtracker and provide your sources and"
          puts "this list of undefined references:"
          puts RDoc::Markup::PrawnCrossReferencing.unresolved_pdf_references.join(", ")
        end
      end

    end

    debug "Rendering PDF"
    @pdf.render_file(@output_dir.join("Documentation.pdf").to_s)
  
    #To allow browsing the documentation with the RubyGems server, put an index.html
    #file there that points to the PDF file.
    debug("Creating index.html")
    unless @options.dry_run
      File.open(@output_dir + "index.html", "w") do |f|
        f.puts("<html>")
        f.puts("<!-- This file exists to allow browsing docs with the Gem server -->")
        f.puts("<head><title>#{doc_title}</title></head>")
        f.puts('<body><p>Documentation available as a <a href="Documentation.pdf">PDF file</a>.</p></body>')
        f.puts("</html>")
      end
    end
  end

  private

  #Invokes the class method ::debug.
  def debug(str = nil, &block)
    self.class.send(:debug, str, &block) #Private class method
  end

  # Outputs the documentation for the class or module +classmod+
  # and all its methods.
  def document_classmod(classmod)
    # Start a new class/module documentation always
    # on a new page and add the PDF destination for
    # this class/module to the list of known PDF
    # references.
    @pdf.start_new_page
    RDoc::Markup::PrawnCrossReferencing.add_pdf_reference(@pdf, classmod.anchor, @pdf.page_count)

    # "Class" or "Module" specifier above the heading
    @pdf.font_size(RDoc::Markup::ToPrawn::HEADING_SIZES[4])
    @pdf.font(RDoc::Markup::ToPrawn::SERIF_CAPS_FONT_NAME)
    if classmod.module?
      @pdf.text("Module")
    else
      @pdf.text("Class")
    end

    # The actual heading
    pdf_heading(1, classmod.full_name)

    # Overview
    classmod.describe_in_pdf(@pdf)

    # Constants
    unless classmod.constants.empty?
      pdf_heading(2, "Constants")
      table = [["Name", "Value", "Description"]] # Header

      # Add all constant’s docs to the table array
      classmod.each_constant do |const|
        document_constant(const, table)
      end

      # Actually draw the table
      @pdf.table(table, header: true) do |table|
        table.columns(0..2).width = @pdf.bounds.width / 3.0
        table.columns(0..1).style(font: RDoc::Markup::ToPrawn::MONO_FONT_NAME,
                                  size: RDoc::Markup::ToPrawn::MONO_FONT_SIZE)
        table.row(0).style(font: RDoc::Markup::ToPrawn::SANS_FONT_NAME,
                           font_style: :bold,
                           size: RDoc::Markup::ToPrawn::BASE_FONT_SIZE + 1,
                           align: :center,
                           background_color: "DDDDDD")
      end

      @pdf.text("\n") # Some space
    end

    # Methods
    meths = classmod.methods_by_type

    ["class", "instance"].each do |type| # Yes, RDoc uses strings here...
      [:public, :protected, :private].each do |visibility| # ...and here it doesn’t.
        unless meths[type][visibility].empty?
          pdf_heading(2, "#{visibility.to_s.capitalize} #{type.capitalize} methods")
          meths[type][visibility].sort_by(&:name).each{|m| document_method(m)}
        end
      end
    end
  end

  # Outputs the documentation for +method+ onto the PDF.
  def document_method(method)
    # @pdf.group do
      # Thick line at the top
      orig_width = @pdf.line_width
      @pdf.line_width = 4
      @pdf.stroke_horizontal_rule
      @pdf.line_width = orig_width

      @pdf.move_down(3) # Prevent method name and call sequence from touching the upper line

      # Register the PDF destination for this method
      RDoc::Markup::PrawnCrossReferencing.add_pdf_reference(@pdf, method.anchor, @pdf.page_count)

      # Method name (1/2 of the available width)
      @pdf.text_box(method.name,
                    at:       [0, @pdf.cursor],
                    width:    0.5 * @pdf.bounds.width,
                    height:   @pdf.height_of("\n"),
                    style:    :bold,
                    overflow: :shrink_to_fit)

      # Call sequence (1/2 of the available width)
      tb = Prawn::Text::Box.new(method.arglists,
                                document: @pdf,
                                at:       [0.5 * @pdf.bounds.width, @pdf.cursor],
                                width:    0.5 * @pdf.bounds.width,
                                align:    :right,
                                size:     RDoc::Markup::ToPrawn::BASE_FONT_SIZE - 1,
                                overflow: :shrink_to_fit)
      tb.render

      # Move the cursor below the call sequence box, plus a slight
      # distance to prevent the following line to touch the method
      # name, text.
      @pdf.move_down(tb.height + 3)

      # Draw the final line here rather than in the #indent block below
      # to ensure there’s no page break in the description header
      @pdf.stroke_line([METHOD_INDENTATION, @pdf.cursor], [@pdf.bounds.width, @pdf.cursor])
    # end

    # Actual method description
    @pdf.indent(METHOD_INDENTATION) do
      method.describe_in_pdf(@pdf)
    end

    # Some space so that it looks better
    @pdf.text("\n")
  end

  def document_constant(constant, table)
    # Constants are documented using tables, which do not support
    # all the fancy things the full-blown Prawn PDF formatter supports.
    # So, for constants, we need to use this more restrictive formatter.
    formatter = RDoc::Markup::ToPrawnTableCell.new(constant.parent,
                                                   @options.show_hash,
                                                   @options.show_pages,
                                                   @options.hyperlink_all)

    # Activate the RDoc formatter visitor on the constant’s comment
    prawn_markup = constant.comment.parse.accept(formatter)

    # Create the table cell
    desc_cell = Prawn::Table::Cell.make(@pdf, prawn_markup, inline_format: true)

    # Shorten the constant’s value if necessary
    if constant.value.chars.count <= CONSTANT_VALUE_CHAR_COUNT
      const_val = constant.value
    else
      const_val = "#{constant.value[0..CONSTANT_VALUE_CHAR_COUNT]}…"
    end

    # And finally, add the new row to the table.
    table << [constant.name, const_val, desc_cell]
  end

  # Creates a heading of +level+ by changing font family and size,
  # drawing the heading, and finally resetting family and size.
  def pdf_heading(level, str)
    # Set heading styles
    @pdf.font_size(RDoc::Markup::ToPrawn::HEADING_SIZES[level])
    @pdf.font(RDoc::Markup::ToPrawn::SANS_FONT_NAME)

    # Output the actual heading
    @pdf.text(str)

    # Reset to base styles
    @pdf.font(RDoc::Markup::ToPrawn::SERIF_FONT_NAME)
    @pdf.font_size(RDoc::Markup::ToPrawn::BASE_FONT_SIZE)

    # Some space after the heading for better look
    @pdf.text("\n")
  end

  #Generates a \hyperref with the given arguments. +show_page+ may be
  #one of three values:
  #[true]  Force page numbers in brackets following the hyperlink.
  #[false] Suppress page numbers in any case.
  #[nil]   Use the value of the commandline options --show-pages, which
  #        defaults to true if not given.
  #The generated hyperlink will be of the following form:
  #  \hyperref[<label>]{<name>} [p. page if requested]
  #def hyperref(label, name, show_page = nil)
  #  if show_page.nil? and @options.show_pages
  #    "\\hyperref[#{label}]{#{name}} \\nolinebreak[2][p.~\\pageref{#{label}}]"
  #  elsif show_page.nil? and !@options.show_pages
  #    "\\hyperref[#{label}]{#{name}}"
  #  elsif show_page
  #    "\\hyperref[#{label}]{#{name}} \\nolinebreak[2][p.~\\pageref{#{label}}]"
  #  else
  #    "\\hyperref[#{label}]{#{name}}"
  #  end
  #end
  #
  ##Generates a \pageref with the given +label+.
  #def pageref(label)
  #  "\\pageref{#{label}}"
  #end
  #
  ##Shortcut for calling #hyperref with <tt>meth.latex_label</tt>,
  ##<tt>meth.latexized(:pretty_name)</tt> and +show_page+.
  #def hyperref_method(meth, show_page = false)
  #  hyperref(meth.latex_label, meth.latexized(:pretty_name), show_page)
  #end
  #
  ##Takes either a string or a RDoc::CodeObject and returns
  ##a \hyperref to it if possible. Otherwise just returns +obj+.
  #def superclass_string(obj)
  #  if obj.kind_of?(String)
  #    RDoc::Markup::ToLaTeX.new.escape(obj) #HACK, \verb doesn't do the trick here
  #  else
  #    hyperref(obj.latex_label, obj.latexized(:full_name))
  #  end
  #end
  #
  ##Takes a list of RDoc::MethodAttr objects and turns them into a sorted
  ##LaTeX table with hyperlinks and page references.
  #def generate_method_table(methods)
  #  table_str = ""
  #  table_str << "\\small"
  #  table_str << "\\begin{longtable}{l|l|l|l|l|l}\n"
  #  #table_str << "\\begin{longtable}{p{0.1666\\textwidth}|p{0.1666\\textwidth}|p{0.1666\\textwidth}|p{0.1666\\textwidth}|p{0.1666\\textwidth}|p{0.1666\\textwidth}}\n"
  #  table_str << "  \\bfseries Name & \\bfseries p & \\bfseries Name & \\bfseries p & \\bfseries Name & \\bfseries p \\\\\n"
  #  table_str << "  \\hline\n"
  #  table_str << "\\endhead\n"
  #  methods.sort.each_slice(3) do |meth1, meth2, meth3|
  #    table_str << hyperref_method(meth1, false) << " & " << pageref(meth1.latex_label) << " &\n"
  #
  #    if meth2
  #      table_str << hyperref_method(meth2, false) << " & " << pageref(meth2.latex_label) << " &\n"
  #    else
  #      table_str << "&&\n"
  #    end
  #
  #    if meth3
  #      table_str << hyperref_method(meth3, false) << " & " << pageref(meth3.latex_label) << " \\\\\n"
  #    else
  #      table_str << "&\\\\\n"
  #    end
  #  end
  #  
  #  table_str << "\n\\end{longtable}\n"
  #  table_str << "\\normalsize\n"
  #  
  #  table_str
  #end
  #
  ##Generates the method overview table after the TOC for +methods+, which should
  ##be all methods of all classes and modules.
  #def generate_method_toc_table
  #  table_str = ""
  #  table_str << "\\small"
  #  table_str << "\\begin{longtable}{l|l}\n"
  #  table_str << "  \\bfseries Name & \\bfseries p \\\\\n"
  #  table_str << "  \\hline\n"
  #  table_str << "\\endhead\n"
  #  @methods.each do |meth|
  #    table_str << hyperref_method(meth, false) << " (" 
  #    table_str << hyperref(meth.parent.latex_label, meth.parent.latexized(:full_name), false) << ")"
  #    table_str << " & " << pageref(meth.latex_label) << " \\\\\n"
  #  end
  #  
  #  table_str << "\n\\end{longtable}\n"
  #  table_str << "\\normalsize\n"
  #  
  #  table_str
  #end
  
end

require_relative "papyrus/options" #Rest required in #initialize
