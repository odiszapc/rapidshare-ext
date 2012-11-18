module Rapidshare
  module Utils
    def post(url, params)
      params[:filecontent] = File.new(params[:filecontent])
      ::RestClient.post(url, params)
    end

    def get(url)
      ::RestClient.get(url)
    end
  end
end