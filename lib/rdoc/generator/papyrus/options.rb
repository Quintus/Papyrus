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

#Mixin module that is used to extend the RDoc::Options
#instance given to RDoc::Generator::Papyrus.setup_options
#to arrange for some new options specific to the PDF
#generator.
module RDoc::Generator::Papyrus::Options
  
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

  # The paper size to use for the PDF. Defaults to "A4".
  # Can be set to anything Prawn::Document.new understands.
  def paper_size
    @paper_size ||= "A4"
  end

  # Setter fir the #paper_size value.
  def paper_size=(val)
    @paper_size = val
  end

end
