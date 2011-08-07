# -*- coding: utf-8 -*-

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

#This is the main class for the PDF generator for RDoc. It examines all
#the information it gets provided from RDoc in the generate method.
class RDoc::Generator::PDF_LaTeX

  #Generic exception class for this library.
  class PDF_LaTeX_Error < StandardError
  end
  
  RDoc::RDoc.add_generator(self) #Tell RDoc about the new generator

  #Description displayed in RDoc’s help.
  DESCRIPTION = "PDF generator based on LaTeX"
  
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
  
  def initialize(options)
    @options = options
    @base_dir = Pathname.pwd.expand_path
    @output_dir = @base_dir + @options.op_dir
    #The following variable is used to generate unique filenames.
    #During processing the ERB templates, many files are created and
    #accidentally creating two files with the same name, effectively
    #overwriting the previous one, should be avoided. Hence, this
    #little number is prepended to generated filenames (except the
    #main file).
    @counter = 0
  end

  #Called by RDoc during option processing. Adds commandline
  #switches specific to this generator.
  def self.setup_options(options)
    #Define the methods to get and set the options
    options.extend(RDoc::Generator::PDF_LaTeX::Options)

    #Define the options themselves
    options.option_parser.on("--[no-]show-pages", "(pdf_latex) Enables or disables page", "numbers following hyperlinks (default true).") do |val|
      options.show_pages = val
    end
    options.option_parser.on("--latex-command=VALUE", "(pdf_latex) Sets the command to run", "LaTeX (defaults to '#{RDoc::Generator::PDF_LaTeX::Options::DEFAULT_LATEX_COMMAND}')") do |val|
      options.latex_command = val
    end
    options.option_parser.on("--babel-lang=VALUE", "(pdf_latex) Sets the language option", "for babel (defaults to '#{RDoc::Generator::PDF_LaTeX::Options::DEFAULT_BABEL_LANG}')") do |val|
      options.babel_lang = val
    end
  end
  
  def generate(top_levels)
    #Prepare all the data needed by all the templates
    doc_title = @options.title
    babel_lang = @options.babel_lang

    #Get the rdoc file list and move the "main page file" to the beginning.
    rdoc_files = top_levels.select{|t| t.name =~ /\.rdoc$/i}
    if @options.main_page #nil if not set, no main page
      main_index = rdoc_files.index{|t| t.full_name == @options.main_page}
      rdoc_files.unshift(rdoc_files.slice!(main_index))
    end

    #Get the class and module lists, sorted alphabetically by their full names
    classes = RDoc::TopLevel.all_classes.sort_by{|klass| klass.full_name}
    modules = RDoc::TopLevel.all_modules.sort_by{|mod| mod.full_name}
    #Get the method list and sort it like this:
    #1. Class/module methods, alphabetically
    #2. Instance methods, alphabetically
    classes_and_modules = classes.concat(modules).sort_by{|mod| mod.full_name}
    methods = classes_and_modules.map{|mod| mod.method_list}.flatten.sort do |meth1, meth2|
      if meth1.type == "class" and meth2.type == "class" #RDoc uses strings, not symbols?
        meth1.name <=> meth2.name
      elsif meth1.type == "class" and meth2.type == "instance"
        -1
      elsif meth1.type == "instance" and meth2.type == "class"
        1
      elsif meth1.type == "instance" and meth2.type == "instance"
        meth1.name <=> meth2.name
      else #Can’t be
        raise(RuntimeError, "You proved God’s existence!")
      end
    end

    #Start the template filling process
    temp_dir = @output_dir + "tmp"
    temp_dir.mkpath
    Dir.chdir(temp_dir) do #We want LaTeX to output it’s files into our temporary directory
      #Evaluate the main page which includes all
      #subpages as necessary.
      main_file = temp_dir + MAIN_FILE_BASENAME
      main_file.open("w"){|f| f.write(MAIN_TEMPLATE.result(binding))}
      
      #Let LaTeX process the whole thing -- 3 times, to ensure
      #any kinds of references are correct.
      3.times{latex(main_file)}
      
      #Oh, and don’t forget to copy the result file into our documentation
      #directory :-)
      FileUtils.cp(temp_dir + MAIN_FILE_RESULT_BASENAME, @output_dir + "Documentation.pdf")
    end
    
    #Remove the temporary directory (this is *not* done if invoking LaTeX
    #failed, as the #latex method throws an exception. This is useful for
    #debugging the generated LaTeX files)
    temp_dir.rmtree
  end

  private
  
  #Runs the LaTeX command with the specified +opts+, which will be quoted
  #by this method. Raises PDF_LaTeX_Error if the +pdflatex+ command (or
  #the command named on the commandline) wasn't found. This exception
  #is also raised if something goes wrong when calling LaTeX.
  def latex(*opts)
    cmd = "\"#{@options.latex_command}\""
    opts.each{|o| cmd << " \"#{o}\""}
    puts cmd if $DEBUG_RDOC
    Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
      stdin.close #We’re always running noninteractive
      print stdout.read if $DEBUG_RDOC
      print stderr.read
      
      e = thread.value.exitstatus
      unless e == 0
        raise(PDF_LaTeX_Error, "Invoking #{@latex_command} failed with exitstatus #{e}!")
      end
    end
  rescue Errno::ENOENT => e
    raise(PDF_LaTeX_Error, "LaTeX not found -- original error was: #{e.class} -- #{e.message}")
  end

  #Renders the given RDoc::ClassModule into a TeX file and returns the
  #relative path (relative to the temporary directory) to the file.
  #Suitable for use with \input in the main template.
  def render_module(mod)
    filename = "#{@counter}_#{mod.name}.tex"; @counter += 1
    File.open(filename, "w"){|f| f.write(MODULE_TEMPLATE.result(binding))}
    filename
  end

  #Renders the given RDoc::TopLevel into a TeX file and returns the
  #relative path (relative to the temporary directory) to the file.
  #Suitable for use with \input in the main template.
  def render_rdoc_file(rdoc_file)
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
  
end
