# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cloudtasker/version'

Gem::Specification.new do |spec|
  spec.name          = 'cloudtasker'
  spec.version       = Cloudtasker::VERSION
  spec.authors       = ['Arnaud Lachaume']
  spec.email         = ['arnaud.lachaume@keypup.io']

  spec.summary       = 'Background jobs for Ruby using Google Cloud Tasks (beta)'
  spec.description   = 'Background jobs for Ruby using Google Cloud Tasks (beta)'
  spec.homepage      = 'https://github.com/keypup-io/cloudtasker'
  spec.license       = 'MIT'

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/keypup-io/cloudtasker'
  spec.metadata['changelog_uri'] = 'https://github.com/keypup-io/cloudtasker/master/tree/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(examples|test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'connection_pool'
  spec.add_dependency 'fugit'
  spec.add_dependency 'google-cloud-tasks'
  spec.add_dependency 'jwt'
  spec.add_dependency 'redis'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'github_changelog_generator'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '0.76.0'
  spec.add_development_dependency 'rubocop-rspec', '1.37.0'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'webmock'

  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'sqlite3'
end
