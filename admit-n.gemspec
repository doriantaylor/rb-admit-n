# frozen_string_literal: true

require_relative 'lib/admit-n/version'

Gem::Specification.new do |spec|
  spec.name    = 'admit-n'
  spec.version = AdmitN::VERSION
  spec.authors = ['Dorian Taylor']
  spec.email   = ['code@doriantaylor.com']
  spec.license = 'Apache-2.0'
  spec.summary = 'Admit N: Fulfill One-Off Payments by Adding Users to Access Control'

  spec.description = <<~EOS
  Admit N is a bare-bones microservice that processes the flow of what to do
  next after somebody pays for access to content. It enrolls the principal to
  the authentication scheme (if they aren't already), logs them in (if they
  aren't already), and ferries them to an interface to assign the rest of the
  passes they bought (if applicable) and confirm the assignments.
  EOS
  spec.homepage = 'https://github.com/doriantaylor/rb-admit-n'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # dev dependencies
  spec.add_development_dependency 'bundler', '~> 2',  '>= 2.6'
  spec.add_development_dependency 'rake',    '~> 13', '>= 13.2'
  spec.add_development_dependency 'rspec',   '~> 3',  '>= 3.13'

  # runtime dependencies

  # data
  spec.add_runtime_dependency 'dry-types',   '~> 1',  '>= 1.9'
  spec.add_runtime_dependency 'sequel',      '~> 1',  '>= 5.92'
  spec.add_runtime_dependency 'money',       '~> 7',  '>= 7.0.2'
  spec.add_runtime_dependency 'uuidtools',   '~> 3',  '>= 3.0'

  # web stuff
  spec.add_runtime_dependency 'rack',        '~> 3',  '>= 3.1.14'
  spec.add_runtime_dependency 'rackup',      '~> 2',  '>= 2.2.1'
  spec.add_runtime_dependency 'jwt',         '~> 2',  '>= 2.10.1'
  spec.add_runtime_dependency 'stripe',      '~> 15', '>= 15.2.1'

  # command line stuff
  spec.add_runtime_dependency 'psych',       '~> 5',  '>= 5.2.4'
  spec.add_runtime_dependency 'thor',        '~> 1',  '>= 1.3.2'

  # stuff i made
  spec.add_runtime_dependency 'http-negotiate', '~> 0', '>= 0.2.2'
  spec.add_runtime_dependency 'uuid-ncname',    '~> 0', '>= 0.4.1'
  spec.add_runtime_dependency 'xml-mixup',      '~> 0', '>= 0.2.1'

end
