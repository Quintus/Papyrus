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
require "prawn/measurement_extensions"
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

  # Maximum page number the column width of the method
  # overview table is calculated for.
  METHOD_OVERVIEW_MAX_PAGENUM = 9999

  # Margin for the top, left, and right edges.
  TOPLEFTRIGHT_MARGIN = 2.cm

  # Margin for the bottom edge (should be big enough
  # to hold the footer).
  BOTTOM_MARGIN = 2 * TOPLEFTRIGHT_MARGIN

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

      options.option_parser.on("--paper-size SIZE",
                               "Set the paper size. Anything Prawn::Document.new",
                               "can understand. Defaults to `A4'."){|val| optons.paper_size = val}

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
    
    @options    = options
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
    @classes_and_modules = @classes.concat(@modules).sort_by(&:full_name)
    @methods = @classes_and_modules.sort_by(&:full_name).map{|mod| mod.enum_for(:each_method).sort_by{|m|m.pretty_name.tr(":#", "ab")}}.flatten
    # Thanks to Hanmac for the above sorting code

    @pdf = nil
    2.times do |i| # Two times for resolving all references
      puts "Constructing PDF..."
      @pdf = Prawn::Document.new(page_size: @options.paper_size, margin: TOPLEFTRIGHT_MARGIN, bottom_margin: BOTTOM_MARGIN)

      # Register our font families
      @pdf.font_families.update(RDoc::Markup::ToPrawn::SERIF_FONT_NAME => RDoc::Markup::ToPrawn::SERIF_FONT_SPEC)
      @pdf.font_families.update(RDoc::Markup::ToPrawn::SANS_FONT_NAME  => RDoc::Markup::ToPrawn::SANS_FONT_SPEC)
      @pdf.font_families.update(RDoc::Markup::ToPrawn::MONO_FONT_NAME  => RDoc::Markup::ToPrawn::MONO_FONT_SPEC)
      @pdf.font_families.update(RDoc::Markup::ToPrawn::SERIF_CAPS_FONT_NAME => RDoc::Markup::ToPrawn::SERIF_CAPS_FONT_SPEC)
      @pdf.font("Libertine")
      @pdf.font_size RDoc::Markup::ToPrawn::BASE_FONT_SIZE

      debug "Evaluating toplevel files"
      @rdoc_files.each do |file|
        # Register the PDF destination for this file
        RDoc::Markup::PrawnCrossReferencing.add_pdf_reference(@pdf, file.anchor, @pdf.page_count)

        # Actually format the file’s documentation
        file.describe_in_pdf(@pdf)

        # Whatever comes next shall start on a new page
        @pdf.start_new_page
      end

      debug "Creating method overview"
      table = [["Method name", "p."]]
      formatter = table_formatter(nil) # We don’t use the resolver
      @methods.each{|m| table << [m.full_name, Prawn::Table::Cell.make(@pdf, formatter.prawn_page_link(m.anchor, formatter.determine_page!(m)), inline_format: true)]}
      @pdf.table(table, header: true) do |tbl|
        # Column width (to_s as we want to measure that width of the printed number)
        tbl.column(0).width = @pdf.bounds.width - @pdf.width_of(METHOD_OVERVIEW_MAX_PAGENUM.to_s)
        tbl.column(1).width = @pdf.width_of(METHOD_OVERVIEW_MAX_PAGENUM.to_s)

        # Border only for the first row
        tbl.row(0).borders = [:bottom]
        tbl.rows(1..Float::INFINITY).borders = []

        # Special cell styles
        tbl.column(0).style(font: RDoc::Markup::ToPrawn::MONO_FONT_NAME,
                            size: RDoc::Markup::ToPrawn::MONO_FONT_SIZE)
        tbl.row(0).style(font: RDoc::Markup::ToPrawn::SANS_FONT_NAME,
                         font_style: :bold,
                         size: RDoc::Markup::ToPrawn::BASE_FONT_SIZE + 1)
        tbl.row(0).column(0).style(align: :left)
        tbl.row(0).column(1).style(align: :right)
      end
      @pdf.start_new_page

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
          puts <<-EOF
There were undefined page references.
If you are sure you have included all relevant files in the
list of files passed to RDoc, this may be a bug in Papyrus.
File a ticket on our bugtracker and provide your sources and
this list of undefined references:
          EOF
          puts RDoc::Markup::PrawnCrossReferencing.unresolved_pdf_references.join(", ")
        end
      end

    end

    debug "Numbering pages"
    @pdf.number_pages("<page>", at: [@pdf.bounds.width - @pdf.width_of("99999"), -(0.5 * BOTTOM_MARGIN)], align: :right) # More than 99999 pages are quite unlikely

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
    # Register the PDF destination for this class/module
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

    # Mixins
    unless classmod.includes.empty?
      pdf_heading(2, "Includes")

      classmod.each_include do |inc|
        document_include(inc)
      end

      @pdf.text("\n") # Looks better
    end

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

    # Attributes
    unless classmod.attributes.empty?
      pdf_heading(2, "Attributes")
      classmod.attributes.sort_by(&:name).each do |attr|
        document_attribute(attr)
      end

      @pdf.text("\n") # Looks better
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

    # Start a new class/module documentation always
    # on a new page.
    @pdf.start_new_page
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
      if target = method.is_alias_for # Single = intended
        @pdf.text("<i>Alias for #{table_formatter(method.parent).prawn_anchor_link(method.anchor, method.pretty_name)}</i>", inline_format: true)
      else
        method.describe_in_pdf(@pdf)
        unless method.aliases.empty?
          aliases = method.aliases.sort_by(&:name).map{|al| table_formatter(method.parent).prawn_anchor_link(al.anchor, al.pretty_name)}
          @pdf.text("\n")
          @pdf.text("<i>Also aliased as: #{aliases.join(', ')}</i>", inline_format: true)
        end
      end
    end

    # Some space so that it looks better
    @pdf.text("\n")
  end

  # Adds a table row for +constant+ to +table+.
  def document_constant(constant, table)
    # Register the PDF destination for this constant
    # FIXME: Always places the destination at the classmod’s first page!
    #        If the constant list is longer than one page, this is
    #        confusing. Could probably be solved by subclassing Table::Cell
    #        and hooking into Prawn’s table layout mechanism.
    RDoc::Markup::PrawnCrossReferencing.add_pdf_reference(@pdf, constant.anchor, @pdf.page_count)

    # Invoke the Prawn table formatter visitor on the constant’s comment
    prawn_markup = constant.comment.parse.accept(table_formatter(constant.parent, 3))

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

  # Outputs the documentation for +inc+ onto the PDF.
  def document_include(inc)
    # Resolve the reference to the full module name.
    @pdf.text(table_formatter(inc.parent).make_crossref(inc.full_name), inline_format: true)
  end

  # Outputs the documentation for +attr+ onto the PDF.
  def document_attribute(attr)
    # Register the PDF destination for this attribute
    RDoc::Markup::PrawnCrossReferencing.add_pdf_reference(@pdf, attr.anchor, @pdf.page_count)

    @pdf.text("<font name=\"#{RDoc::Markup::ToPrawn::SANS_FONT_NAME}\">#{attr.name}#{Prawn::Text::NBSP}<sup>[#{attr.rw}]</sup></font>", inline_format: true)
    @pdf.indent(METHOD_INDENTATION) do
      attr.describe_in_pdf(@pdf)
    end
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

  # At some places we use Prawn tables, which only support
  # a small subset of what the full-blown flow text formatter
  # supports. For these cases, we need an extra formatter,
  # which is returned by this method. +context+ is an
  # RDoc::Context to resolve references relative to,
  # +heading_level+ is used for relatively calculating
  # heading sizes.
  def table_formatter(context, heading_level = 0)
    RDoc::Markup::ToPrawnTableCell.new(context,
                                       heading_level,
                                       @options.show_hash,
                                       @options.show_pages,
                                       @options.hyperlink_all)
  end

end

require_relative "papyrus/options" #Rest required in #initialize
