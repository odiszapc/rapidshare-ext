module Rapidshare
  module Ext

    # Note from odiszapc:
    #
    # 1 oct 2012 the Rapidshare download API (http://images.rapidshare.com/apidoc.txt) was changed
    # so the base download function provided by rapidshare gem became broken
    #
    # In the original method the parameter :filename being interpreted incorrectly now.
    # It's being interpreted like a 'save file as' parameter. Actually it must be equal to the file name you want to download
    # So, to download file now you must specify exactly two parameters: file id and file name.
    class Download < Rapidshare::Download

      # Options:
      # * *filename* (optional) - specifies filename under which the file will be
      #   saved. Default: filename parsed from Rapidshare link.
      # * *downloads_dir* (optional) - specifies directory into which downloaded files
      #   will be saved. Default: current directory.
      #
      def initialize(url, api, options = {})
        super
        @local_filename = options[:save_as]
        @filename = nil # It will be filled automatically by the #check method of the base class
      end

      # Checks if file exists (using checkfiles service) and gets data necessary for download.
      #
      # Returns true or false, which determines whether the file can be downloaded.
      #
      def check
        res = super
        if res
          @remote_filename = @filename
          @filename = @local_filename || @remote_filename
        end
        res
      end

      def perform
        # before downloading we have to check if file exists. checkfiles service
        # also gives us information for the download: hostname, file size for
        # progressbar
        return self unless self.check

        begin
          file = open(File.join(@downloads_dir, @filename), 'wb')
          block_response = Proc.new do |response|
            size = 0
            progress = 0
            total = response.header['content-length'].to_i

            response.read_body do |chunk|
              file << chunk
              size += chunk.size
              new_progress = (size * 100) / total
              unless new_progress == progress
                puts "\rDownloading (%3d%%) " % [new_progress]
              end
              progress = new_progress
            end
          end

          RestClient::Request.execute(:method => :get,
                                      :url => self.download_link,
                                      :block_response => block_response)
        ensure
          file.close()
        end
      end

      # Generates link which downloads file by Rapidshare API
      #
      def download_link
        download_params = { :sub => 'download', :fileid => @fileid, :filename => @remote_filename, :cookie => @api.cookie }
        DOWNLOAD_URL % [ @server_id, @short_host, download_params.to_query ]
      end
    end
  end
end