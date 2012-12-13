module Rapidshare
  class API
      # TODO this class is getting long. keep general request-related and helper
      # method here and move specific method calls like :getaccountdetails to other
      # class (service)?
      #
      # TODO enable users to define their own parsers and pass them as code blocks?
      # not really that practical, but it would be a cool piece of code :)

      # Calls specific RapidShare API service and returns result.
      #
      # Throws exception if error is received from RapidShare API.
      #
      # Params:
      # * *service_name* - name of the RapidShare service, for example +checkfiles+
      # * *params* - hash of service parameters and options (listed below)
      # * *parser* - option, determines how the response body will be parsed:
      #   * *none* - default value, returns response body as it is
      #   * *csv* - comma-separated values, for example: _getrapidtranslogs_.
      #     Returns array or arrays, one array per each line.
      #   * *hash* - lines with key and value separated by '=', for example:
      #     _getaccountdetails_. Returns hash.
      # * *server* - option, determines which server will be used to send request
      #
      def self.request(service_name, params = {})
        params.symbolize_keys!

        parser = (params.delete(:parser) || :none).to_sym
        unless [:none, :csv, :hash].include?(parser)
          raise Rapidshare::API::Error.new("Invalid parser for request method: #{parser}")
        end

        server = params.delete(:server)
        server_url = server ? "https://#{server}/cgi-bin/rsapi.cgi?sub=%s&%s" : URL

        http_method = (params.delete(:method) || :get).to_sym
        raise Exception, "invalid HTTP method #{http_method}" unless self.respond_to? http_method

        case http_method
          when :get
            response = self.send(http_method, server_url % [service_name, params.to_query])
          else
            params[:sub] = service_name
            response = self.send(http_method, server_url.gsub(/\?sub=%s&%s$/,''), params)
        end

        if response.start_with?(ERROR_PREFIX)
          case error = response.sub(ERROR_PREFIX, '').split('.').first
            when 'Login failed'
              raise Rapidshare::API::Error::LoginFailed
            when 'Invalid routine called'
              raise Rapidshare::API::Error::InvalidRoutineCalled.new(service_name)
            else
              raise Rapidshare::API::Error.new(error)
            end
        end

        self.parse_response(parser, response)
      end

      def download(file, params= {})
        if file.match /\Ahttps?:\/\//
          url = file
        else
          url = file_info(file)[:url]
        end

        Rapidshare::Ext::Download.new(url, self, params).perform
      end
  end
end