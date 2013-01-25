module Rapidshare
  module Ext

    # Downloads files from Rapidshare. Separate from +Rapidshare::API+ class because
    # downloading is much more complex than other service calls.
    #
    # Displays text progress bar during download.
    #
    # Note from odiszapc:
    # 1 oct 2012 the Rapidshare download API (http://images.rapidshare.com/apidoc.txt) was changed
    # so the base download function provided by rapidshare gem became broken
    #
    # In the original method the parameter :filename being interpreted incorrectly now.
    # It's being interpreted like a 'save file as' parameter. Actually it must be equal to the file name you want to download
    # So, to download file now you must specify exactly two parameters: file id and file name.
    class Download
      DOWNLOAD_URL = 'https://rs%s%s.rapidshare.com/cgi-bin/rsapi.cgi?%s'

      attr_reader :url, :api, :fileid, :filename, :filesize, :server_id,
                  :short_host, :downloads_dir, :downloaded, :error

      # Options:
      # * *filename* (optional) - specifies filename under which the file will be
      #   saved. Default: filename parsed from Rapidshare link.
      # * *downloads_dir* (optional) - specifies directory into which downloaded files
      #   will be saved. Default: current directory.
      #
      def initialize(url, api, options = {})
        @url = url
        @api = api
        @filename = options[:save_as]
        @downloads_dir = options[:downloads_dir] || Dir.pwd

        # OPTIMIZE replace these simple status variables with status codes
        # and corresponding errors like "File not found"
        #
        # set to true when file is successfully downloaded
        @downloaded = false
        # non-critical error is stored here, beside being displayed
        @error = nil

        @local_filename = options[:save_as]
        @filename = nil # It will be filled automatically by the #check method of the base class
      end

      # Checks if file exists (using checkfiles service) and gets data necessary for download.
      #
      # Returns true or false, which determines whether the file can be downloaded.
      #
      def check
        # PS: Api#checkfiles throws exception when file cannot be found
        response = @api.checkfiles(@url).first rescue {}

        if response[:file_status] == :ok
          @fileid = response[:file_id]
          @filename ||= response[:file_name]
          @filesize = response[:file_size].to_i
          @server_id = response[:server_id]
          @short_host = response[:short_host]

          @remote_filename = @filename
          @filename = @local_filename || @remote_filename
          true
        else
          # TODO report errors according to actual file status
          @error = 'File not found'
          false
        end
      end

      # Downloads file. Calls +check+ method first.
      # When block is given a custom progress bar interpretation can be implemented
      def perform
        # before downloading we have to check if file exists. checkfiles service
        # also gives us information for the download: hostname, file size for
        # progressbar
        return self unless self.check

        file = open(File.join(@downloads_dir, @filename), 'wb')
        block_response = Proc.new do |response|
          downloaded = 0
          total = response.header['content-length'].to_i

          unless total == @filesize
            @error = 'Access denied'
            return self
          end

          response.read_body do |chunk|
            file << chunk
            downloaded += chunk.size
            progress = ((downloaded * 100).to_f / total).round(2)
            yield chunk.size, downloaded, total, progress if block_given?
          end
        end

        RestClient::Request.execute(:method => :get,
                                    :url => self.download_link,
                                    :block_response => block_response)
        file.close()
        @downloaded = true
        self
      end

      # Generates link which downloads file by Rapidshare API
      #
      def download_link
        download_params = { :sub => 'download', :fileid => @fileid, :filename => @remote_filename, :cookie => @api.cookie }
        DOWNLOAD_URL % [ @server_id, @short_host, download_params.to_query ]
      end

      # Says whether file has been successfully downloaded.
      #
      def downloaded?
        @downloaded
      end
    end
  end
end