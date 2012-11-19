require "rest-client"
require "rapidshare"
require "rapidshare-base/utils"
require "rapidshare-base/api"
require "rapidshare-ext/api"
require "rapidshare-ext/download"
require "rapidshare-ext/version"

class Rapidshare::API
  include Rapidshare::Ext::API
end
