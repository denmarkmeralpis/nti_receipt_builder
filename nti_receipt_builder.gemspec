# frozen_string_literal: true

require_relative 'lib/nti_receipt_builder/version'

Gem::Specification.new do |spec|
  spec.name = 'nti_receipt_builder'
  spec.version = NtiReceiptBuilder::VERSION
  spec.authors = ['Den Meralpis']
  spec.email = ['denmark@nueca.com.ph']

  spec.summary = 'A drag-and-drop receipt template builder and renderer for Rails.'
  spec.description = 'NtiReceiptBuilder ships a complete receipt designer — model, layout ' \
                     'validation, millimetre-accurate renderer, Stimulus builder UI and print ' \
                     'views — as a Rails engine. Host applications declare a Variables subclass ' \
                     'that maps receipt placeholders to methods on their own receipt object, so ' \
                     'the gem carries no domain vocabulary of its own.'
  spec.homepage = 'https://github.com/denmarkmeralpis/nti_receipt_builder'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ spec/ features/ sig/ .git .rspec .rubocop.yml Gemfile])
    end
  end

  spec.require_paths = ['lib']

  spec.add_dependency 'actionview', '>= 7.1'
  spec.add_dependency 'activemodel', '>= 7.1'
  spec.add_dependency 'activerecord', '>= 7.1'
  spec.add_dependency 'activesupport', '>= 7.1'
  spec.add_dependency 'railties', '>= 7.1'
end
