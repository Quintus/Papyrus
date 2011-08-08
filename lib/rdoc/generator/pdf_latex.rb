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

require "fileutils"
require "pathname"
require "erb"
require "open3"
gem "rdoc"
require "rdoc/rdoc"
require "rdoc/generator"

require_relative "pdf_latex/options"
require_relative "../markup/to_latex_crossref"
require_relative "latex_markup"

#This is the main class for the PDF generator for RDoc. It takes
#RDoc’s raw parsed data and transforms it into a single PDF file
#backed by pdfLaTeX. If you’re interested in how this process works,
#feel free to dig into this class’s code, but ensure you also have
#a look on the Markup::ToLaTeX class which does the heavy work of
#translating the markup tokens into LaTeX code. The below section
#also has a brief overview of how the generation process works.
#
#== The generation process
#
#1. During startup, RDoc calls the ::setup_options method that adds
#   some commandline options to RDoc (these are described in the
#   RDoc::Generator::PDF_LaTeX::Options module).
#2. RDoc parses the source files.
#3. RDoc calls the #generate method and passes it all encountered
#   files as an array of RDoc::TopLevel objects.
#4. The #generate method examines all encountered classes, modules
#   and methods and then starts to transform the raw data handed by
#   RDoc into LaTeX markup by means of the formatter class
#   RDoc::Markup::ToLaTeX_Crossref. The generated markup is written
#   into a temporary directory "tmp" below the output directory
#   RDoc has chosen or has been instructed to choose (via commandline),
#   generating one LaTeX file for each class and module plus one main
#   file "main.tex" that includes the other files as needed.
#5. pdfLaTeX is invoked on that final main file, generating "main.pdf"
#   in the temporary directory.
#6. The generated PDF file is copied over to the real output directory
#   and renamed to "Documentation.pdf".
#7. The temporary directory is recursively deleted.
#8. A file <tt>index.html</tt> is created inside the output directory
#   that contains a link to the PDF file. This allows navigating to the
#   documentation via RubyGems’ server (if somebody really set his
#   default generator to +pdf_latex+...).
class RDoc::Generator::PDF_LaTeX

  #Generic exception class for this library.
  class PDF_LaTeX_Error < StandardError
  end
  
  RDoc::RDoc.add_generator(self) #Tell RDoc about the new generator

  #Description displayed in RDoc’s help.
  DESCRIPTION = "PDF generator based on LaTeX"

  #The version number.
  VERSION = Pathname.new(__FILE__).dirname.parent.parent.parent.join("VERSION.txt").read.chomp.freeze
  
  #Directory where the LaTeX template files are stored.
  TEMPLATE_DIR = Pathname.new(__FILE__).dirname.expand_path.join("..", "..", "..", "data")
  #The main file’s ERB template.
  MAIN_TEMPLATE = ERB.new(TEMPLATE_DIR.join("main.tex.erb").read)
  #The ERB template for a single file.
  RDOC_FILE_TEMPLATE = ERB.new(TEMPLATE_DIR.join("rdoc_file.tex.erb").read)
  #The ERB template for a single class or module.
  MODULE_TEMPLATE = ERB.new(TEMPLATE_DIR.join("module.tex.erb").read)

  #Basename of the main resulting LaTeX file. The path is prepended
  #later as it’s a temporary directory.
  MAIN_FILE_BASENAME = "main.tex"
  #Basename of the resulting documentation file inside the
  #temporary directory.
  MAIN_FILE_RESULT_BASENAME = "main.pdf"

  #Creates a new instance of this class. Automatically called by RDoc.
  #There shouldn’t be any need for you to call this.
  #==Parameter
  #[options] RDoc passes the current RDoc::Options instance here.
  #==Return value
  #The newly created instance.
  def initialize(options)
    @options = options
    @output_dir = Pathname.pwd.expand_path + @options.op_dir
    #The following variable is used to generate unique filenames.
    #During processing the ERB templates, many files are created and
    #accidentally creating two files with the same name, effectively
    #overwriting the previous one, should be avoided. Hence, this
    #little number is prepended to generated filenames (except the
    #main file).
    @counter = 0
  end

  class << self

    #Called by RDoc during option processing. Adds commandline
    #switches specific to this generator.
    #==Parameter
    #[options] The yet unparsed RDoc::Options.
    def setup_options(options)
      debug("Teaching new options to RDoc")
      #Define the methods to get and set the options
      options.extend(RDoc::Generator::PDF_LaTeX::Options)

      #Define the options themselves
      options.option_parser.on("--[no-]show-pages", "(pdf_latex) Enables or disables page", "numbers following hyperlinks (default true).") do |val|
        debug("Found --show-pages: #{val}")
        options.show_pages = val
      end
      options.option_parser.on("--latex-command=VALUE", "(pdf_latex) Sets the command to run", "LaTeX (defaults to '#{RDoc::Generator::PDF_LaTeX::Options::DEFAULT_LATEX_COMMAND}')") do |val|
        debug("Found --latex-command: #{val}")
        options.latex_command = val
      end
      options.option_parser.on("--babel-lang=VALUE", "(pdf_latex) Sets the language option", "for babel (defaults to '#{RDoc::Generator::PDF_LaTeX::Options::DEFAULT_BABEL_LANG}')") do |val|
        debug("Found --babel-lang: #{val}")
        options.babel_lang = val
      end
    end

    private

    #If RDoc is invoked in debug mode, writes out +str+ using
    #+puts+ (prepending "[pdf_latex] ") and calls it’s block 
    #if one was given. If RDoc isn’t invoked in debug mode, 
    #does nothing.
    def debug(str = nil)
      if $DEBUG_RDOC
        puts "[pdf_latex] #{str}" if str
        yield if block_given?
      end
    end

  end

  #Called by RDoc after parsing has happened in order to generate the output.
  #This method takes the input of RDoc::TopLevel objects and tranforms
  #them by means of the RDoc::Markup::ToLaTeX_Crossref class into LaTeX
  #markup.
  def generate(top_levels)
    #Prepare all the data needed by all the templates
    doc_title = @options.title
    babel_lang = @options.babel_lang

    #Get the rdoc file list and move the "main page file" to the beginning.
    debug("Examining toplevel files")
    @rdoc_files = top_levels.select{|t| t.name =~ /\.rdoc$/i}
    debug("Found #{@rdoc_files.count} toplevels ending in .rdoc that will be processed")
    if @options.main_page #nil if not set, no main page
      main_index = @rdoc_files.index{|t| t.full_name == @options.main_page}
      @rdoc_files.unshift(@rdoc_files.slice!(main_index))
      debug("Main page is #{@rdoc_files.first.name}")
    end

    #Get the class, module and methods lists, sorted alphabetically by their full names
    debug("Sorting classes, modules and methods")
    @classes = RDoc::TopLevel.all_classes.sort_by{|klass| klass.full_name}
    @modules = RDoc::TopLevel.all_modules.sort_by{|mod| mod.full_name}
    @classes_and_modules = @classes.concat(@modules).sort_by{|mod| mod.full_name}
    @methods = @classes_and_modules.map{|mod| mod.method_list}.flatten.sort

    #Start the template filling process
    if @options.dry_run
      temp_dir = Pathname.pwd #No output directory in dryrun mode!
    else
      temp_dir = @output_dir + "tmp"
      temp_dir.mkpath
    end
    debug("Temporary directory is at '#{temp_dir.expand_path}'")
    Dir.chdir(temp_dir) do #We want LaTeX to output it’s files into our temporary directory
      #Evaluate the main page which includes all
      #subpages as necessary.
      debug("Evaluating main ERB temlpate")
      main_file = temp_dir + MAIN_FILE_BASENAME
      main_file.open("w"){|f| f.write(MAIN_TEMPLATE.result(binding))} unless @options.dry_run
      
      #Let LaTeX process the whole thing -- 3 times, to ensure
      #any kinds of references are correct.
      debug("Invoking LaTeX")
      3.times{latex(main_file)}
      
      #Oh, and don’t forget to copy the result file into our documentation
      #directory :-)
      debug("Copying resulting Documentation.pdf file")
      unless @options.dry_run
        FileUtils.rm(@output_dir + "Documentation.pdf") if File.file?(@output_dir + "Documentation.pdf")
        FileUtils.cp(temp_dir + MAIN_FILE_RESULT_BASENAME, @output_dir + "Documentation.pdf")
      end
      
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
    
    #Remove the temporary directory (this is *not* done if invoking LaTeX
    #failed, as the #latex method throws an exception. This is useful for
    #debugging the generated LaTeX files)
    debug("Removing temporary directory")
    temp_dir.rmtree unless @options.dry_run
  end

  private

  #Invokes the class method ::debug.
  def debug(str = nil, &block)
    self.class.send(:debug, str, &block) #Private class method
  end
  
  #Runs the LaTeX command with the specified +opts+, which will be quoted
  #by this method. Raises PDF_LaTeX_Error if the +pdflatex+ command (or
  #the command named on the commandline) wasn't found. This exception
  #is also raised if something goes wrong when calling LaTeX.
  def latex(*opts)
    cmd = "\"#{@options.latex_command}\""
    opts.each{|o| cmd << " \"#{o}\""}
    puts cmd if $DEBUG_RDOC
    unless @options.dry_run
      Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
        stdin.close #We’re always running noninteractive
        print stdout.read if $DEBUG_RDOC
        print stderr.read
        
        e = thread.value.exitstatus
        unless e == 0
          raise(PDF_LaTeX_Error, "Invoking #{@options.latex_command} failed with exitstatus #{e}!")
        end
      end
    end
  rescue Errno::ENOENT => e
    raise(PDF_LaTeX_Error, "LaTeX not found -- original error was: #{e.class} -- #{e.message}")
  end

  #Renders the given RDoc::ClassModule into a TeX file and returns the
  #relative path (relative to the temporary directory) to the file.
  #Suitable for use with \input in the main template.
  def render_module(mod)
    debug("Rendering module ERB template for #{mod.name}")
    filename = "#{@counter}_#{mod.name}.tex"; @counter += 1
    File.open(filename, "w"){|f| f.write(MODULE_TEMPLATE.result(binding))}
    filename
  end

  #Renders the given RDoc::TopLevel into a TeX file and returns the
  #relative path (relative to the temporary directory) to the file.
  #Suitable for use with \input in the main template.
  def render_rdoc_file(rdoc_file)
    debug("Rendering file ERB template for #{rdoc_file.name}")
    filename = "#{@counter}_#{rdoc_file.name}.tex"; @counter += 1
    File.open(filename, "w"){|f| f.write(RDOC_FILE_TEMPLATE.result(binding))}
    filename
  end

  #Generates a \hyperref with the given arguments. +show_page+ may be
  #one of three values:
  #[true]  Force page numbers in brackets following the hyperlink.
  #[false] Suppress page numbers in any case.
  #[nil]   Use the value of the commandline options --show-pages, which
  #        defaults to true if not given.
  #The generated hyperlink will be of the following form:
  #  \hyperref[<label>]{<name>} [p. page if requested]
  def hyperref(label, name, show_page = nil)
    if show_page.nil? and @options.show_pages
      "\\hyperref[#{label}]{#{name}} \\nolinebreak[2][p.~\\pageref{#{label}}]"
    elsif show_page.nil? and !@options.show_pages
      "\\hyperref[#{label}]{#{name}}"
    elsif show_page
      "\\hyperref[#{label}]{#{name}} \\nolinebreak[2][p.~\\pageref{#{label}}]"
    else
      "\\hyperref[#{label}]{#{name}}"
    end
  end

  #Generates a \pageref with the given +label+.
  def pageref(label)
    "\\pageref{#{label}}"
  end
  
  #Shortcut for calling #hyperref with <tt>meth.latex_label</tt>,
  #<tt>meth.latexized(:pretty_name)</tt> and +show_page+.
  def hyperref_method(meth, show_page = false)
    hyperref(meth.latex_label, meth.latexized(:pretty_name), show_page)
  end

  #Takes either a string or a RDoc::CodeObject and returns
  #a \hyperref to it if possible. Otherwise just returns +obj+.
  def superclass_string(obj)
    if obj.kind_of?(String)
      obj
    else
      hyperref(obj.latex_label, obj.latexized(:full_name))
    end
  end

  #Takes a list of RDoc::MethodAttr objects and turns them into a sorted
  #LaTeX table with hyperlinks and page references.
  def generate_method_table(methods)
    table_str = ""
    table_str << "\\small"
    table_str << "\\begin{longtable}{l|l|l|l|l|l}\n"
    table_str << "  \\bfseries Name & \\bfseries p & \\bfseries Name & \\bfseries p & \\bfseries Name & \\bfseries p \\\\\n"
    table_str << "  \\hline\n"
    table_str << "\\endhead\n"
    methods.sort.each_slice(3) do |meth1, meth2, meth3|
      table_str << hyperref_method(meth1, false) << " & " << pageref(meth1.latex_label) << " &\n"

      if meth2
        table_str << hyperref_method(meth2, false) << " & " << pageref(meth2.latex_label) << " &\n"
      else
        table_str << "&&\n"
      end

      if meth3
        table_str << hyperref_method(meth3, false) << " & " << pageref(meth3.latex_label) << " \\\\\n"
      else
        table_str << "&\\\\\n"
      end
    end
    
    table_str << "\n\\end{longtable}\n"
    table_str << "\\normalsize\n"
    
    table_str
  end

  #Generates the method overview table after the TOC for +methods+, which should
  #be all methods of all classes and modules.
  def generate_method_toc_table
    table_str = ""
    table_str << "\\small"
    table_str << "\\begin{longtable}{l|l}\n"
    table_str << "  \\bfseries Name & \\bfseries p \\\\\n"
    table_str << "  \\hline\n"
    table_str << "\\endhead\n"
    @methods.each do |meth|
      table_str << hyperref_method(meth, false) << " (" 
      table_str << hyperref(meth.parent.latex_label, meth.parent.latexized(:full_name), false) << ")"
      table_str << " & " << pageref(meth.latex_label) << " \\\\\n"
    end
    
    table_str << "\n\\end{longtable}\n"
    table_str << "\\normalsize\n"
    
    table_str
  end
  
end
