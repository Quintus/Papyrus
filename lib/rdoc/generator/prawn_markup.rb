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
    return @formatter if defined?(@formatter)
    raise(ArgumentError, "Cannot instanciate formatter without PDF!") unless pdf

    # @formatter = RDoc::Markup::ToPrawnCrossref.new(self.kind_of?(RDoc::Context) ? self : @parent, #Thanks to RDoc for this
    @formatter = RDoc::Markup::ToPrawn.new(pdf, current_heading_level, "UTF-8")
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

end

#FIXME:
#This *doesn't* overwrite the inclusion in the subclasses that
#RDoc::Generator::Markup does!! Therefore I need to monkeypatch
#the subclasses affected by the monkeypatch in markup.rb (RDoc::
#Generator::Markup) as well! YEAH, workarounds for the workarounds!

class RDoc::CodeObject
  include RDoc::Generator::PrawnMarkup
end

class RDoc::Context::Section
  include RDoc::Generator::PrawnMarkup
end

#Note that RDoc::Context::Section is special, as it doesn't inherit
#from RDoc::CodeObject. For the rest, refer to the comment above.
#[RDoc::Context::Section, RDoc::AnyMethod, RDoc::Attr, RDoc::Include, RDoc::Alias, RDoc::Constant, RDoc::Context].each do |klass|
#  klass.send(:include, RDoc::Generator::PrawnMarkup) #private method
#end

#class RDoc::AnyMethod
#  include Comparable
#  
#  #Compares two methods with each other. A method is considered smaller
#  #than another if it is a class method. If +self+ and +other+ are both
#  #of the same type (either "class" or "instance"), they’re compared
#  #alphabetically.
#  #==Parameter
#  #[other] The other method to compare with.
#  #==Return value
#  #-1 if +self+ is smaller than +other+, 0 if they’re equal and
#  #+1 if +self+ is bigger than +other+. +nil+ if +other+ isn’t
#  #a RDoc::AnyMethod.
#  #==Example
#  #  m1.name #=> foo
#  #  m1.type #=> instance
#  #  m2.name #=> bar
#  #  m2.type #=> instance
#  #  m3.name #=> foo
#  #  m3.type #=> class
#  #  
#  #  m1 <=> m2 #=> 1
#  #  m2 <=> m1 #=> -1
#  #  m1 <=> m3 #=> 1
#  #  m3 <=> m1 #=> -1
#  #  m2 <=> m2 #=> 0
#  def <=>(other)
#    return nil unless other.kind_of?(RDoc::AnyMethod)
#    
#    if type == "class" and other.type == "class" #RDoc uses strings, not symbols?
#      name <=> other.name
#    elsif type == "class" and other.type == "instance"
#      -1
#    elsif type == "instance" and other.type == "class"
#        1
#    elsif type == "instance" and other.type == "instance"
#      name <=> other.name
#    else #Shouldn’t be
#      nil
#    end
#  end
#end
