lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "offsite_payments/integrations/pay2go/version"

Gem::Specification.new do |spec|
  spec.name          = "offsite_payments_pay2go"
  spec.version       = OffsitePayments::Integrations::Pay2go::VERSION
  spec.authors       = ["stan"]
  spec.email         = ["solve153@gmail.com"]

  spec.summary       = %q{OffsitePayments for Pay2go, a Taiwan based payment gateway}
  spec.description   = %q{OffsitePayments for Pay2go}
  spec.homepage      = "https://github.com/GoodLife/offsite_payments_pay2go"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"

    spec.metadata["homepage_uri"] = spec.homepage
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'money', '~> 6.13.3'
  spec.add_runtime_dependency 'offsite_payments', '2.7.11'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_development_dependency "mocha", "~> 1.0"
  spec.add_development_dependency "rails", ">= 3.2.14"
end
