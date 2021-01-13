require 'spec_helper'
require 'nuixconnectorscript'

describe 'return_result' do
  include NuixConnectorScript
  it 'outputs result json to stdout' do
    expected = Regexp.escape('{"result":{"data":"message!"}}')
    expect do
      return_result 'message!'
    end.to output(/^#{expected}\r?\n$/).to_stdout
  end
end
