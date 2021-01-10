require 'nuixconnectorscript'

include NuixConnectorScript

describe 'log' do
  it 'logs a message with info severity by default' do
    expected = Regexp.escape('{"log":{"severity":"info","message":"message!","time":"')
               + '.+'
               + Regexp.escape('","stackTrace":""}}')
    expect do
      log "message!"
    end.to output(/#{expected}/).to_stdout
  end
  it 'logs a message with specified severity' do
    expected = Regexp.escape('{"log":{"severity":"error","message":"error!","time":"')
               + '.+'
               + Regexp.escape('","stackTrace":""}}')
    expect do
      log("error!", severity: :error)
    end.to output(/#{expected}/).to_stdout
  end
  it 'logs custom time and stacktrace if set' do
    expected = Regexp.escape('{"log":{"severity":"warn","message":"warning!","time":"time","stackTrace":"stack"}}')
    expect do
      log("warning!", severity: :warn, timestamp: 'time', stack: 'stack')
    end.to output(/#{expected}\r?\n/).to_stdout
  end
  it 'does not log if severity is less than LOG_SEVERITY' do
    $VERBOSE = nil
    NuixConnectorScript::LOG_SEVERITY = :info
    $VERBOSE = false
    expect do
      log("nothing please", severity: :debug)
    end.to_not output.to_stdout
  end
end
