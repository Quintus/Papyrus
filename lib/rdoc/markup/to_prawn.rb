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

gem "rdoc"
require "pathname"
require "rdoc/markup/formatter"
require "rdoc/markup/inline"

class RDoc::Markup::ToPrawn < RDoc::Markup::Formatter
  include RDoc::Text

  FONT_DIR = Pathname.new(__FILE__).dirname.expand_path.parent.parent.parent + "data" + "fonts"

  # Name of the serif font to use.
  SERIF_FONT_NAME = "Libertine"

  # Prawn font specification for the serif font defined above.
  SERIF_FONT_SPEC = {:bold        => FONT_DIR.join("LinLibertine_RBah.ttf").to_s,
                     :italic      => FONT_DIR.join("LinLibertine_RIah.ttf").to_s,
                     :bold_italic => FONT_DIR.join("LinLibertine_RBIah.ttf").to_s,
                     :normal      => FONT_DIR.join("LinLibertine_Rah.ttf").to_s}

  # Name of the sans-serif font to use.
  SANS_FONT_NAME = "Biolinum"

  # Prawn font specification for the sans-serif font defined above.
  SANS_FONT_SPEC = { :bold        => FONT_DIR.join("LinBiolinum_RBah.ttf").to_s,
                     :italic      => FONT_DIR.join("LinBiolinum_RIah.ttf").to_s,
                     :normal      => FONT_DIR.join("LinBiolinum_Rah.ttf").to_s}

  # Name of the sans-serif font to use.
  MONO_FONT_NAME = "DejaVuSansMono"

  # Prawn font specification for the sans-serif font defined above.
  MONO_FONT_SPEC = { :bold        => FONT_DIR.join("DejaVuSansMono-Bold.ttf").to_s,
                     :italic      => FONT_DIR.join("DejaVuSansMono-Oblique.ttf").to_s,
                     :bold_italic => FONT_DIR.join("DejaVuSansMono-BoldOblique.ttf").to_s,
                     :normal      => FONT_DIR.join("DejaVuSansMono.ttf").to_s}

  #Default font size in pt.
  BASE_FONT_SIZE = 11

  #Font sizes used for headings. The 1st element
  #of this array specified the size for a level 1 heading,
  #the 2nd that one for a level 2 heading, etc. Note that
  #there’s no 0th heading, hence this is +nil+.
  HEADING_SIZES = [nil, # This way we dno’t need a hash
                   32,
                   22,
                   18,
                   16,
                   14,
                   12]

  #Number of PDF points to indent when a list ist encountered.
  LIST_PADDING = 20

  def initialize(pdf, heading_level = 0, inputencoding = "UTF-8", markup = nil)
    super(markup)

    @pdf               = pdf
    @heading_level     = heading_level
    @inputencoding     = inputencoding
    @lists_in_progress = []
    @list_numbers      = [] # Keeps track of the labels of number lists
    @paddings          = [] # Keeps track of the indentation

    # Copied from RDoc 3.12, adds link capabilities
    @markup.add_special(/((link:|https?:|mailto:|ftp:|irc:|www\.)\S+\w)/, :HYPERLINK)
    @markup.add_special(/rdoc-[a-z]+:\S+/, :RDOCLINK)
    @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\])/, :TIDYLINK)

    # Inline formatting directives as known by Prawn’s
    # inline formatter
    add_tag(:BOLD, "<b>", "</b>")
    add_tag(:TT,   "<tt>", "</tt>")
    add_tag(:EM,   "<it>", "</it>")

    # Basic PDF adjustments
    @pdf.font_families.update(SERIF_FONT_NAME => SERIF_FONT_SPEC)
    @pdf.font_families.update(SANS_FONT_NAME  => SANS_FONT_SPEC)
    @pdf.font_families.update(MONO_FONT_NAME  => MONO_FONT_SPEC)

    # Set default font and size
    @pdf.font("Libertine")
    @pdf.font_size BASE_FONT_SIZE
  end

  #First method called.
  def start_accepting
    # Nothing
  end

  #Last method called.
  def end_accepting
    # Nothing
  end

  def accept_paragraph(par)
    @pdf.text(par.text.chomp)
    #TODO: Inline formatting via #to_prawn
  end

  def accept_verbatim(ver)
    @pdf.save_font do
      @pdf.font MONO_FONT_NAME
      @pdf.text(ver.text.chomp, :size => BASE_FONT_SIZE - 1)
    end

    # Some distance to the following text
    @pdf.text("\n")
  end

  def accept_rule(rule)
    orig_width      = @pdf.line_width
    @pdf.line_width = rule.weight

    @pdf.stroke do
      @pdf.horizontal_rule
    end

    @pdf.line_width = orig_width
  end

  def accept_list_start(list)
    @lists_in_progress.push(list.type)
    @list_numbers << 0 if list.type == :NUMBER # Add a label number if we enter a NUMBER list
  end

  def accept_list_end(list)
    @list_numbers.pop if @lists_in_progress.pop == :NUMBER # Remove a number if we leave a NUMBER list
  end

  def accept_list_item_start(item)
    case @lists_in_progress.last
    when :BULLET then
      pdf_add_padding(LIST_PADDING)

      bullet_radius = @pdf.font.ascender / 5
      @pdf.fill do
        @pdf.circle([-bullet_radius - 5, @pdf.cursor - @pdf.font.ascender / 2], bullet_radius) # -5 ensures the bullet doesn’t touch the text
      end
    when :NUMBER then
      pdf_add_padding(LIST_PADDING)

      # Increment the last number of the number label
      @list_numbers[-1] += 1
      label = "#{@list_numbers.join('.')}."

      @pdf.draw_text(label, at: [-@pdf.width_of(label) - 5, @pdf.cursor - @pdf.font.ascender]) # -5 ensures the label doesn’t touch the text
    when :NOTE, :LABEL then
      label_width = @pdf.width_of(item.label, style: :bold) + 5 # +5 ensures the label doesn’t touch the text
      pdf_add_padding(label_width)

      @pdf.draw_text(item.label, at: [-label_width, @pdf.cursor - @pdf.font.ascender], style: :bold)
    #when :UALPHA then
    #when :LALPHA then
    else
      raise("Unknown list type #@list_in_progress!")
    end
  end

  def accept_list_item_end(item)
    pdf_subtract_last_padding
  end

  def accept_blank_line(line)
    @pdf.text("\n")
  end

  def accept_heading(head)
    @pdf.font_size HEADING_SIZES[head.level]
    @pdf.text(head.text)
    @pdf.font_size BASE_FONT_SIZE
  end

  def accept_raw(raw)
    @pdf.text(raw)
  end

  def handle_special_HYPERLINK
    # TODO
  end

  def handle_special_RDOCLINK
    # TODO
  end

  def handle_special_TIDYLINK
    # TODO
  end

  private

  def to_prawn(item)
    # TODO
  end

  # Indents all following flow commands by +padding+ PDF points.
  # Call #pdf_subtract_last_padding to undo the effect.
  def pdf_add_padding(padding)
    @paddings.push(padding)
    @pdf.bounds.add_left_padding(padding)
  end

  # Undoes a previous #pdf_add_padding.
  def pdf_subtract_last_padding
    @pdf.bounds.subtract_left_padding(@paddings.pop)
  end

end
