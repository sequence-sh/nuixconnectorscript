# nuixconnectorscript

Nuix Ruby module that executes scripts and reads to/from stdin/out.
The `listen` method in this module is used to _hook_ into Nuix,
execute commands or scripts, and stream data back.

## Usage

To run:

```powershell
& 'C:\Program Files\Nuix\Nuix 9.0\nuix_console.exe' -licencesourcetype dongle C:\Scripts\nuixconnectorscript\lib\nuixconnectorscript.rb
```

Stdin/out is used to write to/from nuix.
A new line is used to delimit both input and output messages,
so all new lines must be escaped.

### Input

The default input, is a command JSON which can be used to
define new functions or execute existing ones:

```json
{
  "cmd": "log_msg",
  "ishelper": false,
  "isstream": true,
  "def": "def log_msg(args={})\n  m = [args['m1'], args['m2']]\n  log m.join(' ')\nend",
  "args": { "m1": "hello", "m2": "there!" },
  "casepath": "C:\\Nuix\\Case"
}
```

| Parameter |       Required       | Description                                                                                           |
| :-------- | :------------------: | :---------------------------------------------------------------------------------------------------- |
| cmd       |  :white_check_mark:  | The name of the function. Used to execute an existing function if no function definition is provided. |
| ishelper  | :white_large_square: | See [helper functions](#helper-functions)                                                             |
| isstream  | :white_large_square: | See [streaming data](#streaming-data)                                                                 |
| def       | :white_large_square: | Function definition. Create new / replace existing function.                                          |
| args      | :white_large_square: | The arguments to be passed to the function.                                                           |
| casepath  | :white_large_square: | If set, opens the Nuix case in this path. If another case is opened, closes that case first.          |

The only reserved `cmd` keyword is `END_CMD` which is `done`
by default. It's used to stop the nuix process: `{"cmd":"done"}`.

### Nuix case - current, open and close

There are two helper functions that can be used to open and close
Nuix cases:

| Function          | Description                                                                        |
| :---------------- | :--------------------------------------------------------------------------------- |
| `open_case(path)` | Opens a case at the given path. If a case is already open, closes that case first. |
| `close_case`      | Closes `$current_case`. Does nothing if no case is opened.                         |

The currently opened case is tracked in the `$current_case`
global variable. This variable is set to a `Case` object
returned by `$utilities.case_factory.open` or `nil` if no
case is currently opened.

If the `casepath` argument is specified in the command JSON,
then the script checks if that case is already opened and,
if not, opens that case.

### Helper Functions

When `ishelper` is set to `true` the function definition
is evaluated but not run. This makes the function available
to any other function.

For example, sending the following two commands:

```json
{"cmd":"helper","def":"def helper\n  log \'hello\'\nend", "ishelper": true}
{"cmd":"run_helper","def":"def run_helper(args={})\n  helper\nend"}
```

Results in the following output:

```json
{"log":{"severity":"info","message":"hello","time":"...","stackTrace":""}}
{"result":{"data":null}}
```

### Streaming data

When `isstream` is set to `true` any subsequent messages
are not processed as a command JSON, but are appended to
a `Queue` object called `datastream` in `args`.

The first message received is saved as the end-of-stream
token. It must be used again to tell the process when the
data stream is finished.

All other messages in a datastream will be added to the queue
as-is, without any processing.

See [Data stream](#data-stream) in [Examples](#examples).

### Responses

All output is written to stdout. There are four types of
messages: log, result, error, and entity.

Error messages are written to stderr and the same message
is _logged_ to stdout using a log severity of `error`.

#### Response helpers

| Function                                                                                 | Output                                                                                                               |
| :--------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------- |
| `log(message, severity: :info, timestamp: Time.now, stack: '')`                          | `{"log":{"severity":"info","message":"Starting","time":"2021-01-13 11:04:47 +0000","stackTrace":""}}`                |
| `return_result(result)`                                                                  | `{"result":{"data":"whatever is returned from a function"}}`                                                         |
| `write_error(message, timestamp: Time.now, location: '', stack: '', terminating: false)` | `{"error":{"message":"Could not parse JSON: abc","time":"2021-01-13 11:06:27 +0000","location":"","stackTrace":""}}` |
| `return_entity(props)`                                                                   | `{"entity":{"prop1":"value","prop2":1}}`                                                                             |

#### Log severities

```ruby
  LogSeverity = {
    :fatal => 0,
    :error => 1,
    :warn  => 2,
    :info  => 3,
    :debug => 4,
    :trace => 5
  }
```

#### Function result

Functions always return a result object when they are finished. If nothing
was _returned_ from the function, the result data will be `null`:

```json
{ "result": { "data": null } }
```

## Nuix Ruby version support

Currently, _minimum_ NUIX version support is `7.4.0` - this is when Nuix
upgraded to Ruby version 2.3.3 (see [release notes](https://download.nuix.com/releases/desktop/stable/8.8/8.8.7.475/docs/en/changelog.html))

### Nuix-Ruby version table

| Nuix | Ruby  |
| :--: | :---: |
| 6.2  | 1.9.3 |
| 7.0  | 2.2.3 |
| 7.4  | 2.3.3 |
| 8.2  | 2.5.3 |
| 8.8  | 2.5.7 |

### Support for Nuix 7.0 - 7.4

Is possible (untested), but the `Queue` class is missing some functionality
that is currently used for data streaming and would need to be implemented.

If not using streaming, the rest should work.

Tests pass if stream context is filtered out: `bundle exec rspec -f d -t ~stream`

## Examples

### Test if a Nuix case exists

Nuix function:

```ruby
def does_case_exist(args={})
  begin
    the_case = $utilities.case_factory.open(args['path'])
    the_case.close()
    return true
  rescue => e
    log("Case does not exist: #{e}")
  end
  return false
end
```

JSON to store the function and execute it (needs to be sent on one line):

```json
{
  "cmd": "does_case_exist",
  "def": "def does_case_exist(args={})\n  begin\n    the_case = $utilities.case_factory.open(args['path'])\n    the_case.close()\n    return true\n  rescue => e\n    log(\"Case does not exist: #{e}\")\n  end\n  return false\nend",
  "args": {
    "path": "C:\\Nuix\\TestCase"
  }
}
```

JSON to run `does_case_exist` again:

```json
{ "cmd": "does_case_exist", "args": { "path": "C:\\Nuix\\AnotherTestCase" } }
```

Input and output:

```
OUT: {"log":{"severity":"info","message":"Starting","time":"2021-01-13 11:20:17 +0000","stackTrace":""}}
IN : {"cmd": "does_case_exist","def":"def does_case_exist(args={})\n  begin\n    the_case = $utilities.case_factory.open(args['path'])\n    the_case.close()\n    return true\n  rescue => e\n    log(\"Case does not exist: #{e}\")\n  end\n  return false\nend","args":{"path":"C:\\Nuix\\TestCase"}}
OUT: {"log":{"severity":"info","message":"Case does not exist: Location does not contain a case: C:\\Nuix\\TestCase","time":"2021-01-13 11:20:38 +0000","stackTrace":""}}
OUT: {"result":{"data":false}}
IN : {"cmd":"does_case_exist","args":{"path":"C:\\Nuix\\AnotherTestCase"}}
OUT: {"result":{"data":true}}
IN : {"cmd":"done"}
OUT: {"log":{"severity":"info","message":"Finished","time":"2021-01-13 11:23:10 +0000","stackTrace":""}}
```

### Data stream

Just a test. No Nuix required to run this example.

Function:

```ruby
def process_stream(args={})
  ds = args['datastream']
  while ds and (!ds.closed? or !ds.empty?)
    data = ds.pop
    break if ds.closed? and data.nil?
    log("Received: #{data}")
  end
end
```

JSON to store the function and execute it (needs to be sent on one line):

```json
{
  "cmd": "process_stream",
  "isstream": true,
  "def": "def process_stream(args={})\n  ds = args['datastream']\n  while ds and (!ds.closed? or !ds.empty?)\n    data = ds.pop\n    break if ds.closed? and data.nil?\n    log(\"Received: #{data}\")\n  end\nend"
}
```

JSON to run `process_stream` again:

```json
{ "cmd": "process_stream", "isstream": true }
```

Datastream messages:

The first and last message is the token that the script uses
to signal the start and end of the stream. This can be anything.

```
end-of-stream
data1
data2
end-of-stream
```

Input and output:

```
OUT: {"log":{"severity":"info","message":"Starting","time":"2021-01-13 11:38:29 +0000","stackTrace":""}}
IN : {"cmd":"process_stream","isstream":true,"def":"def process_stream(args={})\n  ds = args['datastream']\n  while ds and (!ds.closed? or !ds.empty?)\n    data = ds.pop\n    break if ds.closed? and data.nil?\n    log(\"Received: #{data}\")\n  end\nend"}
IN : end-of-stream
IN : data1
OUT: {"log":{"severity":"info","message":"Received: data1","time":"2021-01-13 11:38:45 +0000","stackTrace":""}}
IN : data2
OUT: {"log":{"severity":"info","message":"Received: data2","time":"2021-01-13 11:38:49 +0000","stackTrace":""}}
IN : end-of-stream
OUT: {"result":{"data":null}}
IN : {"cmd":"process_stream","isstream":true}
IN : end-of-stream
IN : data3
OUT: {"log":{"severity":"info","message":"Received: data3","time":"2021-01-13 11:39:20 +0000","stackTrace":""}}
IN : end-of-stream
OUT: {"result":{"data":null}}
IN : {"cmd":"done"}
OUT: {"log":{"severity":"info","message":"Finished","time":"2021-01-13 11:39:28 +0000","stackTrace":""}}
```
