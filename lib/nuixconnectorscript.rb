require 'json'

# Script to enable execution of ruby functions in Nuix
module NuixConnectorScript

  class Error < StandardError; end

  END_CMD      = 'done'.freeze
  ENCODING     = 'UTF-8'.freeze
  LOG_SEVERITY = :trace

  LogSeverity = {
    :fatal => 0,
    :error => 1,
    :warn => 2,
    :info => 3,
    :debug => 4,
    :trace => 5
  }.freeze

  $current_case = nil

  def log(message, severity: :info, timestamp: Time.now, stack: '')
    return unless LogSeverity[severity] <= LogSeverity[LOG_SEVERITY]

    body = { :log => {
      :severity => severity.to_s,
      :message => message,
      :time => timestamp,
      :stackTrace => stack
    } }
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
    } }
    log(message, severity: :error, timestamp: timestamp, stack: stack)
    $stderr.puts JSON.generate(body)
    exit(1) if terminating
  end

  def return_entity(props)
    body = { :entity => props }
    $stdout.puts JSON.generate(body)
  end

  def open_case(path)
    unless $current_case.nil?
      return if $current_case.get_location.get_path.tr('\\', '/') == path.tr('\\', '/')

      log 'Another Case is open, closing first'
      close_case
    end

    log "Opening case: #{path}"
    $current_case = $utilities.case_factory.open(path)
  end

  def close_case
    return if $current_case.nil?

    log "Closing case: #{$current_case.get_location.get_path}"
    $current_case.close
    $current_case = nil
  end

  def listen

    log 'NuixConnectorScript starting'

    functions = {}

    loop do

      log('NuixConnectorScript waiting for stdin input', severity: :trace)

      input = $stdin.gets.chomp

      log('NuixConnectorScript received stdin input', severity: :trace)

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
      case_path = json['casepath']

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

      open_case(case_path) unless case_path.nil?

      if is_stream
        unless functions[cmd][:accepts_stream]
          write_error("The function '#{cmd}' does not support data streaming", terminating: true)
        end
        log("Creating datastream for function '#{cmd}'.", severity: :debug)
        datastream = Queue.new
        if args.nil?
          args = { 'datastream' => datastream }
        else
          args['datastream'] = datastream
        end
        data_input = Thread.new do
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
        log("#{cmd} starting", severity: :debug)
        result = args.nil? ? send(functions[cmd][:fdef]) : send(functions[cmd][:fdef], args)
        if is_stream
          log('Waiting for data stream to finish', severity: :debug)
          data_input.join
        end
        log("#{cmd} finished", severity: :debug)
        return_result(result)
      rescue => e
        write_error(
          "Could not execute #{cmd}: #{e}",
          stack: e.backtrace.join("\n"),
          terminating: true
        )
      end

    end

    close_case
    log 'NuixConnectorScript finished'

  end

end

if $0 == __FILE__
  include NuixConnectorScript
  $utilities = utilities if defined? utilities
  NuixConnectorScript.listen
end
