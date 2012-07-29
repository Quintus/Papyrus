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

require_relative "to_prawn"

# RDoc formatter that converts RDoc markup into Prawn inline-markup
# that is suitable for use in table cells. Note that Prawn currently
# doesn’t support fancy formatting inside tables, so trying to do
# things like labelled lists inside places where Papyrus uses
# a Prawn table will most likely fail. Although this formatter
# accepts anything it is supposed to, feeding it with unsupported
# markup (like the definition lists) will print a warning on
# the standard error stream. The markup will be swallowed and
# ignored.
class RDoc::Markup::ToPrawnTableCell < RDoc::Markup::Formatter
  include RDoc::Text
  include RDoc::Markup::PrawnCrossReferencing

  # Creates a new instance of this formatter. The parameters
  # are the same as for ToPrawn::new.
  def initialize(context, heading_level = 0, show_hash = false, show_pages = true, hyperlink_all = false, markup = nil)
    @context       = context
    @show_hash     = show_hash
    @show_pages    = show_pages
    @hyperlink_all = hyperlink_all

    # Call super after this initialisation. This is necessary,
    # because the PrawnCrossReferencing module uses some methods
    # from us that would otherwise return nil.
    super(markup)

    # Inline formatting directives as known by Prawn’s
    # inline formatter
    add_tag(:BOLD, "<b>", "</b>")
    add_tag(:TT,   "<font name=\"#{RDoc::Markup::ToPrawn::MONO_FONT_NAME}\" size=\"#{RDoc::Markup::ToPrawn::MONO_FONT_SIZE}\">", "</font>")
    add_tag(:EM,   "<i>", "</i>")
  end

  # Interface for PrawnCrossReference. Whether to
  # show hashes before cross referenced methods.
  def show_hash?
    @show_hash
  end

  # Interface for PrawnCrossReference. Whether to
  # show page numbers behind cross references.
  def show_pages?
    @show_pages
  end

  # Interface for PrawnCrossReference. Whether to
  # try hyperlinking everything.
  def hyperlink_all?
    @hyperlink_all
  end

  # Interface for PrawnCrossReference. Returns the
  # RDoc::Context this formatter shall resolve
  # cross-references relative to.
  def context
    @context
  end

  # Formatter visitor: First method called.
  def start_accepting
    @result = ""
  end

  # Formatter visitor: Last method called.
  # Return value of +description+.
  def end_accepting
    @result
  end

  # Formatter visitor: Accept a normal paragraph with inline markup.
  def accept_paragraph(par)
    @result << to_prawn_table_cell(par.text.chomp)
  end

  # Formatter visitor: Accept a block of verbatim text.
  def accept_verbatim(ver)
    warn("Unsupported formatting directive `verbatim' in table cell. Ignoring.")
  end

  # Formatter visitor: Accept a rule.
  def accept_rule(rule)
    warn("Unsupported formatting directive `rule' in table cell. Ignoring.")
  end

  # Formatter visitor: Accept a list start.
  def accept_list_start(list)
    warn("Unsupported formatting directive `list-start' in table cell. Ignoring.")
  end

  # Formatter visitor: Accept a list end.
  def accept_list_end(list)
    warn("Unsupported formatting directive `list-end' in table cell. Ignoring.")
  end

  # Formatter visitor: Accept a list item start.
  def accept_list_item_start(item)
    warn("Unsupported formatting directive `list-item-start' in table cell. Ignoring.")
  end

  # Formatter visitor: Accept a list item end.
  def accept_list_item_end(list)
    warn("Unsupported formatting directive `list-item-end' in table cell. Ignoring.")
  end

  # Formatter visitor: Accept a blank line.
  def accept_blank_line(line)
    @result << "\n\n"
  end

  # Formatter visitor: Accept a heading.
  def accept_heading(head)
    warn("Unsupported formatting directive `heading' in table cell. Ignoring.")
  end

  # Formatter visitor: Accept raw text.
  def accept_raw(raw)
    @result << raw
  end

  # Tokenises the inline markup in +item+ and calls the
  # apropriate inline handler methods on this formatter.
  #
  # Returns the prawn inline-markup for +item+.
  def to_prawn_table_cell(item)
    convert_flow(@am.flow(item))
  end

end
