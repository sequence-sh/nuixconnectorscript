require 'spec_helper'
require 'nuixconnectorscript'

def run_listen(send = [])
  thread = Thread.new do
    listen
  end
  sleep(0.1)
  send.each { |msg| $stdout.puts msg }
  thread.join
end

describe 'listen' do

  include NuixConnectorScript

  DONE_JSON = '{"cmd":"done"}'.freeze

  LOG_START =
    '\{"log":\{"severity":"info","message":"Starting","time":".+","stackTrace":""\}\}\r?\n'.freeze
  LOG_END =
    '\{"log":\{"severity":"info","message":"Finished","time":".+","stackTrace":""\}\}\r?\n'.freeze

  # RSpec::Matchers.define_negated_matcher :not_output, :output

  # it 'returns when END_CMD is received' do
  #   $VERBOSE = nil
  #   NuixConnectorScript::END_CMD = 'end'
  #   $VERBOSE = false
  #   allow($stdin).to receive(:gets) { '{"cmd":"end"}' }
  #   th = Thread.new {listen}
  #   result = nil
  #   expect($stdout).to receive(:puts).twice
  #   expect{result = th.join(1)}.not_to raise_error
  #   expect(result).to_not be_nil
  # end

  it 'logs start and end message' do
    allow($stdin).to receive(:gets) { DONE_JSON }
    expected = LOG_START + LOG_END
    expect { run_listen }.to output(/^#{expected}$/).to_stdout
  end

  it 'runs function and returns a result message' do
    allow($stdin).to receive(:gets).twice.and_return(
      '{"cmd":"get_result","def":"def get_result\n  return \'hello\'\nend"}',
      DONE_JSON
    )
    expected = LOG_START + Regexp.escape('{"result":{"data":"hello"}}') + '\r?\n' + LOG_END
    expect { run_listen }.to output(/^#{expected}$/).to_stdout
  end

  it 'uses stored def to run same function' do
    allow($stdin).to receive(:gets).exactly(3).and_return(
      '{"cmd":"get_result","def":"def get_result\n  return \'hi\'\nend"}',
      '{"cmd":"get_result"}',
      DONE_JSON
    )
    expected = LOG_START \
             + Regexp.escape('{"result":{"data":"hi"}}') \
             + '\r?\n' \
             + Regexp.escape('{"result":{"data":"hi"}}') \
             + '\r?\n' \
             + LOG_END
    expect { run_listen }.to output(/^#{expected}$/).to_stdout
  end

  it 'replaces a function if a new def is provided' do
    allow($stdin).to receive(:gets).exactly(3).and_return(
      '{"cmd":"get_result","def":"def get_result\n  return \'hi\'\nend"}',
      '{"cmd":"get_result","def":"def get_result\n  return \'hello\'\nend"}',
      DONE_JSON
    )
    expected = LOG_START \
             + Regexp.escape('{"result":{"data":"hi"}}') \
             + '\r?\n' \
             + Regexp.escape('{"result":{"data":"hello"}}') \
             + '\r?\n' \
             + LOG_END
    expect { run_listen }.to output(/^#{expected}$/).to_stdout
  end

  it 'passes args to the function' do
    func = "def write_out(args={})\\n  m = [args['1'], args['2']]\\n  return m.join(' ')\\nend"
    allow($stdin).to receive(:gets).exactly(3).and_return(
      "{\"cmd\":\"get_result\",\"def\":\"#{func}\",\"args\":{\"1\":\"hello\", \"2\":\"there!\"}}",
      '{"cmd":"get_result","args":{"1":"bye"}}',
      DONE_JSON
    )
    expected = LOG_START \
             + Regexp.escape('{"result":{"data":"hello there!"}}') \
             + '\r?\n' \
             + Regexp.escape('{"result":{"data":"bye "}}') \
             + '\r?\n' \
             + LOG_END
    expect { run_listen }.to output(/^#{expected}$/).to_stdout
  end

  context 'streams' do

    data_func = '
def process_stream(args={})
  ds = args[\'datastream\']
  while ds and (!ds.closed? or !ds.empty?)
    data = ds.pop
    break if ds.closed? and data.nil?
    log(\'Received: \' + data)
  end
end'.gsub(/\r?\n/, '\\n')

    data_json = "{\"cmd\":\"process_stream\",\"isstream\":true,\"def\":\"#{data_func}\"}"

    it 'redirects stdin to the datastream if isstream is true' do
      allow($stdin).to receive(:gets).and_return(
        data_json,
        'abc-123', # start token
        'data1',
        'data2',
        'abc-123', # end token
        DONE_JSON
      )
      expected = LOG_START \
               + '\{"log":\{"severity":"info","message":"Received: data1","time":".+","stackTrace":""\}\}\r?\n' \
               + '\{"log":\{"severity":"info","message":"Received: data2","time":".+","stackTrace":""\}\}\r?\n' \
               + '\{"result":\{"data":null\}\}\r?\n' \
               + LOG_END
      expect { run_listen }.to output(/^#{expected}$/).to_stdout
    end

    it 'does not redirect stdin if isstream is false' do
      allow($stdin).to receive(:gets).and_return(
        data_json,
        'abc-123', # start token
        'abc-123', # end token
        '{"cmd":"process_stream"}',
        DONE_JSON
      )
      expected = LOG_START \
               + '\{"result":\{"data":null\}\}\r?\n' \
               + '\{"result":\{"data":null\}\}\r?\n' \
               + LOG_END
      expect { run_listen }.to output(/^#{expected}$/).to_stdout
    end

    it 'uses the existing datastream key in the args' do
      allow($stdin).to receive(:gets).and_return(
        "{\"cmd\":\"process_stream\",\"isstream\":true,\"def\":\"#{data_func}\",\"args\":{\"datastream\":\"\"}}",
        'abc-123', # start token
        'data1',
        'abc-123', # end token
        DONE_JSON
      )
      expected = LOG_START \
               + '\{"log":\{"severity":"info","message":"Received: data1","time":".+","stackTrace":""\}\}\r?\n' \
               + '\{"result":\{"data":null\}\}\r?\n' \
               + LOG_END
      expect { run_listen }.to output(/^#{expected}$/).to_stdout
    end

  end

  context 'errors' do

    it "writes error when it can't parse json, and continues" do
      allow($stdin).to receive(:gets).twice.and_return(
        '{"cmd":"}',
        DONE_JSON
      )
      expected_err = Regexp.escape('{"error":{"message":"Could not parse JSON: {\"cmd\":\"}"')
      expected_log = Regexp.escape('{"log":{"severity":"error","message":"Could not parse JSON:')
      expect { run_listen }.to output(/^#{expected_err}/).to_stderr.and \
        output(/^#{expected_log}/).to_stdout
    end

    it "writes error when it can't find a function definition, and terminates" do
      allow($stdin).to receive(:gets).once.and_return(
        '{"cmd":"unknown"}'
      )
      expected_err = Regexp.escape(
        '{"error":{"message":"Function definition for \'unknown\' not found"'
      )
      expected_log = Regexp.escape(
        '{"log":{"severity":"error","message":"Function definition for \'unknown\' not found'
      )
      expect { run_listen }.to output(/^#{expected_err}/).to_stderr.and \
        output(/^#{expected_log}/).to_stdout.and raise_error(SystemExit)
    end

    it "writes error when it can't execute a function, and terminates" do
      allow($stdin).to receive(:gets).once.and_return(
        '{"cmd":"get_result","def":"def get_result\n  retrn \'hi\'\nend"}'
      )
      expected_err = Regexp.escape('{"error":{"message":"Could not execute get_result:')
      expected_log = Regexp.escape(
        '{"log":{"severity":"error","message":"Could not execute get_result:'
      )
      expect { run_listen }.to output(/^#{expected_err}/).to_stderr.and \
        output(/^#{expected_log}/).to_stdout.and raise_error(SystemExit)
    end

  end

end

################################################################################
