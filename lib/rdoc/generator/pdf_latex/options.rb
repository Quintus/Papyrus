# -*- coding: utf-8 -*-

module RDoc

  module Generator

    class PDF_LaTeX
      
      #Mixin module that is used to extend the RDoc::Options
      #instance given to RDoc::Generator::PDF_LaTeX.setup_options
      #to arrange for some new options specific to the PDF
      #generator.
      module Options

        #The default command invoked when running LaTeX.
        #Overriden by the <tt>--latex-command</tt> commandline
        #option.
        DEFAULT_LATEX_COMMAND = "pdflatex"

        #The default language option passed to the LaTeX +babel+
        #package.
        DEFAULT_BABEL_LANG = "english"
        
        #Wheather or not to show page numbers in square
        #brackets behind any cross-reference made. Useful
        #if one is sure that the documentation won’t be printed
        #and therefore doesn’t need the annoying page numbers.
        def show_pages
          @show_pages ||= true
        end

        #Setter for #show_pages value.
        def show_pages=(val)
          @show_pages = !!val
        end

        #The command to run LaTeX, defaults to the
        #value of DEFAULT_LATEX_COMMAND, which in turn
        #is "pdflatex".
        def latex_command
          @latex_command ||= DEFAULT_LATEX_COMMAND
        end

        #Setter for the #latex_command value.
        def latex_command=(val)
          @latex_command = val
        end

        #The language option to be passed to the +babel+ package.
        #Note that changing this value doesn’t translate hard-coded
        #strings like "Public class methods" yet.
        def babel_lang
          @babel_lang ||= DEFAULT_BABEL_LANG
        end

        #Setter for the #babel_lang value.
        def babel_lang=(val)
          @babel_lang = val
        end
        
      end

    end

  end

end
