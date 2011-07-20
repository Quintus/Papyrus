# -*- coding: utf-8 -*-
#This file does some monkey patches on RDoc’s classes to make it easier
#to get a LaTeX-conforming represantation that is unique across the whole
#documentation in a way that it can be used as cross-references for 
#<tt>\label</tt> and <tt>\ref</tt> things. <foo>abc</foo>.

class RDoc::CodeObject

  LATEX_FORMATTER = RDoc::Markup::ToLaTeX.new

  #Takes this CodeObject’s name and puts it into #latexize.
  def latexized_name
    latexize(name)
  end

  def latex_description
    LATEX_FORMATTER.convert(comment)
  end
  
  private

  #Completely escapes all LaTeX-special characters from a strirg.
  #==Parameter
  #[str] The strig to process
  #==Return value
  #A string containing the escaped result
  #==Example
  #  puts latexize("ab_ce#ff") #=> ab\_ce\#ff
  def latexize(str)
    LATEX_FORMATTER.escape(str)
  end

end

class RDoc::Context

  #Returns a (hopefully) unique, LaTeX-conforming label string
  #that can be used for cross-references.
  def latex_label
    #Hyperref doesn’t want the ref paramter of the
    #\href command to have escaped underscores, therefore
    #I cannot use the #latexize method here.
    "class-module-#{full_name}"
  end

  #Returns this class’/module’s full lexicographical name in a
  #LaTeX-parsable way.
  def latexized_full_name
    latexize(full_name)
  end
  
end

class RDoc::MethodAttr

  #Returns a (hopefully) unique, LaTeX-conforming label string
  #that can be used for cross-references.
  #==Return value
  #A string object.
  #==Examples
  #  p meth.full_name   #=> "Foo#hello_world"
  #  p meth.latex_label #=> "method-attr-Foo+hello_world
  #
  #  p meth.full_name   #=> "Foo::hello_world"
  #  p meth.latex_label #=> "method-attr-Foo::hello_world
  def latex_label
    #Hyperref doesn’t want underscores to be escaped in the
    #\href command’s ref argument -- therefore I cannot use
    #the #latexize method here.
    escaped = full_name.gsub("#", "+")
    "method-attr-#{escaped}"
  end

  #Returns this method’s full lexicographical name in a
  #LaTeX-parsable way.
  def latexized_full_name
    latexize(full_name)
  end

  def latexized_prefix
    latexize(name_prefix)
  end

  def latexized_prefix_name
    latexized_prefix + latexized_name
  end
  
end

class RDoc::Alias

  def latexized_new_name
    latexize(new_name)
  end

  def latexized_old_name
    latexize(old_name)
  end

end

class RDoc::Constant

  LATEX_VALUE_LENGTH = 10

  #Shortens the value to LATEX_VALUE_LENGTH characters (plus ellipsis ...)
  #and escapes all LaTeX control characters.
  def latexized_value
    if value.chars.count > LATEX_VALUE_LENGTH
      str = latexize(value.chars.first(LATEX_VALUE_LENGTH).join) + "\\ldots"
    else
      str = latexize(value)
    end
    str
  end

  def latex_label
    "const-#{parent.full_name}::#{name}"
  end
  
end
