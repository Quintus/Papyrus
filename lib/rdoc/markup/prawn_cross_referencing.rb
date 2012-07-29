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

require "rdoc/cross_reference"
require_relative "to_prawn"

# Mixin module for RDoc formatters. It adds specials for
# recognising cross-references and converts them to
# Prawn’s inline markup tags (namely the +link+ tag).
#
# == Interface
# This mixin requires you to define a few methods it makes
# use of to properly integrate in your formatter. Namely
# you have to define the following instance methods on
# your formatter:
#
# [#context]
#   This method is intended to return the RDoc::Context
#   you’re currently in. From this context all cross-
#   references will be resolved.
# [#hyperlink_all?]
#   If this returns +true+, tries a more liberal search
#   for cross-references than the default. Usually this
#   results in a huge number of false positives being
#   created, as common words, which are normally not used
#   for cross-referencing, will be considered when you
#   enable this.
# [#show_hash?]
#   If this returns +true+, the cross-references for
#   instance methods will always have a leading
#   hash sign #, even if the original markup didn’t
#   specify one.
# [#show_pages?]
#   If this returns +true+, a short page marker in
#   brackets will be placed behind every cross
#   reference.
#
# Ensure that these methods return a meaningful
# value before you execute the call to +super+ in your
# #initialize method, because this will trigger the
# #initialize method of this module, which in turn will
# execute some calls to the methods listed above. This
# module will forward your call to +super+ to the next
# ancestor, so don’t worry your parameters won’t get
# through. And, please note you *have* to call +super+
# in your formatter’s +initialize+. If you don’t, you
# won’t get any cross-referencing facilities, because
# this module’s +initialize+ adds the necessary RDoc
# specials to your formatter.
#
# == The cross-reference mechanism
# To properly resolve the cross-references (including
# display of a page number in brackets if requested by
# the +show_pages+ option), this module employs a
# complex two-run mechanism. This is necessary because
# when a target may first be referenced in the documentation
# somewhere, it may not be defined. For example, if you
# write the documentation of class +Aaa+ and reference the
# docs of class +Bbb+ there, the PDF destination for +Bbb+
# is not defined yet. If it was just for the destination,
# this wouldn’t be much of a problem as it shifts the
# problem of page lookup for creating a valid, clickable
# hyperlink in the viewer’s window to the PDF viewer. However,
# to correctly implement the +show_pages+ option that
# instructs this formatter to place the destination’s page
# number next to the link, we have to do this ourselves.
#
# For this to work, we first need to keep track of the
# pages the PDF destinations are defined for. Although
# the underlying Prawn library already does so, extracting
# the information from the low-level PDF tree it provides
# access to is cumbersome and, to be honest, I did not feel
# like digging in the PDF specification until I figure out
# how this is stored in the PDF tree. Therefore I took another,
# easier approach. Whenever defining a class, method, or
# anything that may be referenced later, a PDF destination
# is added to a) the Prawn document for writing it out
# and b) to the ::resolvable_pdf_references hash documented
# below. Doing so is the duty of the ::add_pdf_reference
# method, which is called from the RDoc::Generator::Papyrus
# class whenever stumbling over one of the referencable
# entities. To resolve such a reference, call the
# ::resolve_pdf_reference method (this is done by this
# formatter whenever it encounters a cross reference).
#
# So long as the documentation only refers to destinations
# already registered with this class, everything is fine.
# However, when doing a forward reference as explained in
# the +Aaa+/+Bbb+ case shown further above, this is not
# possible anymore as the destination has not yet been
# defined and any call to ::resolve_pdf_reference will
# return +nil+ instead of any useful page number. This
# is the reason why all the methods dealing with the
# PDF destinations are module methods rather than instance
# methods of this module: When generating the PDF documentation
# for the first time, destinations are added to the
# ::resolvable_pdf_references hash as already explained. If
# then a cross-reference is encountered that cannot be
# resolved to a page number, this formatter places three
# question marks ??? instead of the page number and link
# on the outputted PDF and remembers the unresolved destinations
# in the ::unresolved_pdf_references hash. Going further through
# the document, the ::resolvable_pdf_references hash gets
# more populated, so that after finishing the document it
# most likely contains all the references that were previously
# unsolvable. However, as the document has already been finished,
# this information does not help us anymore. This enforces
# Papyrus to generate the whole document completely anew,
# but this time providing the already populated
# ::resolvable_pdf_references hash which this formatter
# can now use to resolve all those references that were not
# resolvable previously. Note that before starting the new
# run, the ::unresolved_pdf_references array has to be emptied
# to avoid confusion about references not being resolved
# even after the second run.
#
# It is extremely unlikely that placing the destination
# page number on the PDF causes Prawn to shift following
# text onto a new page and thereby invalidating those
# parts of the ::resolvable_pdf_destinations hash that
# refer to destinations near page edges. Papyrus currently
# does not take care of this unlikely situation, but it
# can be managed if after a document generation run has
# completed, one looks up all the PDF destinations in
# Prawn’s lowlevel PDF tree (which is always up to
# date¹) and compares them with what the
# ::resolved_pdf_references hash contains. If any two
# destinations are found whose page targets are not
# equal to each other, the unlikely case described above
# has occured, which means you have to correct the
# ::resolvable_pdf_references hash and then start
# a new generation run for the document. This process then
# needs to be repeated until all inequalitites between the
# two data structures have been eliminated (as changing
# a reference to a possibly larger page number may result
# in a page break, thus invalidating some other references
# again). However, you have to read and understand the
# {PDF specification}[http://www.adobe.com/devnet/pdf/pdf_reference.html]
# first, as this specifies how Prawn handles its data
# (hint: The cross-referencing stuff is called "links"
# in the PDF spec, and those links refer to "destinations").
# Have fun with the thousand-page document. I’ll glady take
# your pull request. :-)
#
# ¹ Note that while it is always up to date, during a
# generation run it is by no means complete. It is filled
# "live" when destinations are added to the PDF document.
module RDoc::Markup::PrawnCrossReferencing

  # Colour used for internal links. HTML colour code.
  INTERNAL_LINK_COLOR = "0000FF"

  # A hash that maps all already known destinations
  # to the line number where they appear. Keys are strings.
  def self.resolvable_pdf_references
    @resolvable_references ||= {}
  end

  # Names of destinations that could not be resolved yet.
  # An array of strings.
  def self.unresolved_pdf_references
    @unresolved_references ||= []
  end

  # Marks the given destination as resolvable (so that
  # it shows up in the return value of ::resolvable_pdf_reference)
  # and creates the actual PDF destination in the given file.
  #
  # == Parameters
  # [pdf]
  #   The Prawn::Document object to add the destination
  #   to.
  # [dest_name]
  #   Name of the PDF destination you want to register.
  #   Usually the return value of PrawnMarkup#anchor.
  # [page]
  #   The page the destinations is registered on.
  def self.add_pdf_reference(pdf, dest_name, page)
    pdf.add_dest(dest_name, pdf.dest_fit(pdf.page_count - 1)) # 0-based index
    resolvable_pdf_references[dest_name] = page
  end

  # Attempts to resolve the PDF destination +dest_name+
  # into a page number.
  #
  # == Parameters
  # [dest_name]
  #   The PDF destination to resolve, usable the return value
  #   of PrawnMarkup#anchor.
  #
  # == Return value
  # If the destination could be resolved, the page number
  # it refers to. +nil+ otherwise.
  def self.resolve_pdf_reference(dest_name)
    resolvable_pdf_references[dest_name]
  end

  # Like ::resolve_pdf_reference, but if it cannot resolve
  # the documentation, adds the destination name to
  # ::unresolved_pdf_references.
  #
  # == Parameters
  # [dest_name]
  #   The PDF destination to resolve, usable the return value
  #   of PrawnMarkup#anchor.
  #
  # == Return value
  # If the destination could be resolved, the page number
  # it refers to. +nil+ otherwise.
  def self.resolve_pdf_reference!(dest_name)
    if page = resolve_pdf_reference(dest_name) # single = intended
      page
    else
      unresolved_pdf_references << dest_name
      nil
    end
  end

  # Does some extra initialisation necessary for the
  # cross-reference resolver. Namely it adds the
  # RDoc specials for recognising possible cross-references
  # in the markup. Be sure to call +super+ in the including
  # class!
  #
  # This method also calls +super+ itself and passes on all
  # arguments it receives. Ensure that when you call +super+,
  # methods like #context already return a meaningful value.
  def initialize(*)
    super
    @crossref_resolver = RDoc::CrossReference.new(context)

    if hyperlink_all?
      @markup.add_special(RDoc::CrossReference::ALL_CROSSREF_REGEXP, :CROSSREF)
    else
      @markup.add_special(RDoc::CrossReference::CROSSREF_REGEXP, :CROSSREF)
    end

    @markup.add_special(/rdoc-ref:\S\w/, :RDOCLINK)
  end

  # Handles encountered cross references.
  def handle_special_CROSSREF(special)
    # If we aren’t instructed to try resolving all possibilities,
    # we won’t resolve all-lowercase words (which may be false
    # positives not meant to be a reference).
    if !hyperlink_all? and special.text =~ /^[a-z]+$/
      return special.text
    end

    make_crossref(special.text)
  end

  # Handles encountered links of type rdoc-ref:.
  def handle_special_RDOCLINK(special)
    make_crossref(special.match(/^rdoc-ref:/).post_match)
  end

  private

  # Tries to resolve the given reference name.
  #
  # == Parameters
  # [name]
  #   The name to resolve. May be a class name, a
  #   method name, etc.
  # [display_name (nil)]
  #   If +name+ can be resolved, the generated link
  #   will use this as it’s label. This is automatically
  #   derived from +name+ if not given.
  #
  # == Return value
  # If +name+ can be resolved, an inline-prawn construct
  # referencing the target and if requested by the
  # +show_pages+ option the destination’s page number is
  # returned.
  #
  # == Remarks
  # This method is the heart of the cross-referencing
  # mechanism described in this class’ introductionary
  # text. To understand how it works, be sure to read
  # that text.
  def make_crossref(name, display_name = nil)
    # Strip the hash sign # if we’re instructed to
    # do so.
    unless display_name
      if name.start_with?("#") && !show_hash?
        display_name = name[1..-1]
      else
        display_name = name
      end
    end

    # Let RDoc do the hard work of resolving the name.
    resolved = @crossref_resolver.resolve(name, display_name)

    # If RDoc returns a string, the name couldn’t be resolved.
    if resolved.kind_of?(String)
      resolved
    else # Some RDoc::CodeObject subclass instance
      if dest_page = RDoc::Markup::PrawnCrossReferencing.resolve_pdf_reference!(resolved.anchor) # Single = intended
        # Destination page is known
        if show_pages?
          "<color rgb=\"#{INTERNAL_LINK_COLOR}\"><link anchor=\"#{resolved.anchor}\">#{display_name}</link></color> [p. <color rgb=\"#{INTERNAL_LINK_COLOR}\"><link anchor=\"#{resolved.anchor}\">#{dest_page}</link></color>]"
        else
          "<color rgb=\"#{INTERNAL_LINK_COLOR}\"><link anchor=\"#{resolved.anchor}\">#{display_name}</link></color>"
        end
      else # Destination page is not known
        debug("Unresolved PDF reference to #{resolved.anchor}")
        if show_pages?
          display_name + " (p. ???)"
        else
          dispaly_name
        end
      end
    end
  end

end
