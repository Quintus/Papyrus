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

  #Font size for all the monospaced stuff. Teletype fonts
  #are usually larger, hence to ensure the overall text
  #harmony, the teletyped part should be drawn smaller.
  MONO_FONT_SIZE = BASE_FONT_SIZE - 1

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

  # Colour used for internal links. HTML colour code.
  INTERNAL_LINK_COLOR = "0000FF"

  # Colour used for external links. HTML colour code.
  EXTERNAL_LINK_COLOR = "FF0000"

  def initialize(pdf, heading_level = 0, inputencoding = "UTF-8", markup = nil)
    super(markup)

    @pdf               = pdf
    @heading_level     = heading_level
    @inputencoding     = inputencoding
    @lists_in_progress = []
    @list_numbers      = [] # Keeps track of the labels of number lists
    @paddings          = [] # Keeps track of the indentation
    @note_positions    = [] # Keeps track of page and position in note lists

    # Copied from RDoc 3.12, adds link capabilities
    @markup.add_special(/((link:|https?:|mailto:|ftp:|irc:|www\.)\S+\w)/, :HYPERLINK)
    @markup.add_special(/rdoc-[a-z]+:\S+/, :RDOCLINK)
    @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\])/, :TIDYLINK)

    # Inline formatting directives as known by Prawn’s
    # inline formatter
    add_tag(:BOLD, "<b>", "</b>")
    add_tag(:TT,   "<font name=\"#{MONO_FONT_NAME}\" size=\"#{MONO_FONT_SIZE}\">", "</font>")
    add_tag(:EM,   "<i>", "</i>")

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
    @pdf.text(to_prawn(par.text.chomp), inline_format: true)
  end

  def accept_verbatim(ver)
    @pdf.save_font do
      @pdf.font MONO_FONT_NAME
      @pdf.text(ver.text.chomp, :size => MONO_FONT_SIZE)
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
    if list.type == :LABEL || list.type == :NOTE
      pdf_add_padding(LIST_PADDING, LIST_PADDING) # Labelled lists get both margins
    else
      pdf_add_padding(LIST_PADDING) # Other lists just a left one.
    end

    @list_numbers << 0 if list.type == :NUMBER # Add a label number if we enter a NUMBER list
  end

  def accept_list_end(list)
    pdf_subtract_last_padding
    @list_numbers.pop if @lists_in_progress.pop == :NUMBER # Remove a number if we leave a NUMBER list
  end

  def accept_list_item_start(item)
    case @lists_in_progress.last
    when :BULLET then
      bullet_radius = @pdf.font.ascender / 5
      @pdf.fill do
        @pdf.circle([-bullet_radius - 5, @pdf.cursor - @pdf.font.ascender / 2], bullet_radius) # -5 ensures the bullet doesn’t touch the text
      end
    when :NUMBER then
      # Increment the last number of the number label
      @list_numbers[-1] += 1
      label = "#{@list_numbers.join('.')}."

      @pdf.draw_text(label, at: [-@pdf.width_of(label) - 5, @pdf.cursor - @pdf.font.ascender]) # -5 ensures the label doesn’t touch the text
    when :NOTE, :LABEL then
      # Determine the height the label would render to
      label_tokens = Prawn::Text::Formatted::Parser.to_array("<b><#{to_prawn(item.label)}</b>") # Labels are always bold, regardless of what the user sets
      tb = Prawn::Text::Formatted::Box.new(label_tokens, document: @pdf, width: @pdf.bounds.width, at: [0, @pdf.cursor])
      tb.render(dry_run: true)
      height = tb.height

      # Fill the area the label is going to occupy with a light
      # grey, then draw a border for the left, upper, and right
      # edges of the area. The bottom border is the same as
      # the top border of the content box, which is drawn later
      # on.
      @pdf.fill_color = "DDDDDD"
      @pdf.fill_rectangle([0, @pdf.cursor], @pdf.bounds.width, height)
      @pdf.stroke_line([0, @pdf.cursor - height],[0, @pdf.cursor])
      @pdf.stroke_line([0, @pdf.cursor], [@pdf.bounds.width, @pdf.cursor])
      @pdf.stroke_line([@pdf.bounds.width, @pdf.cursor], [@pdf.bounds.width, @pdf.cursor - height])
      @pdf.fill_color = "000000" # Reset colour

      # Now draw the actual label on the prepared area.
      tb.render

      # Continue below the text box
      @pdf.move_down(height)

      # Remember current position (needed for drawing the side borders later on)
      @note_positions.push([@pdf.page_count, @pdf.cursor])
      # Draw the top border
      @pdf.stroke{@pdf.horizontal_rule}

      # Add some extra spacing to prevent the text from touching
      # the border
      pdf_add_padding(5, 5)
    #when :UALPHA then
    #when :LALPHA then
    else
      raise("Unknown list type #{@lists_in_progress.last}!")
    end
  end

  def accept_list_item_end(item)
    if @lists_in_progress.last == :NOTE || @lists_in_progress.last == :LABEL
      # Remove the extra spacing that prevents the text to
      # not touch the border
      pdf_subtract_last_padding

      # Draw the bottom border
      @pdf.stroke{@pdf.horizontal_rule}
      # Remember the current position so that we know where to
      # continue later
      this_page, this_pos = @pdf.page_count, @pdf.cursor
      # Get the position where the list started
      start_page, start_pos = @note_positions.pop

      if start_page == this_page
        # If no page borders were crossed for this note list,
        # we can just draw the side borders around the block
        # of text.
        @pdf.stroke do
          @pdf.line([0, start_pos], [0, this_pos])                                 # Left border
          @pdf.line([@pdf.bounds.width, start_pos], [@pdf.bounds.width, this_pos]) # Right border
        end
      else
        # Otherwise, the list has been split over multiple pages.
        # Now we need to draw the border from the list’s start to
        # the start page’s bottom, around the sides of any completely
        # filled pages, and from the last list page’s to the list’s end.
        start_page.upto(this_page) do |pagenum|
          # First, switch to the page we want to re-edit
          @pdf.go_to_page(pagenum)

          # Now, depending on which page we switched, draw the
          # borders accordingly.
          @pdf.stroke do
            case pagenum
            when start_page then # List’s first page
              @pdf.line([0, start_pos], [0, 0])                                 # Left border
              @pdf.line([@pdf.bounds.width, start_pos], [@pdf.bounds.width, 0]) # Right border
            when last_page  then # List’s last page
              @pdf.line([0, @pdf.bounds.height], [0, this_pos])                                 # Left border
              @pdf.line([@pdf.bounds.width, @pdf.bounds.height], [@pdf.bounds.width, this_pos]) # Right border
            else # Completely filled page
              @pdf.line([0, @pdf.bounds.height], [0, 0])                                 # Left border
              @pdf.line([@pdf.bounds.width, @pdf.bounds.height], [@pdf.bounds.width, 0]) # Right border
            end #case
          end #stroke
        end #upto

        # Restore the original position to allow the
        # text flow to continue from there. Note that
        # the above loop’s last iteration automatically
        # restores `this_page' as the current page, so
        # no need to do this again here.
        @pdf.move_cursor_to(this_pos)

        # Leave some space to prevent the following text from
        # touching the bottom border.
        @pdf.text("\n")
      end #if start_page == this_page
    end
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

  def handle_special_HYPERLINK(special)
    make_url(special.text)
  end

  def handle_special_RDOCLINK(special)
    "RDOCLINK: #{special.text}"
  end

  # Method copied from RDoc project and slightly modified.
  #
  # Handles hyperlinks of form {text}[url] and text[url].
  def handle_special_TIDYLINK(special)
    return special.text unless special.text =~ /\{(.*?)\}\[(.*?)\]/ or special.text =~ /(\S+)\[(.*?)\]/
    make_url($2, $1)
  end

  private

  def to_prawn(item)
    convert_flow(@am.flow(item))
  end

  # Indents all following flow commands by +padding+ PDF points.
  # Call #pdf_subtract_last_padding to undo the effect.
  def pdf_add_padding(left_padding, right_padding = nil)
    @paddings.push([left_padding, right_padding])
    @pdf.bounds.add_left_padding(left_padding)
    @pdf.bounds.add_right_padding(right_padding) if right_padding
  end

  # Undoes a previous #pdf_add_padding.
  def pdf_subtract_last_padding
    left_padding, right_padding = @paddings.pop
    @pdf.bounds.subtract_right_padding(right_padding) if right_padding
    @pdf.bounds.subtract_left_padding(left_padding)
  end

  def make_url(url, text = nil)
    url = "http://#{url}" unless url =~ /^.*?:/
    if text
      "<color rgb=\"#{EXTERNAL_LINK_COLOR}\"><link href=\"#{url}\">#{text}</link></color>"
    else
      "<color rgb=\"#{EXTERNAL_LINK_COLOR}\"><font name=\"#{MONO_FONT_NAME}\" size=\"#{MONO_FONT_SIZE - 1}\"><link href=\"#{url}\">#{url}</link></font></color>"
    end
  end

end
