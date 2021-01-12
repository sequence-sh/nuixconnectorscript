require 'json'

module NuixConnectorScript

  class Error < StandardError; end

  END_CMD       = 'done'.freeze
  ENCODING      = 'UTF-8'.freeze
  LOG_SEVERITY  = :info

  LogSeverity = {
    :fatal => 0,
    :error => 1,
    :warn  => 2,
    :info  => 3,
    :debug => 4,
    :trace => 5
  }

  def log(message, severity: :info, timestamp: Time.now, stack: '')
    return unless LogSeverity[severity] <= LogSeverity[LOG_SEVERITY]
    body = { :log => {
      :severity => severity.to_s,
      :message => message,
      :time => timestamp,
      :stackTrace => stack
    }}
    $stdout.puts JSON.generate(body)
  end

  def return_result(result)
      body = { :result => { :data => result } }
      $stdout.puts JSON.generate(body)
  end

  def write_error(message, timestamp: Time.now, location: '', stack: '', terminating: false)
    body = { :error => {
      :message => message,
      :time => timestamp,
      :location => location,
      :stackTrace => stack
    }}
    log(message, severity: :error, timestamp: timestamp, stack: stack)
    $stderr.puts JSON.generate(body)
    exit(1) if terminating
  end

  def return_entity(props)
      body = { :entity => props }
      $stdout.puts JSON.generate(body)
  end

  def listen()

    log "Starting"

    functions = {}

    loop do

      log("reader: waiting for input", severity: :debug)

      input = $stdin.gets.chomp

      log("reader: received input", severity: :debug)

      begin
        json = JSON.parse(input)
      rescue JSON::ParserError
        write_error("Could not parse JSON: #{input}")
        next
      end

      cmd = json['cmd']

      break if cmd.eql? END_CMD

      args = json['args']
      fdef = json['def']
      is_stream = json['isstream']

      unless fdef.nil?
        op = functions.key?(cmd) ? 'Replacing' : 'Adding new'
        log("#{op} function for '#{cmd}'", severity: :debug)
        functions[cmd] = {
          :accepts_stream => true,
          :fdef => eval(fdef)
        }
      end

      unless functions.key?(cmd)
        write_error("Function definition for '#{cmd}' not found", terminating: true)
      end

      if is_stream
        if !functions[cmd][:accepts_stream]
          write_error("The function '#{cmd}' does not support data streaming", terminating: true)
        end
        datastream = Queue.new
        if args.nil?
          args = { 'datastream' => datastream }
        else
          args['datastream'] = datastream
        end
        dataInput = Thread.new do
          datastream_end = nil
          loop do
            data_in = $stdin.gets.chomp
            if datastream_end.nil?
              datastream_end = data_in
            elsif datastream_end.eql? data_in
              datastream.close
              datastream_end = nil
              break
            else
              datastream << data_in
            end
          end
        end
      end

      begin
        result = args.nil? ? send(functions[cmd][:fdef]) : send(functions[cmd][:fdef], args)
        dataInput.join if is_stream
        return_result(result)
      rescue => ex
        write_error("Could not execute #{cmd}: #{ex}", stack: ex.backtrace.join("\n"), terminating: true)
      end

    end

    log "Finished"

  end

end

if $0 == __FILE__
  include NuixConnectorScript
  $utilities = utilities if defined? utilities
  NuixConnectorScript.listen
end
