require 'spec_helper'
require 'nuixconnectorscript'

# class CaseFactory
#   def open
#   end
# end
# class Utilities
#   case_factory = CaseFactory.new
# end

RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

def get_log_rx(msg)
  return '\{"log":\{"severity":"info","message":"' + msg \
         + '","time":".+","stackTrace":""\}\}\r?\n'
end

describe 'open_case' do

  include NuixConnectorScript

  before(:each) do
    $current_case = nil
    allow($utilities).to receive_message_chain(:case_factory, :open) { 'new_case' }
  end

  after(:all) do
    $current_case = nil
  end

  it 'opens new case' do
    path = 'c:/Nuix/case'
    expected_log = get_log_rx "Opening case: #{path}"
    expect { open_case(path) }.to output(/^#{expected_log}$/).to_stdout
    expect($current_case).to eq('new_case')
  end

  it 'ignores path separators' do
    path = 'c:/Nuix/case'
    already_open = 'c:\Nuix\case'
    $current_case = {}
    allow($current_case).to receive_message_chain(:get_location, :get_path) { already_open }
    expect { open_case(path) }.not_to output.to_stdout
  end

  it 'closes case if a case is open' do
    path = 'c:/Nuix/case'
    another_case = 'c:/another/case'
    expected_log = get_log_rx('Another Case is open, closing first') \
                 + get_log_rx("Closing case: #{another_case}") \
                 + get_log_rx("Opening case: #{path}")
    $current_case = {}
    allow($current_case).to receive_message_chain(:get_location, :get_path) { another_case }
    allow($current_case).to receive(:close) { true }
    expect { open_case(path) }.to output(/^#{expected_log}$/).to_stdout
    expect($current_case).to eq('new_case')
  end

end

describe 'close_case' do

  include NuixConnectorScript

  after(:all) do
    $current_case = nil
  end

  it 'does nothing when no case is open' do
    $current_case = nil
    expect { close_case }.not_to output.to_stdout
  end

  it 'closes an open case' do
    path = 'c:/Nuix/case'
    expected_log = get_log_rx("Closing case: #{path}")
    $current_case = {}
    allow($current_case).to receive_message_chain(:get_location, :get_path) { path }
    allow($current_case).to receive(:close)
    expect { close_case }.to output(/^#{expected_log}$/).to_stdout
    expect($current_case).to be_nil
  end

end
