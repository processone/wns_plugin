# Amazon Device Messaging for Kindle Fire (ADM)
ADM sends notifications to Amazon Kindle Fire devices via [ADM](https://developer.amazon.com/sdk/adm.html).

##Installation

    $ gem install adm

##Requirements

Tested ruby versions:

* `1.9.3`
* `2.0.0`

##Usage

Sending notifications:

```ruby
require 'adm'

registrationIds = ["abcd","wxyz"]
options = {:data => 
            {:score => "5x1",
             :time => "15:10"},
           :consolidationKey => "updated_score",
           :expiresAfter => 86400
          }
adm = ADM.new(client_id, client_secret)
begin
  responses = adm.send_notification(registrationIds, options)
  responses.each_key { |reg_id|
    print "registrationId: #{reg_id} - Response: #{responses[reg_id][:response]}"
  }
end
rescue AccessKeyError => accessKeyError
  print "Error retrieving access key: #{accessKeyError.response[:status_code]} #{accessKeyError.response[:reason]}"
end
```

Because ADM requires currently one request per destination client, currently `response` is a hash containing one response for each target registrationId. Each associated response is in turn another hash with the following keys: `body`, `headers`, `response` and `status_code`. Because all responses (including errors) from Amazon are encoded in json format, `body` is already parsed into a hash map representing the json structure itself. If `status_code` is different from 200 (error) the hash also contains the key `reason` with the code returned by ADM Service.

###Running specs

    bundle exec rspec spec
