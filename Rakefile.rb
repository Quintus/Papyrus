# -*- coding: utf-8 -*-

=begin
This file is part of RDoc PDF LaTeX.

RDoc PDF LaTeX is a RDoc plugin for generating PDF files.
Copyright © 2011  Pegasus Alpha

RDoc PDF LaTeX is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

RDoc PDF LaTeX is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with RDoc PDF LaTeX; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
=end

gem "rdoc", ">= 3"
require "rake"
require "rdoc/task"
require "rubygems/package_task"

PROJECT_TITLE = "LaTeX-PDF generator for RDoc"

RDoc::Task.new do |r|
  r.generator = "hanna"
  r.rdoc_files.include("lib/**/*.rb", "**/*.rdoc", "README.rdoc", "COPYING")
  r.title = PROJECT_TITLE
  r.main = "README.rdoc"
  r.rdoc_dir = "doc"
end

desc "Tests the whole thing by documenting this project with the PDF-LaTeX generator."
task :smoke_test do
  require_relative "lib/rdoc/generator/pdf_latex"
  ENV["RDOCOPT"] = nil
  rdoc = RDoc::RDoc.new
  #TODO: How does this RDoc::Options thing work?
  rdoc.document(%w[-f pdf_latex -m README.rdoc -x Rakefile.rb --debug])
end
