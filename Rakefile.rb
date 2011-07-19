gem "rdoc", ">= 3"
require "rake"
require "rdoc/task"
require "rubygems/package_task"

require_relative "lib/rdoc/generator/pdf_latex"

PROJECT_TITLE = "LaTeX-PDF generator for RDoc"

RDoc::Task.new do |r|
  r.generator = "hanna"
  r.title = PROJECT_TITLE
  r.main = "README.rdoc"
  r.rdoc_dir = "doc"
end

desc "Tests the whole thing by documenting this project with the PDF-LaTeX generator."
task :smoke_test do
  ENV["RDOCOPT"] = nil
  rdoc = RDoc::RDoc.new
  rdoc.document(%w[-f pdf_latex -m README.rdoc])
end
