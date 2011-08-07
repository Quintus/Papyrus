# -*- coding: utf-8 -*-
require "rdoc/cross_reference"
require_relative "to_latex"

#Class adding cross-referencing facility to the
#RDoc::Markup::ToLaTeX class. If using this class
#instead of RDoc::Markup::ToLaTeX, names of classes
#and modules inside descriptions are recognized as well
#as <tt>rdoc-ref</tt> links, which have the following
#form:
#  rdoc-ref: WhatYouWantToReference
#For information on how to use this class, see it’s
#superclass RDoc::Markup::ToLaTeX.
class RDoc::Markup::ToLaTeX_Crossref < RDoc::Markup::ToLaTeX

  #RDoc::Context this formatter resolves it’s references from.
  attr_accessor :context

  #Creates a new instance of this class.
  #
  #TODO: Add option for suppressing the page number.
  #==Parameters
  #[context]       The RDoc::Context from which references which be
  #                resolved relatively.
  #[show_hash]     Wheather or not to show hash signs # in front of
  #                methods if present.
  #[heading_level] (0) Base level for LaTeX headings. This is useful
  #                to ensure logical smaller parts get smaller
  #                headings; see also RDoc::Markup::ToLaTeX for
  #                more information.
  #[hyperlink_all] (false) If true, tries to hyperlink everything that
  #                looks like a method name. If false, just hyperlink
  #                references with mixed-case or uppercase words and
  #                references starting with # or ::.
  #[markup]        TODO.
  #==Return value
  #The newly created instance.
  #==Example
  #  f = RDoc::Markup::ToLaTeX_Crossref.new(a_rdoc_toplevel, false)
  def initialize(context, show_hash, heading_level = 0, hyperlink_all = false, markup = nil)
    super(heading_level, markup)

    @context           = context
    @show_hash         = show_hash
    @hyperlink_all     = hyperlink_all
    @crossref_resolver = RDoc::CrossReference.new(@context)
    
    if @hyperlink_all
      @markup.add_special(RDoc::CrossReference::ALL_CROSSREF_REGEXP, :CROSSREF)
    else
      @markup.add_special(RDoc::CrossReference::CROSSREF_REGEXP, :CROSSREF)
    end
    
    @markup.add_special(/rdoc-ref:\S\w/, :HYPERLINK)
  end
  
  #call-seq:
  #  show_hash?()   ==> bool
  #  show_hashes?() ==> bool
  #
  #Wheather or not the hash signs # are shown in front of
  #methods.
  #==Return value
  #Either true or false
  #==Example
  #  f.show_hashes? #=> true
  def show_hash?
    @show_hash
  end
  alias show_hashes? show_hash?

  #Wheather or not this formatter tries to resolve
  #even words that may not be references (such as "new"),
  #i.e. those with no method prefix # or :: in front and all
  #in lowercase.
  #==Return value
  #Either true or false
  #==Example
  #  f.hyperlink_all? #=> false
  def hyperlink_all?
    @hyperlink_all
  end

  #Handles encountered cross references.
  def handle_special_CROSSREF(special)
    #If we aren’t instructed to try resolving all possibilities,
    #we won’t resolve all-lowercase words (which may be false
    #positives not meant to be a reference).
    if !@hyperlink_all and special.text =~ /^[a-z]+$/
      return escape(special.text)
    end

    make_crossref(special.text)
  end

  #Adds handling of encountered <tt>rdoc-ref</tt> links
  #to the HYPERLINK handler of the ToLaTeX formatter.
  def handle_special_HYPERLINK(special)
    return make_crossref($') if spec.text =~ /^rdoc-ref:/
    super
  end
  
  private

  #Tries to resolve the given reference name.
  #==Parameters
  #[name] The name to resolve.
  #[display_name] (nil) If +name+ can be resolved, the generated
  #               \\hyperlink will use this as it’s text. This
  #               is automatically derived from +name+ if not
  #               given.
  #==Return value
  #If +name+ can be properly resolved, a \hyperlink construct
  #of the following form is returned:
  #
  #  \hyperlink[<resolved reference>]{<display_name>}%
  #  \nolinebreak[2]%
  #  [p.~\pageref{<resolved reference>}]
  #
  #In any case, the first matching of the following
  #actions is taken:
  #
  #1. If +name+ can be resolved and is documented, returns
  #   the above \hyperlink construct.
  #2. If +name+ can be resolved, but isn’t documented, returns
  #   +display_text+.
  #3. If +name+ was escaped, returns +name+.
  #4. If +name+ is completely unresolved, returns +display_text+.
  #==Remarks
  #Note that this method automatically adds explicit LaTeX hyphenation
  #indications (i.e. <tt>\-</tt>) before namespace separators to
  #prevent names like <tt>Foo::Bar::Baz::FooBar::Hello::World</tt> from producing
  #overfull \hbox-es and running out of the page.
  def make_crossref(name, display_name = nil)
    #If no display name is given, calculate it from
    #the original reference name. If the reference
    #is starting with '#', strip the hash sign if
    #we’re instructed to not show these hashes.
    #In all other cases, just reuse the reference
    #name.
    if !display_name
      if name.start_with?("#") and !@show_hash
        display_name = name[1..-1]
      else
        display_name = name
      end
    end
    
    resolved_name = @crossref_resolver.resolve(name, display_name)

    if resolved_name.kind_of?(String)
      escape(resolved_name)
    else #Some RDoc::CodeObject sublass instance
      if RDoc::RDoc.current.options.show_pages
        "\\hyperref[#{resolved_name.latex_label}]{#{escape(display_name).gsub("::", "\\-::")}} \\nolinebreak[2][p.~\\pageref{#{resolved_name.latex_label}}]"
      else
        "\\hyperref[#{resolved_name.latex_label}]{#{escape(display_name).gsub("::", "\\-::")}}"
      end
    end
  end
  
end
