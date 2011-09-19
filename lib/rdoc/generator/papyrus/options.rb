# -*- coding: utf-8 -*-
#
# This file is part of Papyrus.
# 
# Papyrus is a RDoc plugin for generating PDF files.
# Copyright © 2011  Pegasus Alpha
# 
# Papyrus is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# Papyrus is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Papyrus; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#
module RDoc

  module Generator

    class Papyrus
      
      #Mixin module that is used to extend the RDoc::Options
      #instance given to RDoc::Generator::Papyrus.setup_options
      #to arrange for some new options specific to the PDF
      #generator.
      module Options

        #The default command invoked when running LaTeX.
        #Overriden by the <tt>--latex-command</tt> commandline
        #option.
        DEFAULT_LATEX_COMMAND = "xelatex"

        #The default language option passed to the LaTeX +babel+
        #package.
        DEFAULT_BABEL_LANG = "english"
        
        #The default encoding for the <tt>--inputencoding</tt> option.
        DEFAULT_INPUT_ENCODING = "UTF-8"

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

        #The encoding assumed for *all* the input files. Defautls to "UTF-8".
        def inputencoding
          @inputencoding ||= DEFAULT_INPUT_ENCODING
        end

        #Setter for the #inputencoding value.
        def inputencoding=(val)
          @inputencoding = val
        end

        #Wheather or not to include the methods' sourcecode in the
        #PDF file in form of an appendix. I highly recommand you to
        #not do this as the bigger a project grows, the thicker the
        #resulting PDF will be. Furthermore printing the PDF would
        #resulting in printing the sourcecode which is nonsense as
        #you're better off directly looking into the sourcecode files
        #with your favourite editor where you can edit them.
        def append_source
          @append_source ||= false
        end
        
        #Stter for the #append_source value.
        def append_source=(val)
          @append_source = val
        end

      end

    end

  end

end
