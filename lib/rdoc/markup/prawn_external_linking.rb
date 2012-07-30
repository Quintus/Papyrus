# -*- coding: utf-8 -*-
#
# This file is part of Papyrus.
#
# Papyrus is a RDoc plugin for generating PDF files.
# Copyright © 2012 Pegasus Alpha
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

# Mixin module for RDoc formatters. It adds specials for
# recognising links to external web pages and converts them
# to Prawn’s inline markup tags (namely the +link+ tag).
# Note that in contrast to PrawnCrossReferencing you are
# not required to implement specific methods in your
# formatter for this to work. Just call +super+ in your
# +initialize+ method and you should be done.
module RDoc::Markup::PrawnExternalLinking

  # Colour used for external links. HTML colour code.
  EXTERNAL_LINK_COLOR = "FF0000"

  # Adds the RDoc specials needed for hyperlinks to
  # your formatter. Be sure to call +super+ in the
  # including class’ +initialize+ method (this method
  # then calls +super+ itself again, passing all arguments
  # on to the next ancestor).
  def initialize(*)
    super

    # Copied from RDoc 3.12, adds link capabilities
    @markup.add_special(/((link:|https?:|mailto:|ftp:|irc:|www\.)\S+\w)/, :HYPERLINK)
    @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\])/, :TIDYLINK)
  end

  # Handles the HYPERLINK special and turns it into a clickable URL.
  def handle_special_HYPERLINK(special)
    make_url(special.text)
  end

  # Method copied from RDoc project and slightly modified.
  #
  # Handles hyperlinks of form {text}[url] and text[url].
  def handle_special_TIDYLINK(special)
    return special.text unless special.text =~ /\{(.*?)\}\[(.*?)\]/ or special.text =~ /(\S+)\[(.*?)\]/
    make_url($2, $1)
  end

  private

  # Creates a clickable URL. If +text+ is given, uses that as the
  # label. Otherwise, just uses the link text as label and displays
  # it in a monospaced font.
  def make_url(url, text = nil)
    url = "http://#{url}" unless url =~ /^.*?:/
    if text
      "<color rgb=\"#{EXTERNAL_LINK_COLOR}\"><link href=\"#{url}\">#{text}</link></color>"
    else
      "<color rgb=\"#{EXTERNAL_LINK_COLOR}\"><font name=\"#{RDoc::Markup::ToPrawn::MONO_FONT_NAME}\" size=\"#{RDoc::Markup::ToPrawn::MONO_FONT_SIZE - 1}\"><link href=\"#{url}\">#{url}</link></font></color>"
    end
  end

end
