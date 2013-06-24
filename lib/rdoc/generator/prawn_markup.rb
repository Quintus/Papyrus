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

# Mixin that sets the formatter for the CodeObjects it
# is mixed into to the Prawn formatter.
module RDoc::Generator::PrawnMarkup

  # Mimics RDoc::Generator::Markup#description, but with
  # a PDF for outputting.
  def describe_in_pdf(pdf)
    markup_into_pdf(@comment, pdf)
  end

  # Mimics RDoc::Text#markup, but with a PDF
  # for outputting.
  def markup_into_pdf(text, pdf)
    parse(text).accept(formatter(pdf))
  end

  # The formatter to use. When called for the first time,
  # instanciates the Prawn formatter with the given
  # Prawn::Document instances. Otherwise, just returns
  # the already intanciates formatter.
  def formatter(pdf = nil)
    if defined?(@formatter)
      # The formatter may be re-used with a different
      # Prawn::Document PDF object.
      @formatter.pdf = pdf if pdf
      return @formatter
    else
      raise(ArgumentError, "Cannot instanciate formatter without PDF!") unless pdf
    end

    @formatter = RDoc::Markup::ToPrawn.new(self.kind_of?(RDoc::Context) ? self : @parent, # Thanks to RDoc for this
                                           pdf,
                                           current_heading_level,
                                           @store.rdoc.options.inputencoding,
                                           @store.rdoc.options.show_hash,
                                           @store.rdoc.options.show_pages,
                                           @store.rdoc.options.hyperlink_all)
  end

  # The heading level we’re currently in. Instead of directly using
  # the heading level the user provides (by the number of leading
  # equation signs), we add the value returned by this method to
  # the heading level (in ToPrawn#accept_heading). This way, it
  # is possible to use e.g. a level-3 heading in a method documentation,
  # which is then smaller than a level-3 heading in a class documentation
  # or a toplevel file.
  def current_heading_level
    case self
    when RDoc::TopLevel then 0
    when RDoc::ClassModule then 1 #Never-ever use level 1 headings apart from TopLevels...
    when RDoc::MethodAttr, RDoc::Alias, RDoc::Constant, RDoc::Include then 3
    else
      0
    end
  end

  # PDF destination name to use if you want to reference
  # this object. The reference has to be set before you
  # can refer to it.
  def anchor
    case self
    when RDoc::ClassModule then "classmod-#{full_name}"
    when RDoc::Constant    then "const-#{parent.full_name}-#{name}"
    when RDoc::TopLevel    then "toplevel-#{relative_name}"
    when RDoc::Alias       then "alias-#{parent.full_name}-#{new_name}"
    when RDoc::AnyMethod   then "method-#{parent.full_name}-#{pretty_name}"
    when RDoc::Attr        then "attr-#{parent.full_name}-#{pretty_name}"
    else
      raise("Cannot create anchors to objects of class #{self.class}!")
    end
  end

end

# Include the PrawnMarkup module to tell RDoc to use
# the ToPrawn formatter.
class RDoc::CodeObject
  include RDoc::Generator::PrawnMarkup
end

# Include the PrawnMarkup module to tell RDoc to use the ToPrawn
# formatter. Needs to be done separately from the inclusion
# in CodeObject, because Section doesn’t inherit from CodeObject.
class RDoc::Context::Section
  include RDoc::Generator::PrawnMarkup
end
