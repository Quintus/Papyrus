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
require "rake/clean"
require "rdoc/task"
require "rubygems/package_task"
require_relative "lib/rdoc/generator/pdf_latex"

PROJECT_TITLE = "LaTeX-PDF generator for RDoc"
PROJECT_NAME = "rdoc_pdf-latex"
PROJECT_SUMMARY = "PDF generator plugin for RDoc"
PROJECT_DESC =<<DESC
RDoc PDF LaTeX is a PDF generator plugin for RDoc based on LaTeX. It
allows you to turn your project's documentation into a nice PDF file
instead of the usual HTML output.
DESC

PROJECT_FILES = [
                 Dir["data/*.tex.erb"],
                 Dir["lib/**/*.rb"],
                 Dir["**/*.rdoc"],
                 "VERSION.txt",
                 "COPYING"
                 ].flatten

PROJECT_REQUIREMENTS = [
                        "(pdf)LaTeX2e: For the actual PDF generation."
                        ]

GEMSPEC = Gem::Specification.new do |spec|
  spec.name = PROJECT_NAME
  spec.summary = PROJECT_SUMMARY
  spec.description = PROJECT_DESC
  spec.version = RDoc::Generator::PDF_LaTeX::VERSION.gsub("-", ".")
  spec.author = "Marvin Gülker"
  spec.email = "m-guelker@pegasus-alpha.de"
  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 1.9"
  spec.add_dependency("rdoc", ">= 3.9.1")
  spec.add_development_dependency("hanna-nouveau")
  spec.requirements = PROJECT_REQUIREMENTS
  spec.files = PROJECT_FILES
  spec.has_rdoc = true
  spec.extra_rdoc_files = %w[README.rdoc COPYING]
  spec.rdoc_options << "-t" << PROJECT_TITLE << "-m" << "README.rdoc"
end

Gem::PackageTask.new(GEMSPEC).define

TMP_DOC_DIR = "tmp"

CLOBBER.include(TMP_DOC_DIR)
ENV["RDOCOPT"] = nil #Needed to override my "-f hanna" default

desc "Generate RDoc documentation in HTML format."
task :html_rdoc => :clobber_rdoc do
  #This is tricky, as the Rakefile already loads the
  #PDF generator: Create a new Rakefile and use that one!
  mkdir TMP_DOC_DIR
  cd TMP_DOC_DIR
  File.open("Rakefile", "w") do |f|
    f.write(<<-EOF)
require "rake"
gem "rdoc", ">= 3"
require "rdoc/task"
RDoc::Task.new do |r|
  r.generator = "hanna"
  r.rdoc_files.include("../lib/**/*.rb", "../**/*.rdoc", "../README.rdoc", "../COPYING")
  r.title = "#{PROJECT_TITLE}"
  r.main = "README.rdoc"
  r.rdoc_dir = "../doc"
end
    EOF
  end
  sh "rake rdoc"
  cd ".."
end

RDoc::Task.new do |r|
  r.generator = "pdf_latex"
  r.rdoc_files.include("lib/**/*.rb", "**/*.rdoc", "README.rdoc", "COPYING")
  r.title = #{PROJECT_TITLE}
  r.main = "README.rdoc"
  r.rdoc_dir = "doc"
end

#desc "Tests the whole thing by documenting this project with the PDF-LaTeX generator."
#task :smoke_test do
#  rm_rf PDFDOC_DIR
#  ENV["RDOCOPT"] = nil
#  rdoc = RDoc::RDoc.new
#  #TODO: How does this RDoc::Options thing work?
#  rdoc.document(["-f","pdf_latex", "-m", "README.rdoc", "-x", "Rakefile.rb", "--debug", "-o", PDFDOC_DIR])
#end
