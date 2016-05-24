# Windows Notification Service for Windows Universal Platform (WNS)
WNS sends raw notifications to Universal Windows Platform apps via [WNS](https://msdn.microsoft.com/en-us/windows/uwp/controls-and-patterns/tiles-and-notifications-windows-push-notification-services--wns--overview).

##Installation

    $ gem install wns

##Requirements

Tested ruby versions:

* `1.9.3`
* `2.0.0`

##Usage

Sending raw notifications:

```ruby
require 'wns'

channels = ["https://...abcd","https://...wxyz"]
options = {:data =>
            {:score => "5x1",
             :time => "15:10"},
           :consolidationKey => "updated_score",
           :expiresAfter => 86400
          }
wns = WNS.new(client_id, client_secret)
begin
  responses = wns.send_notification(channels, options)
  responses.each_key { |channel|
    print "URI: #{channel} - Response: #{responses[channel][:response]}"
  }
end
rescue AccessKeyError => accessKeyError
  print "Error retrieving access key: #{accessKeyError.response[:status_code]} #{accessKeyError.response[:reason]}"
end
```

Because WNS uses OAuth 2, it requires currently one request per destination client. Currently `response` is a hash containing one response for each WNS channel. Each associated response is in turn another hash with the following keys: `body`, `headers`, `response` and `status_code`. Because all responses (including errors) from Windows are encoded in json format, `body` is already parsed into a hash map representing the json structure itself. If `status_code` is different from 200 (error) the hash also contains the key `reason` with the code returned by WNS.

###Running specs

    bundle exec rspec spec
