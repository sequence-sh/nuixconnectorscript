require 'spec_helper'
require 'nuixconnectorscript'

describe 'return_entity' do
  include NuixConnectorScript
  it 'outputs entity json to stdout' do
    expected = Regexp.escape('{"entity":{"prop1":"value","prop2":1}}')
    expect do
      return_entity({ prop1: 'value', prop2: 1 })
    end.to output(/^#{expected}\r?\n$/).to_stdout
  end
end
