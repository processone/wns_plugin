require 'httparty'
require 'cgi'
require 'json'

class WNS
  include HTTParty

  format :json

  REQUEST_ACCESS_URL = 'https://login.live.com/accesstoken.srf'
  WNS_ACCESS_SCOPE = "notify.windows.com"
  WNS_PUSH_CONTENT_TYPE = "application/octet-stream"

  default_timeout 30

  attr_accessor :timeout, :client_id, :client_secret

  def initialize(client_id, client_secret)
    @client_id = client_id
    @client_secret = client_secret
    @expires_in = 0
    @access_token = nil
    @last_access_timestamp = nil
  end

  def send_notification(channels, options = {})
    access_token = get_access_token()

    params = {
      :body => options.to_json,
      :headers => {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => WNS_PUSH_CONTENT_TYPE,
        'X-WNS-Type' => 'wns/raw'
      }
    }

    responses = {}

    begin
      channels.each do |channel|
        response = self.class.post(channel, params)
        responses[channel] = build_response(response)
      end
    rescue => e
      raise NotificationError.new(e), "Unexpected error sending notification: #{e.message}"
    end
    responses

  end

  ## for debug purposes
  def request_access_token()
    params = {
      :body => { :grant_type => 'client_credentials',
                 :scope => WNS_ACCESS_SCOPE,
                 :client_id => @client_id,
                 :client_secret => @client_secret
               },
      :headers => {
        'Content-Type' => 'application/x-www-form-urlencoded',
      }
    }

    raw_response = self.class.post(REQUEST_ACCESS_URL, params)

    build_response(raw_response)

  end

  private

  def build_response(response)

    body = response.parsed_response || {}
    case response.code
      when 200
        { :response => 'success', :body => body, :headers => response.headers,
          :status_code => response.code }
      when 400
        { :response => 'Wrong headers', :body => body, :headers => response.headers,
          :status_code => response.code,
          :reason => body['reason'] || 'unknown' }
      when 401
        { :response => 'Access token expired',
          :headers => response.headers, :body => body, :status_code => response.code,
          :reason => body['reason'] || 'unknown' }
      when 403
        { :response => 'Invalid token',
          :headers => response.headers, :body => body, :status_code => response.code,
          :reason => body['reason'] || 'unknown' }
      when 404
        { :response => 'Invalid token', :body => body, :headers => response.headers,
          :status_code => response.code,
          :reason => 'unknown' }
      when 406
        { :response => 'Exceeded maximum allowable rate of messages',
          :headers => response.headers, :body => body, :status_code => response.code,
          :reason => body['reason'] || 'unknown' }
      when 413
        { :response => 'Payload is too large', :body => body, :headers => response.headers,
          :status_code => response.code,
          :reason => body['reason'] || 'unknown' }
      when 500
        { :response => 'There was an internal error in the WNS server',
          :headers => response.headers, :body => body, :status_code => response.code,
          :reason => body['reason'] || 'unknown' }
      when 503
        { :response => 'Server is temporarily unavailable',
          :headers => response.headers, :body => body, :status_code => response.code,
          :reason => body['reason'] || 'unknown' }
    end
  end

  def get_access_token()
    if @access_token == nil || access_token_expired()
      @access_token = nil
      @last_access_timestamp = nil

      response = request_access_token()

      if response[:status_code] != 200
        raise AccessKeyError.new(response), 'Error requesting access key to push data'
      else
        body = response[:body]
        @access_token = body['access_token']
        @last_access_timestamp = Time.now
        @expires_in = body['expires_in']
      end
    end

    @access_token
  end

  def access_token_expired()
    (@last_access_timestamp + @expires_in) < Time.now
  end

end

class ResponseError < StandardError
  # Returns the failed response decomposed into the following keys
  # { :response => String, :headers => Hash, :status_code => Number,
  #   :reason => String }
  # @return Hash
  attr_reader :response
  # Instantiate an instance of ResponseError with a Hash object
  # @param [Hash]
  def initialize(response)
    @response = response
  end
end

# Exception raised when WNS instance fails to retrieve an access key before
# pushing data
class AccessKeyError < ResponseError; end
class NotificationError < ResponseError; end
