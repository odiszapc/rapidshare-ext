require 'rest-client'
#require 'progressbar'

# active_support helpers
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/hash/keys'

require 'rapidshare-base/utils'
require 'rapidshare-base/api'
require 'rapidshare-base/download'

require 'rapidshare-ext/api'
require 'rapidshare-ext/download'
require 'rapidshare-ext/version'

class Rapidshare::API
  include Rapidshare::Ext::API
end
