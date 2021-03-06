module Beebotte
  require "beebotte/version"
  require 'hmac-sha1'
  require 'base64'
  require 'json'
  require 'rest-client'
  require 'base64'
  require 'classy_hash'
  require 'mqtt'

  class Connector

    ATTRIBUTE_TYPE_LABELS =     [
        'any',
        'number',
        'string',
        'boolean',
        'object',
        'function',
        'array',
        'alphabetic',
        'alphanumeric',
        'decimal',
        'rate',
        'percentage',
        'email',
        'gps',
        'cpu',
        'memory',
        'netif',
        'disk',
        'temperature',
        'humidity',
        'body_temp',
    ]

    def initialize(apiKey, secretKey, hostname='api.beebotte.com', port=80, protocol=nil, headers=nil)
      @apiKey = apiKey
      @secretKey = secretKey
      @hostname = hostname
      @port = port
      @protocol = protocol.is_a?(String) ? protocol.downcase : ((@port == 443) ? 'https' : 'http')
      @headers = headers || {
          "Content-type" => 'application/json',
          "Content-MD5" => '',
          "User-Agent" => get_useragent_string
      }

      @resource_schema = {
          name: CH::G.string_length(2..30),
          label: [:optional, CH::G.string_length(0..30) ],
          description: [:optional, String ],
          vtype: Set.new(ATTRIBUTE_TYPE_LABELS),
          sendOnSubscribe: [:optional, TrueClass]
      }

      @channel_schema = {
          name: CH::G.string_length(2..30),
          label: [:optional, CH::G.string_length(0..30) ],
          description: [:optional, String ],
          resources: [ [ @resource_schema ] ],
          ispublic: [:optional, TrueClass]
      }

      @read_params_schema = {
          channel: CH::G.string_length(2..30),
          resource: CH::G.string_length(2..30),
          limit: [:optional, 1..2000 ],
          'time-range' => [:optional, String],
          'start-time' => [:optional, String],
          'end-time' => [:optional, String],
          filter: [:optional, String],
          'sample-rate' => [:optional, 1..10000]
      }

    end

    # write persistent information
    def write(channel, resource, data, &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      raise ArgumentError, 'Resource name must be a string' unless resource.is_a?(String)
      raise ArgumentError, 'Data must be a hash object' unless data.is_a?(Hash)

      body = {data: data}
      response = post_data("/v1/data/write/#{channel}/#{resource}", body.to_json)
      if block
        block.call(response.body, response.code)
      else
        (response.code >= 200 && response.code < 300) ? true : false
      end
    end

    # publish transient information
    def publish(channel, resource, data, &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      raise ArgumentError, 'Resource name must be a string' unless resource.is_a?(String)
      raise ArgumentError, 'Data must be a hash object' unless data.is_a?(Hash)
      body = {data: data}
      response = post_data("/v1/data/publish/#{channel}/#{resource}", body.to_json)
      if block
        block.call(response.body, response.code)
      else
        (response.code >= 200 && response.code < 300) ? true : false
      end
    end

    # Read persisted messages from the specified channel and resource
    #
    # ==== Attributes
    #
    # * +channel+ - String: the channel name
    # * +resource+ - String: the resource name
    # * +params+ - Hash: the query parameters: 'time-range', 'start-time', 'end-time', 'limit', 'filter', 'sample-rate'
    #
    def read(params, &block)
      ClassyHash.validate(params, @read_params_schema, strict: true)
      params[:limit] ||= 750
      rtn = {}
      uri = "/v1/data/read/#{params[:channel]}/#{params[:resource]}"
      [:channel, :resource].each {|k| params.delete(k) }
      response = get_data(uri, params)
      rtn = JSON.parse(response.body) if response.code >= 200 && response.code < 300
      if block
        block.call(rtn, response.code)
      else
        (response.code >= 200 && response.code < 300) ? rtn : nil
      end

    end

    def get_connections(user=nil, &block)
      resource = user.nil? ? [] : {}
      uri = "/v1/connections" + (resource.is_a?(String) ? "/#{resource}" : '')
      response = get_data(uri)
      resource = JSON.parse(response.body) if response.code >= 200 && response.code < 300
      if block
        block.call(resource, response.code)
      else
        (response.code >= 200 && response.code < 300) ? resource : nil
      end
    end

    def get_conection(user, &block)
      raise ArgumentError, 'User name must be a string' unless user.is_a?(String)
      get_connections(user, &block)
    end


    # get_channels { |response| puts response.body }
    def get_channels(channel=nil, &block)
      rtn = {}
      uri = "/v1/channels" + (channel.is_a?(String) ? "/#{channel}" : '')
      response = get_data(uri)
      rtn = JSON.parse(response.body) if response.code >= 200 && response.code < 300
      if block
        block.call(rtn, response.code)
      else
        (response.code >= 200 && response.code < 300) ? rtn : nil
      end
    end

    def get_channel(channel, &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      get_channels(channel, &block)
    end

    def add_channel(channel, &block)
      ClassyHash.validate(channel, @channel_schema, strict: true)
      # validate that no resource descriptions are the same as the channel name
      raise ArgumentError, 'Must have at least one resource' if channel[:resources].length < 1
      channel[:resources].each do |r|
        raise ArgumentError, 'Resource :name must not equal Channel :name' if r[:name] == channel[:name]
      end
      response = post_data("/v1/channels", channel.to_json)
      if response.code >= 200 && response.code < 300
        get_channel(channel[:name], &block)
      else
        if block
          block.call({}, response.code)
        else
          return false
        end
      end
    end

    def del_channel(channel, &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      response = del_data("/v1/channels/#{channel}")
      if block
        block.call(response.body, response.code)
      else
        return (response.code >= 200 && response.code < 300) ? true : false
      end
    end

    def get_resources(channel, resource='*', &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      rtn = {}
      params = {
          resource: resource
      }
      response = get_data("/v1/channels/#{channel}/resources", params)
      rtn = JSON.parse(response.body) if response.code >= 200 && response.code < 300
      if block
        block.call(rtn, response.code)
      else
        return (response.code >= 200 && response.code < 300) ? rtn : nil
      end
    end

    def get_resource(channel, resource, &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      raise ArgumentError, 'Resource name must be a string' unless resource.is_a?(String)
      get_resources(channel, resource, &block)
    end

    #
    # {resource: {name, description, type, vtype, ispublic}}
    #
    def add_resource(channel, resource, &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      ClassyHash.validate(resource, @resource_schema, strict: true)
      # validate that no resource descriptions are the same as the channel name
      raise ArgumentError, 'Resource :name must not equal Channel :name' if resource[:name] == channel
      response = post_data("/v1/channels/#{channel}/resources", resource.to_json)
      if response.code >= 200 && response.code < 300
        get_resource(channel, resource[:name], &block)
      else
        if block
          block.call({}, response.code)
        else
          return false
        end

      end
    end

    def del_resource(channel, resource, &block)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String)
      raise ArgumentError, 'Resource name must be a string' unless resource.is_a?(String)
      response = del_data("/v1/channels/#{channel}/resources/#{resource}")
      if block
        block.call(response.body, response.code)
      else
        return (response.code >= 200 && response.code < 300) ? true : false
      end
    end

    private

    def get_data(uri, params=nil)
      @headers["Content-MD5"] = ''
      if params && params.is_a?(Hash)
        params.each_with_index do |a, index|
          uri << ((index == 0) ? "?" : "&")
          uri << "#{a[0]}=#{a[1]}"
        end
      end
      signature = get_signature('GET', uri, @headers, @secretKey)
      @headers["Authorization"] = "#{@apiKey}:#{signature}"
      url = "#{@protocol}://#{@hostname}:#{@port}#{uri}"
      response = RestClient.get(url, @headers)
    end

    def post_data(uri, body=nil)
      @headers["Content-MD5"] = body.nil? ? '' : Digest::MD5.base64digest(body)
      signature = get_signature('POST', uri, @headers, @secretKey)
      @headers["Authorization"] = "#{@apiKey}:#{signature}"
      url = "#{@protocol}://#{@hostname}:#{@port}#{uri}"
      response = RestClient.post(url, body, @headers)
    end

    def del_data(uri)
      @headers["Content-MD5"] = ''
      signature = get_signature('DELETE', uri, @headers, @secretKey)
      @headers["Authorization"] = "#{@apiKey}:#{signature}"
      url = "#{@protocol}://#{@hostname}:#{@port}#{uri}"
      response = RestClient.delete(url, @headers)
    end

    def get_signature(method, path, headers, secretKey)
      @headers["Date"] = Time.now.utc.httpdate
      raise ArgumentError, 'Beebotte Secret key is missing' if secretKey.nil? || !secretKey.is_a?(String)
      raise ArgumentError, 'Invalid method' unless (method == 'GET' || method == 'PUT' || method == 'POST' || method == 'DELETE')
      raise ArgumentError, 'Invalid path' unless path.is_a?(String) && path.match(/^\//)
      stringToSign = "#{method}\n#{headers['Content-MD5']}\n#{headers["Content-type"]}\n#{headers["Date"]}\n#{path}"
      signature = sha1_sign(secretKey, stringToSign)
    end

    def sha1_sign(secretKey, stringToSign)
      hmac = HMAC::SHA1.new(secretKey)
      hmac.update(stringToSign)
      Base64.strict_encode64("#{hmac.digest}")
    end

    def get_useragent_string
      return "beebotte ruby SDK v#{Beebotte::VERSION}"
    end
  end

  class Stream
    attr_accessor :token, :host, :port, :ssl
    attr_reader :subscriptions

    class NotConnected < StandardError; end
    class NoSubscriptions < StandardError; end

    def initialize(opts = {})
      @token = opts[:token]
      @secretKey = opts[:secret_key]
      raise ArguementError, 'Must set token OR secret_key in opts' if (@token.nil? && @secretKey.nil?)
      @host = opts[:host] || "mqtt.beebotte.com"
      @port = opts[:port] || 1883
      @ssl = opts[:ssl] || false
      @subscriptions = []
      @client = MQTT::Client.new
    end

    def connect
      @client.disconnect() if @client.connected?
      @client.host = @host
      @client.port = @port
      @client.ssl = @ssl
      @client.username = @client.password = nil
      @subscriptions = []
      if @token
        @client.username = "token:#{@token}"
      else
        @client.username = @secretKey
      end
      @client.connect()
      @client.connected?
    end

    def disconnect
      @subscriptions = []
      @client.disconnect()
      true
    end

    def connected?
      @client.connected?
    end

    def get(&block)
      raise NoSubscriptions if @subscriptions.length == 0
      @client.get(&block)
    end

    def publish(channel, resource, data)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String) && channel.length.between?(2,30)
      raise ArgumentError, 'Resource name must be a string' unless resource.is_a?(String) && resource.length.between?(2,30)
      raise ArgumentError, 'Data name must be a Hash' unless data.is_a?(Hash)
      data = {data: data, write: false }
      @client.publish("#{channel}/#{resource}" , data.to_json)
    end


    def write(channel, resource, data)
      raise ArgumentError, 'Channel name must be a string' unless channel.is_a?(String) && channel.length.between?(2,30)
      raise ArgumentError, 'Resource name must be a string' unless resource.is_a?(String) && resource.length.between?(2,30)
      raise ArgumentError, 'Data name must be a Hash' unless data.is_a?(Hash)
      data = {data: data, write: true }
      @client.publish("#{channel}/#{resource}" , data.to_json)

    end

    def subscribe(topic)
      raise ArgumentError, "Topic must be in the form of 'channel/resource'" unless topic.is_a?(String) && topic.match(/^[a-zA-Z0-9_]*\/[a-zA-Z0-9_]*$/)
      raise NotConnected unless connected?
      return true if @subscriptions.include?(topic)
      if @client.subscribe(topic)
        @subscriptions << topic
        return true
      else
        return false
      end
    end


  end
end

