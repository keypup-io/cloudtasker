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

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_dependency 'activesupport'
  spec.add_dependency 'connection_pool'
  spec.add_dependency 'fugit'
  spec.add_dependency 'google-cloud-tasks'
  spec.add_dependency 'jwt'
  spec.add_dependency 'redis'
  spec.add_dependency 'retriable'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
