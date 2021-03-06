# -*- coding: utf-8 -*-
#
# This file is part of Papyrus.
# 
# Papyrus is a RDoc plugin for generating PDF files.
# Copyright © 2011  Pegasus Alpha
# 
# Papyrus is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# Papyrus is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Papyrus; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#Mixin module mixed into RDoc::CodeObject subclasses in order
#to overwrite RDoc’s standard RDoc::Generator::Markup mixin module that
#forces RDoc to HTML output. This module forces RDoc to LaTeX output ;-).
#
#Note that just mixing this into RDoc::CodeObject isn’t enough as the
#RDoc::Generator::Markup module is mixed into the subclasses and
#would therefore take precedence during method lookup.
module RDoc::Generator::LaTeX_Markup

  #Special escapes to be used inside the hyperref labels
  #(hyperref doesn't accept the normal escapes correctly
  #or not at all (in case of _ -> \_). A hash of form:
  #  "char" => "escape"
  LABEL_ESCAPE = {
    "#" => ":INST:",
    "%" => ":perc:",
    "^" => ":xor:",
    "&" => ":amp:",
    "_" => ":und:",
    "~" => ":tilde:",
    "[" => ":rbracket:",
    "]" => ":lbracket:",
    "=" => ":equal:"
  }.freeze
  
  #Create an unique label for this CodeObject.
  #==Return value
  #A string (hopefully) uniquely identifying this CodeObject. Intended for
  #use as the reference in a <tt>\href</tt> command.
  #==Raises
  #[PapyrusError] +self+ isn’t a CodeObject (→ Context::Section).
  def latex_label
    case self
    when RDoc::Context then "class-module-#{label_escape(full_name)}"
    when RDoc::MethodAttr then "method-attr-#{label_escape(full_name)}"
    when RDoc::Constant then "const-#{label_escape(parent.full_name)}::#{label_escape(name)}"
    else
      raise(RDoc::Generator::Papyrus::PapyrusError, "Unrecognized token: #{self.inspect}!")
    end
  end

  #Calls a method of this CodeObject and passes the return value
  #to RDoc::Markup::ToLaTeX#escape.
  #==Parameter
  #[symbol] The symbol of the method (or attribute getter, same in Ruby) to call.
  #[*args]  Any arguments to pass to the method.
  #[&block] A block to pass to the method.
  #==Return value
  #A string from which everything LaTeXnically dangerous has been escaped.
  #==Raises
  #[NoMethodError] You passed a +symbol+ of an undefined method.
  def latexized(symbol, *args, &block)
    if respond_to?(symbol)
      formatter.escape(send(symbol, *args, &block).to_s) #formatter method defined below
    else
      raise(NoMethodError, "Requested call to unknown method #{self.class}##{symbol} to be latexized!")
    end
  end
  
  #Instanciates the LaTeX formatter if it is necessary and stores it
  #in an instance variable @formatter. This method is automatically
  #called by RDoc to obtain the formatter this generator wants
  #to use.
  #==Return value
  #Returns the newly instanciated or already stored LaTeX formatter.
  def formatter
    return @formatter if defined?(@formatter)

    @formatter = RDoc::Markup::ToLaTeX_Crossref.new(self.kind_of?(RDoc::Context) ? self : @parent, #Thanks to RDoc for this
                                                    current_heading_level,
                                                    RDoc::RDoc.current.options.inputencoding,
                                                    RDoc::RDoc.current.options.show_hash,
                                                    RDoc::RDoc.current.options.show_pages,
                                                    RDoc::RDoc.current.options.hyperlink_all)
  end
  
  #Heading depth the formatter is currently in. This is added to
  #any heading request the processed markup mades in order to ensure
  #that the correct LaTeX heading order is always preserved. For example,
  #if the user orders a level 2 heading in a file (the README for instance),
  #he gets a larger heading as if he had ordered a level 2 heading inside a
  #method description.
  def current_heading_level
    case self
    when RDoc::TopLevel then 0
    when RDoc::ClassModule then 1 #Never-ever use level 1 headings apart from TopLevels...
    when RDoc::MethodAttr, RDoc::Alias, RDoc::Constant, RDoc::Include then 3
    else
      0
    end
  end

  private

  #Uses the LABEL_ESCAPE hash to replace all necessary characters
  #in +str+ and returns the result.
  def label_escape(str)
    res = str.dup
    LABEL_ESCAPE.each_pair do |char, esc|
      res.gsub!(char, esc)
    end
    res
  end
  
end

#FIXME:
#This *doesn't* overwrite the inclusion in the subclasses that
#RDoc::Generator::Markup does!! Therefore I need to monkeypatch
#the subclasses affected by the monkeypatch in markup.rb (RDoc::
#Generator::Markup) as well! YEAH, workarounds for the workarounds!

#class RDoc::CodeObject
#  include RDoc::Generator::LaTeX_Markup
#end

#Note that RDoc::Context::Section is special, as it doesn't inherit
#from RDoc::CodeObject. For the rest, refer to the comment above.
[RDoc::Context::Section, RDoc::AnyMethod, RDoc::Attr, RDoc::Include, RDoc::Alias, RDoc::Constant, RDoc::Context].each do |klass|
  klass.send(:include, RDoc::Generator::LaTeX_Markup) #private method
end

class RDoc::Constant

  #No more characters than specified here will be shown
  #as a constant’s value. If the content is longer, an
  #ellipsis will be put at the end of the value.
  LATEX_VALUE_LENGTH = 10

  #Shortens the value to LATEX_VALUE_LENGTH characters (plus ellipsis ...)
  #and escapes all LaTeX control characters.
  def latexized_value
    if value.chars.count > LATEX_VALUE_LENGTH
      str = formatter.escape(value.chars.first(LATEX_VALUE_LENGTH).join) + "\\ldots"
    else
      str = formatter.escape(value)
    end
    str
  end
end

class RDoc::AnyMethod
  include Comparable
  
  #Compares two methods with each other. A method is considered smaller
  #than another if it is a class method. If +self+ and +other+ are both
  #of the same type (either "class" or "instance"), they’re compared
  #alphabetically.
  #==Parameter
  #[other] The other method to compare with.
  #==Return value
  #-1 if +self+ is smaller than +other+, 0 if they’re equal and
  #+1 if +self+ is bigger than +other+. +nil+ if +other+ isn’t
  #a RDoc::AnyMethod.
  #==Example
  #  m1.name #=> foo
  #  m1.type #=> instance
  #  m2.name #=> bar
  #  m2.type #=> instance
  #  m3.name #=> foo
  #  m3.type #=> class
  #  
  #  m1 <=> m2 #=> 1
  #  m2 <=> m1 #=> -1
  #  m1 <=> m3 #=> 1
  #  m3 <=> m1 #=> -1
  #  m2 <=> m2 #=> 0
  def <=>(other)
    return nil unless other.kind_of?(RDoc::AnyMethod)
    
    if type == "class" and other.type == "class" #RDoc uses strings, not symbols?
      name <=> other.name
    elsif type == "class" and other.type == "instance"
      -1
    elsif type == "instance" and other.type == "class"
        1
    elsif type == "instance" and other.type == "instance"
      name <=> other.name
    else #Shouldn’t be
      nil
    end
  end
end
