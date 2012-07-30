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
require_relative "prawn_external_linking"
require_relative "prawn_cross_referencing"

# RDoc formatter than turns RDoc markup into a PDF file
# by using the Prawn PDF library.
class RDoc::Markup::ToPrawn < RDoc::Markup::Formatter
  include RDoc::Text
  include RDoc::Markup::PrawnExternalLinking
  include RDoc::Markup::PrawnCrossReferencing

  # Struct for saving information about used padding.
  # +right_padding+ may be +nil+.
  PaddingInfo = Struct.new(:left_padding, :right_padding)

  # Struct for saving information about a position on a
  # specific page.
  PositionInfo = Struct.new(:page, :cursor)

  # Directory where the font files reside.
  FONT_DIR = Pathname.new(__FILE__).dirname.expand_path.parent.parent.parent + "data" + "fonts"

  # Name of the serif font to use.
  SERIF_FONT_NAME = "Libertine"

  # Prawn font specification for the serif font defined above.
  SERIF_FONT_SPEC = {:bold        => FONT_DIR.join("LinLibertine_RBah.ttf").to_s,
                     :italic      => FONT_DIR.join("LinLibertine_RIah.ttf").to_s,
                     :bold_italic => FONT_DIR.join("LinLibertine_RBIah.ttf").to_s,
                     :normal      => FONT_DIR.join("LinLibertine_Rah.ttf").to_s}

  # Name of the serif small-caps font to use.
  SERIF_CAPS_FONT_NAME = "Libertine-Caps"

  # Prawn font specification for the serif small-caps font defined above.
  SERIF_CAPS_FONT_SPEC = {:normal => FONT_DIR.join("LinLibertine_aS.ttf").to_s}

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
                   13,
                   12]

  #Number of PDF points to indent when a list ist encountered.
  LIST_PADDING = 20

  # The PDF file this formatter will output to,
  # a Prawn::Document object.
  attr_accessor :pdf

  # Create a new ToPrawn formatter.
  #
  # == Parameters
  # [context]
  #   The RDoc::Context to cross-references are resolved
  #   from relatively.
  # [pdf]
  #   The Prawn::Document to output to. Note that
  #   this method doesn’t do any initialisation on
  #   that object, so you have to add the font families
  #   required by this formatter (see constants), set the
  #   default font size, etc. before you pass the object
  #   to this method.
  # [heading_level (0)]
  #   The relative heading level. This value is added to
  #   the heading level the user requests to prevent
  #   huge headings in contexts like method documentation.
  # [inputencoding ("UTF-8")]
  #   Not used currently.
  # [show_hash (false)]
  #   Show the hash signs # behind cross-references to
  #   instance methods even if you don’t wrote them in
  #   the markup.
  # [show_pages (true)]
  #   Print the page numbers cross-references refer to
  #   behind those in brackets.
  # [hyperlink_all (false)]
  #   Go mad and try to crossref everything. Generates lots
  #   of false positives.
  # [markup (nil)]
  #   Passed on to the superclass.
  def initialize(context, pdf, heading_level = 0, inputencoding = "UTF-8", show_hash = false, show_pages = true, hyperlink_all = false, markup = nil)
    @context       = context
    @pdf           = pdf
    @heading_level = heading_level
    @inputencoding = inputencoding
    @show_hash     = show_hash
    @show_pages    = show_pages
    @hyperlink_all = hyperlink_all

    # Call super after this initialisation. This is necessary,
    # because the PrawnCrossReferencing module uses some methods
    # from us that would otherwise return nil.
    super(markup)


    # The following variables are the different stacks
    # used when nesting lists. Each time a nest is done,
    # something is pushed on this stack. On leaving a level,
    # it is removed again.
    @lists_in_progress = [] # Keeps track of the list type(s) we currently process
    @list_numbers      = [] # Keeps track of the labels of number lists
    @paddings          = [] # Keeps track of the indentation
    @note_positions    = [] # Keeps track of page and position in note lists

    # Inline formatting directives as known by Prawn’s
    # inline formatter
    add_tag(:BOLD, "<b>", "</b>")
    add_tag(:TT,   "<font name=\"#{MONO_FONT_NAME}\" size=\"#{MONO_FONT_SIZE}\">", "</font>")
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

  #First method called.
  def start_accepting
    # Nothing
  end

  #Last method called.
  def end_accepting
    # Nothing
  end

  # Called for parsing a paragraph of text.
  def accept_paragraph(par)
    @pdf.text(to_prawn(par.text.chomp), inline_format: true)
  end

  # Called for parsing a code block.
  def accept_verbatim(ver)
    @pdf.save_font do
      @pdf.font MONO_FONT_NAME
      @pdf.text(ver.text.chomp, :size => MONO_FONT_SIZE)
    end

    # Some distance to the following text
    @pdf.text("\n")
  end

  # Called for parsing a horizontal rule.
  def accept_rule(rule)
    orig_width      = @pdf.line_width
    @pdf.line_width = rule.weight

    @pdf.stroke do
      @pdf.horizontal_rule
    end

    @pdf.line_width = orig_width
  end

  # Called when any kind of list starts. Initialises list-specific
  # variables.
  def accept_list_start(list)
    @lists_in_progress.push(list.type)
    if list.type == :LABEL || list.type == :NOTE
      pdf_add_padding(LIST_PADDING, LIST_PADDING) # Labelled lists get both margins
    else
      pdf_add_padding(LIST_PADDING) # Other lists just a left one.
    end

    @list_numbers << 0 if list.type == :NUMBER # Add a label number if we enter a NUMBER list
  end

  # Called when a list ends. Cleanup.
  def accept_list_end(list)
    pdf_subtract_last_padding
    @list_numbers.pop if @lists_in_progress.pop == :NUMBER # Remove a number if we leave a NUMBER list
  end

  # Called when a list item starts. Draws the label/bullet/number and
  # does some initialisation.
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
      tb = Prawn::Text::Formatted::Box.new(label_tokens,
                                           document: @pdf,
                                           width: @pdf.bounds.width - 10, # -5pt left/-5pt right so it doesn’t touch the left/right border
                                           at: [5, @pdf.cursor - 5]) # Place it at X=5 due to ↑ ## -5pt so it doesn’t touch the top border
      tb.render(dry_run: true)
      height = tb.height + 10 # +5pt top/+5pt bottom to prevent the text from touching the top/bottom border

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

      # Continue below the text box and border
      @pdf.move_down(height)

      # Remember current position (needed for drawing the side borders later on)
      @note_positions.push(PositionInfo.new(@pdf.page_count, @pdf.cursor))
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

  # Called when a list ends. Finishes any list decoration and
  # cleans up.
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
      start_info = @note_positions.pop
      start_page, start_pos = start_info.page, start_info.cursor

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
            when this_page  then # List’s last page
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

  # Called for and inserts an empty line.
  def accept_blank_line(line)
    @pdf.text("\n")
  end

  # Called for parsing a heading of any level.
  def accept_heading(head)
    @pdf.font_size HEADING_SIZES[@heading_level + head.level] # Relative heading sizes allow us to use smaller headings e.g. in methods. See PrawnMarkup#current_heading_level for the calculation.
    @pdf.text(head.text)
    @pdf.font_size BASE_FONT_SIZE
    @pdf.text("\n") # Some space, looks better
  end

  # Inserts raw text.
  def accept_raw(raw)
    @pdf.text(raw)
  end

  # Tokenises the inline markup in +item+ and calls the apropriate handlers
  # on the calling instance.
  def to_prawn(item)
    convert_flow(@am.flow(item))
  end

  private

  # Indents all following flow commands by +padding+ PDF points.
  # Call #pdf_subtract_last_padding to undo the effect.
  def pdf_add_padding(left_padding, right_padding = nil)
    @paddings.push(PaddingInfo.new(left_padding, right_padding))
    @pdf.bounds.add_left_padding(left_padding)
    @pdf.bounds.add_right_padding(right_padding) if right_padding
  end

  # Undoes a previous #pdf_add_padding.
  def pdf_subtract_last_padding
    pad_info = @paddings.pop
    @pdf.bounds.subtract_right_padding(pad_info.right_padding) if pad_info.right_padding
    @pdf.bounds.subtract_left_padding(pad_info.left_padding)
  end

end
