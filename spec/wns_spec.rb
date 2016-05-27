require 'spec_helper'

describe WNS do
  it "should raise an error if the oauth keys aren't provided" do
    expect {WNS.new}.to raise_error
  end

  describe "sending notification" do
    let(:access_token) { 'EgAcAQMAAAAALYAAY/c+Huwi3Fv4Ck10UrKNmtxRO6Njk2MgA=' }
    let(:expires_in) { 3600 }
    let(:client_id) { 'ms-app://s-1-15-2-012345678-012345678-012345678-012345678-012345678-012345678-012345678' }
    let(:client_secret) { 'abcdefghijklmnopqrstuvwxy0123456' }
    let(:invalid_client_secret) { 'invalid' }

    let(:channel) {'https://cloud.notify.windows.com/?token=AQE%2525bU%252fSjZOCvRjjpILow%253d%253d'}
    let(:channels) { [ channel ]}

    let(:valid_req_access_body) do
      { :grant_type => 'client_credentials',
        :scope => 'notify.windows.com',
        :client_id => client_id,
        :client_secret => client_secret
      }
    end

    let(:valid_req_access_headers) do
      {
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    end

    let(:invalid_req_access_body) do
      { :grant_type => 'client_credentials',
        :scope => 'notify.windows.com',
        :client_id => client_id,
        :client_secret => invalid_client_secret
      }
    end

    let(:valid_response_access_headers) do
      {
        'Content-Type' => 'application/json'
      }
    end

    let(:empty_push_body) do {} end

    let(:valid_push_body) do
      {
        :data => {}
      }
    end

    let(:valid_push_headers) do
      {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => 'application/octet-stream',
        "X-WNS-Type" => "wns/raw"
      }
    end

    let(:valid_push_response_headers) do
        {        }
    end

    before(:each) do
      stub_request(:post, WNS::REQUEST_ACCESS_URL).with(
        :body => valid_req_access_body,
        :headers => valid_req_access_headers
      ).to_return(
        :body => {
          'access_token' => access_token,
          'expires_in' => expires_in,
          'scope' => 'messaging:push',
          'token_type' => 'Bearer'
        }.to_json,
        :headers => valid_response_access_headers,
        :status => 200
      )

      stub_request(:post, channel).with(
        :body => empty_push_body.to_json,
        :headers => valid_push_headers
      ).to_return(
        :body => {
        }.to_json,
        :headers => valid_push_response_headers,
        :status => 200
      )
    end

    context "without data" do
      it "should get an access token using POST to WNS server" do
        wns = WNS.new(client_id, client_secret)
        wns.send(:get_access_token)
        wns.instance_variable_get(:@access_token).should eq(access_token)
        wns.instance_variable_get(:@expires_in).should eq(expires_in)
      end

      it "should send notification without data using POST to WNS server" do
        wns = WNS.new(client_id, client_secret)
        responses = wns.send_notification(channels)
        responses.each_key { |chan|
          responses[chan].should include(:response => 'success', :status_code => 200, :body => {})
        }
      end
    end

    context "with data" do
      let!(:stub_with_data){
        stub_request(:post, channel).
          with(:body => {:data => { :score => "5x1", :time => "15:10"}}.to_json,
               :headers => valid_push_headers ).
          to_return(:status => 200, :body => "", :headers => {})
      }
      before do
      end
      it "should send the data in a post request to WNS" do
        wns = WNS.new(client_id, client_secret)
        wns.send_notification(channels, { :data => { :score => "5x1", :time => "15:10"} })
        stub_with_data.should have_been_requested
      end
    end

    context "when send_notification responds with failure" do
      let(:mock_invalid_access_request_attributes) do
        {
          :body => invalid_req_access_body,
          :headers => valid_req_access_headers
        }
      end

      let(:mock_request_attributes) do
        {
          :body => valid_push_body,
          :headers => valid_push_headers
        }
      end

      subject { WNS.new(client_id, client_secret) }

      context "on access token request failure code 400" do
        before do
          stub_request(:post, WNS::REQUEST_ACCESS_URL).with(
            mock_invalid_access_request_attributes
          ).to_return(
            :body => { 'reason' => 'UNAUTHORIZED_CLIENT' }.to_json,
            :headers => valid_response_access_headers,
            :status => 400
          )
        end
        it "should raise an AccessKeyError exception" do
          wns = WNS.new(client_id, invalid_client_secret)
          expect { wns.send_notification(channels) }.to raise_error(AccessKeyError)
       end
      end

      context "on push failure code 400" do
        before do
          stub_request(:post, channel).with(
            {
              :body => empty_push_body,
              :headers => valid_push_headers
            }
          ).to_return(
            :body => { 'reason' => 'Wrong headers' }.to_json,
            :headers => valid_push_response_headers,
            :status => 400
          )
        end
        it "should not send notification due to 400" do
          responses = subject.send_notification(channels)
          responses.each_key { |chan|
            responses[chan].should include(:response => 'Wrong headers',
                                             :status_code => 400,
                                             :reason => 'Wrong headers')
          }
        end
      end

      context "on push failure code 401" do
        before do
          stub_request(:post, channel).with(
            {
              :body => empty_push_body,
              :headers => valid_push_headers
            }
          ).to_return(
            :body => { 'reason' => 'AccessTokenExpired' }.to_json,
            :headers => valid_push_response_headers,
            :status => 401
          )
        end
        it "should not send notification due to 401" do
          responses = subject.send_notification(channels)
          responses.each_key { |chan|
            responses[chan].should include(:response => 'Access token expired',
                                             :status_code => 401,
                                             :reason => 'AccessTokenExpired')
          }
        end
      end

      context "on push failure code 413" do
        before do
          stub_request(:post, channel).with(
            {
              :body => empty_push_body,
              :headers => valid_push_headers
            }
          ).to_return(
            :body => { 'reason' => 'Payload is too large' }.to_json,
            :headers => valid_push_response_headers,
            :status => 413
          )
        end
        it "should not send notification due to 413" do
          responses = subject.send_notification(channels)
          responses.each_key { |chan|
            responses[chan].should include(:response => 'Payload is too large',
                                             :status_code => 413,
                                             :reason => 'Payload is too large')
          }
        end
      end

      context "on push failure code 406" do
        before do
          stub_request(:post, channel).with(
            {
              :body => empty_push_body,
              :headers => valid_push_headers
            }
          ).to_return(
            :body => { 'reason' => 'Exceeded maximum allowable rate of messages' }.to_json,
            :headers => valid_push_response_headers,
            :status => 406
          )
        end
        it "should not send notification due to 429" do
          responses = subject.send_notification(channels)
          responses.each_key { |chan|
            responses[chan].should include(:response => 'Exceeded maximum allowable rate of messages',
                                             :status_code => 406,
                                             :reason => 'Exceeded maximum allowable rate of messages')
          }
        end
      end

      context "on push failure code 500" do
        before do
          stub_request(:post, channel).with(
            {
              :body => empty_push_body,
              :headers => valid_push_headers
            }
          ).to_return(
            :body => "",
            :headers => valid_push_response_headers,
            :status => 500
          )
        end
        it "should not send notification due to 500" do
          responses = subject.send_notification(channels)
          responses.each_key { |chan|
            responses[chan].should include(:response => 'There was an internal error in the WNS server',
                                             :status_code => 500,
                                             :reason => 'unknown')
          }
        end
      end

      context "on push failure code 503" do
        before do
          stub_request(:post, channel).with(
            {
              :body => empty_push_body,
              :headers => valid_push_headers
            }
          ).to_return(
            :body => "",
            :headers => valid_push_response_headers,
            :status => 503
          )
        end
        it "should not send notification due to 503" do
          responses = subject.send_notification(channels)
          responses.each_key { |chan|
            responses[chan].should include(:response => 'Server is temporarily unavailable',
                                             :status_code => 503,
                                             :reason => 'unknown')
          }
        end
      end
    end
  end
end
