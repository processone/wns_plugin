require 'spec_helper'

describe ADM do
  it "should raise an error if the oauth keys aren't provided" do
    expect {ADM.new}.to raise_error
  end

  describe "sending notification" do
    let(:access_token) { 'Atc|MQEWYJxEnP3I1ND03ZzbY_NxQkA7Kn7Aioev_OfMRcyVQ4NxGzJMEaKJ8f0lSOiV-yW270o6fnkI' }
    let(:expires_in) { 3600 }
    let(:client_id) { 'amzn1.application-oa2-client.0ba5f9a3403f412ab985132164af24d7' }
    let(:client_secret) { '5c6444a8847b398aa901ccf913aeb30364304860c2d59384b38443fb22a9b7d9' }
    let(:invalid_client_secret) { 'invalid' }

    let(:registration_id) {'amzn1.adm-registration.v1.Y29tLmFtYXpvbi5EZXZpY2VNZXNzYWdpbmcuYL3FOMUlCWEdpdm5TZ3RWbm9XUT0hN0lrSU1YUlNSVVBpT2pOd0lnWktvUT09'}
    let(:registration_ids) { [ registration_id ]}
    let(:push_url) { /.*https:\/\/api.amazon.com\/messaging\/registrations\/.*\/messages/ }

    let(:valid_req_access_body) do
      { :grant_type => 'client_credentials',
        :scope => 'messaging:push',
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
        :scope => 'messaging:push',
        :client_id => client_id,
        :client_secret => invalid_client_secret
      }
    end

    let(:valid_response_access_headers) do
      {
        'X-Amzn-RequestId' => 'd917ceac-2245-11e2-a270-0bc161cb589d',
        'Content-Type' => 'application/json'
      }
    end

    let(:valid_push_body) do
      {
        :data => {}
      }
    end

    let(:valid_push_headers) do
      {
        "Content-Type" => 'application/json',
        "X-Amzn-Type-Version" => 'com.amazon.device.messaging.ADMMessage@1.0',
        "Accept" => 'application/json',
        "X-Amzn-Accept-Type" => 'com.amazon.device.messaging.ADMSendResult@1.0',
        "Authorization" => "Bearer #{access_token}"
      }
    end

    let(:valid_push_response_headers) do
        {
          "X-Amzn-Data-md5" => 't5psxALRTM7WN30Q8f20tw==',
          "X-Amzn-RequestId" => 'e8bef3ce-242e-11e2-8484-47fz4656fc00d',
          "Content-Type" => 'application/json',
          "X-Amzn-Type-Version" => 'com.amazon.device.messaging.ADMSendResult@1.0'
        }
    end

    before(:each) do
      stub_request(:post, ADM::REQUEST_ACCESS_URL).with(
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

      stub_request(:post, push_url).with(
        :body => valid_push_body.to_json,
        :headers => valid_push_headers
      ).to_return(
        # ref: https://developer.amazon.com/sdk/adm/sending-message.html
        :body => {
          'registrationID' => registration_id
        }.to_json,
        :headers => valid_push_response_headers,
        :status => 200
      )
    end

    context "without data" do
      it "should get an access token using POST to ADM server" do
        adm = ADM.new(client_id, client_secret)
        adm.send(:get_access_token)
        adm.instance_variable_get(:@access_token).should eq(access_token)
        adm.instance_variable_get(:@expires_in).should eq(expires_in)
      end

      it "should send notification without data using POST to ADM server" do
        adm = ADM.new(client_id, client_secret)
        responses = adm.send_notification(registration_ids)
        responses.each_key { |reg_id|
          responses[reg_id].should include(:response => 'success', :status_code => 200, :body => {'registrationID' => reg_id})
        }
      end
    end

    context "with data" do
      let!(:stub_with_data){
        stub_request(:post, push_url).
          with(:body => {:data => { :score => "5x1", :time => "15:10"}}.to_json,
               :headers => valid_push_headers ).
          to_return(:status => 200, :body => "", :headers => {})
      }
      before do
      end
      it "should send the data in a post request to ADM" do
        gcm = ADM.new(client_id, client_secret)
        gcm.send_notification(registration_ids, { :data => { :score => "5x1", :time => "15:10"} })
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

      subject { ADM.new(client_id, client_secret) }

      context "on access token request failure code 400" do
        before do
          stub_request(:post, ADM::REQUEST_ACCESS_URL).with(
            mock_invalid_access_request_attributes
          ).to_return(
            :body => { 'reason' => 'UNAUTHORIZED_CLIENT' }.to_json,
            :headers => valid_response_access_headers,
            :status => 400
          )
        end
        it "should raise an AccessKeyError exception" do
          adm = ADM.new(client_id, invalid_client_secret)
          expect { adm.send_notification(registration_ids) }.to raise_error(AccessKeyError)
       end
      end

      context "on push failure code 400" do
        before do
          stub_request(:post, push_url).with(
            mock_request_attributes
          ).to_return(
            :body => { 'reason' => 'InvalidChecksum' }.to_json,
            :headers => valid_push_response_headers,
            :status => 400
          )
        end
        it "should not send notification due to 400" do
          responses = subject.send_notification(registration_ids)
          responses.each_key { |reg_id|
            responses[reg_id].should include(:response => 'Invalid request',
                                             :status_code => 400,
                                             :reason => 'InvalidChecksum')
          }
        end
      end

      context "on push failure code 401" do
        before do
          stub_request(:post, push_url).with(
            mock_request_attributes
          ).to_return(
            :body => { 'reason' => 'AccessTokenExpired' }.to_json,
            :headers => valid_push_response_headers,
            :status => 401
          )
        end
        it "should not send notification due to 401" do
          responses = subject.send_notification(registration_ids)
          responses.each_key { |reg_id|
            responses[reg_id].should include(:response => 'Client authentication failed or auth token invalid',
                                             :status_code => 401,
                                             :reason => 'AccessTokenExpired')
          }
        end
      end

      context "on push failure code 413" do
        before do
          stub_request(:post, push_url).with(
            mock_request_attributes
          ).to_return(
            :body => { 'reason' => 'MessageTooLarge' }.to_json,
            :headers => valid_push_response_headers,
            :status => 413
          )
        end
        it "should not send notification due to 413" do
          responses = subject.send_notification(registration_ids)
          responses.each_key { |reg_id|
            responses[reg_id].should include(:response => 'Payload it too large',
                                             :status_code => 413,
                                             :reason => 'MessageTooLarge')
          }
        end
      end

      context "on push failure code 429" do
        before do
          stub_request(:post, push_url).with(
            mock_request_attributes
          ).to_return(
            :body => { 'reason' => 'TooManyRequests' }.to_json,
            :headers => valid_push_response_headers,
            :status => 429
          )
        end
        it "should not send notification due to 429" do
          responses = subject.send_notification(registration_ids)
          responses.each_key { |reg_id|
            responses[reg_id].should include(:response => 'Exceeded maximum allowable rate of messages',
                                             :status_code => 429,
                                             :reason => 'TooManyRequests')
          }
        end
      end

      context "on push failure code 500" do
        before do
          stub_request(:post, push_url).with(
            mock_request_attributes
          ).to_return(
            :body => "",
            :headers => valid_push_response_headers,
            :status => 500
          )
        end
        it "should not send notification due to 500" do
          responses = subject.send_notification(registration_ids)
          responses.each_key { |reg_id|
            responses[reg_id].should include(:response => 'There was an internal error in the ADM server',
                                             :status_code => 500,
                                             :reason => 'unknown')
          }
        end
      end

      context "on push failure code 503" do
        before do
          stub_request(:post, push_url).with(
            mock_request_attributes
          ).to_return(
            :body => "",
            :headers => valid_push_response_headers,
            :status => 503
          )
        end
        it "should not send notification due to 503" do
          responses = subject.send_notification(registration_ids)
          responses.each_key { |reg_id|
            responses[reg_id].should include(:response => 'Server is temporarily unavailable',
                                             :status_code => 503,
                                             :reason => 'unknown')
          }
        end
      end

    end
  end
end
