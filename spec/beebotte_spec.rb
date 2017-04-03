require 'spec_helper'

describe Beebotte do
  context 'Connector' do
    it 'properly initializes with API and Secure keys' do
      b = Beebotte::Connector.new("<yourApiKey>", "<yourSecretKey>")
      expect(b.is_a?(Object)).to be_truthy
      expect(b.class).to eq(Beebotte::Connector)
    end

    it 'does not initialize without API and Secure Keys' do
      expect {
        b = Beebotte::Connector.new("<yourApiKey>")
      }.to raise_error ArgumentError
    end

    context 'mocking the bbt api' do
      context 'channel operations' do
        before :all do
          @b = Beebotte::Connector.new("<yourApiKey>", "<yourSecretKey>")
          stub_request(:post, "http://api.beebotte.com/v1/channels").
             to_return(body: "true", status: 200)
          stub_request(:get, "http://api.beebotte.com/v1/channels/channel").
             to_return(body: "{}", status: 200)
          stub_request(:delete, "http://api.beebotte.com/v1/channels/channel").
              to_return(body: "true", status: 200)
        end

        it 'creates a channel if the schema is valid' do
          channel = {"name":"a"}
          expect{ @b.add_channel(channel) }.to raise_error ClassyHash::SchemaViolationError
          channel[:name] = "areallylongnamethatislongerthan30characters"
          expect{ @b.add_channel(channel) }.to raise_error ClassyHash::SchemaViolationError
          channel[:name] = "channel"
          expect{ @b.add_channel(channel) }.to raise_error ClassyHash::SchemaViolationError
          channel[:resources] = [{"name":"resource", "vtype":"any"}]
          @b.add_channel(channel) { |r, code|
            expect(code).to eq(200)
          }
        end


      end
    end
  end
end
