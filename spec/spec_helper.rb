require 'simplecov'
SimpleCov.start do
  add_filter '/vendor/'
end
require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
