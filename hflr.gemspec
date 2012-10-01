# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{hflr}
  s.version = "1.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Colin Davis"]
  s.date = %q{2011-02-09}
  s.description = %q{HFLR -- Hierarchical Fixed Length Records

Allows you to read and write files of fixed width records when the file contains one or more
than one type of record.  

Install with 'gem install hflr'

See the tests and examples bundled with this gem.}
  s.email = %q{colin.c.davis@gmail.com}
  s.extra_rdoc_files = %w(History.txt README.txt)
  s.files = %w(History.txt README.txt hflr.gemspec lib/hflr.rb lib/hflr/fl_record_file.rb lib/hflr/hflr.rb lib/hflr/record_template.rb test/customer_orders.dat test/customers.dat test/examples.rb test/flrfile_test.rb test/record_template_test.rb test/sample.dat test/sample2_out.dat test/sample_activities.dat test/sample_out.dat test/test_helper.rb test/test_hflr.rb)
  #s.homepage = %q{http://rubygems.org}
  #s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = %w(lib)

  s.rubygems_version = %q{1.3.4}
  s.summary = %q{HFLR -- Hierarchical Fixed Length Records  Allows you to read and write files of fixed width records when the file contains one or more than one type of record}
  s.test_files = %w(test/test_hflr.rb test/test_helper.rb)
end
