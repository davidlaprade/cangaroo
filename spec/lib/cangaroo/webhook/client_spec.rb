require 'rails_helper'

module Cangaroo
  module Webhook
    RSpec.describe Client do
      let(:client) { Client.new(connection, '/api_path') }

      let(:connection) { create(:cangaroo_connection) }

      let(:url) { "http://#{connection.url}/api_path" }

      let(:request_id) { '123456' }
      let(:parameters) { { email: 'info@nebulab.it' } }
      let(:payload) { { order: { id: 'R12345', state: 'completed' } } }

      let(:response) do
        { 'request_id': '52f367367575e449c3000001',
          'summary': 'Successfully updated order for R12345' }
      end

      before do
        stub_request(:post, /^#{url}.*/)
          .to_return(body: response.to_json, status: 200)
      end

      describe '.post' do
        it 'makes the post request with correct url, headers and body' do
          client.post(payload, request_id, parameters)
          expect(WebMock).to have_requested(:post,
                                            'http://www.store.com/api_path')
            .with(
              headers: { 'X_HUB_TOKEN': connection.token },
              body: {
                request_id: request_id,
                parameters: connection.parameters.deep_merge(parameters),
                order: { id: 'R12345', state: 'completed' }
              }.to_json)
        end

        context 'when response code is 200 (success)' do
          it 'returns the parsed response' do
            expect(client.post(payload, request_id, parameters))
              .to eq(response.stringify_keys)
          end
        end

        context 'when response code is 203 (no content)' do
          it 'returns an empty string' do
            stub_request(:post, /^#{url}.*/).to_return(status: 203, body: '')

            expect(client.post(payload, request_id, parameters)).to eq('')
          end
        end

        context 'when response code is not 200 (success)' do
          let(:failure_response) do
            {
              'request_id': '52f367367575e449c3000001',
              'summary': 'Cannot update order. Order R12345 not found in storefront.'
            }
          end

          before do
            stub_request(:post, /^#{url}.*/).to_return(
              body: failure_response.to_json,
              status: 500)
          end

          it 'raises Cangaroo::Webhook::Error' do
            expect { client.post(payload, request_id, parameters) }
              .to raise_error(Cangaroo::Webhook::Error)
          end
        end
      end
    end
  end
end
