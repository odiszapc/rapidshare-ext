# Rapidshare::Ext

Makes your interactions with Rapidshare API more pleasant by providing new handy features: creating/moving/deleting files/folders in a user friendly way, upload files, etc.

This gem extends the existing one - https://github.com/defkode/rapidshare, so it has all features implemented in the source library. In addition, it much simplifies operations with data in your Rapidshare account.

## Installation

Add this line to your Gemfile:

    gem 'rapidshare-ext'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rapidshare-ext

## Usage

First, create an instance:
```ruby
api = Rapidshare::API.new(:login => 'my_login', :password => 'my_password')
api = Rapidshare::API.new(:cookie => 'cookie_here') # More preferable way
```

### Folders
As you note you can have a hierarchy of folders in your account.

Creating folders:
```ruby
folder_id = api.add_folder "a/b/c" # => <FOLDER ID>
```

Deleting folders:
```ruby
api.remove_folder("/a/b/c")
```

Moving folders:
```ruby
api.move_folder("/a/b/c", :to => "/a")
```
This moves folder "c" from directory "/a/b/" and places it under the directory "/a"

Get hierarchy of all folders in account:
```ruby
api.folders_hierarchy
# => {
#   <folder ID> => {
#     :parent => <parent folder ID>,
#     :name => <folder name>,
#     :path => <folder absolute path>
#   },
#   ...
# }
```

Note, that after the folder hierarhy is generated first time the data is cached permanently to improve performance.

So, if you want to invalidate the cache just call the above method with trailing "!":
```ruby
api.folders_hierarchy!
```

If folder tree is inconsistent (orphans are found) the Exception will be thrown. To automatically normalize the tree, call the method with :consistent flag:
```ruby
api.folders_hierarchy :consistent => true
```
Be careful with a tree consistency, orphan folders may contain a critical data.

A more secure way to deal with consistency is to fix orphans first and then generate folders tree:
```ruby
api.add_folder "/garbage"
api.move_orphans :to => "/garbage" # Collect all orphans and place them under the /garbage folder
tree = api.folders_hierarchy
```

### Orphans
Ok, the Rapidshare has its common problem: orphan folders. What is this? For example we have the following directory tree:
```
ROOT
`-a  <- RS API allows us to delete JUST THIS folder, so hierarchy relation between folders will be lost and the folders "c" and "b" will become orphans
  `-b
    `-c
```
Orphans is invisible in your File Manager on the Rapidshare web site, so you may want to hide data in that way (stupid idea)
We can fix it by detecting all orphan fodlers and moving them to a specific fodler:
```ruby
move_orphans :to => "/"
```

Or we can just kill'em all:
```ruby
remove_orphans!
```

Get folder ID or path:
```ruby
id = api.folder_id("/foo/bar") # <ID>
api.folder_path(id) # "/foo/bar"
```

### Files

File uploading is simple now:
```ruby
api.upload("/home/odiszapc/my_damn_cat.mov", :to => "/gallery/video", :as => "cat1.mov")
# => {
#  :id         => 1,
#  :size       => 12345, # File size in bytes
#  :checksum   => <MD5>,
#  :url        => <DOWNLOAD_URL>, # https://rapidshare/.......
#  :already_exists? => true/false # Does the file already exists within a specific folder, real uploading will not being performed in this case
#}
```
After uploading has been completed the file will be stored in a Rapidshare as "/gallery/video/cat1.mov"
To get download url after uploading:
```ruby
result = api.upload("/home/odiszapc/my_damn_cat.mov", :to => "/gallery/video", :as => "cat1.mov")
result[:url]
```

By default, file is uploaded to root folder:
```ruby
api.upload("/home/odiszapc/my_damn_humster.mov")
```

Deleting files:
```ruby
api.remove_file("/putin/is/a/good/reason/to/live/abroad/ticket_to_Nikaragua.jpg")
```

Renaming files:
```ruby
api.rename_file("/foo/bar.rar", "baz.rar")
```

Moving files:
```ruby
api.move_file("/foo/bar/baz.rar", :to => "/foo") # new file path: "/foo/baz.rar"
api.move_file("/foo/bar/baz.rar") # move to a root folder
```

Get file ID:
```ruby
api.file_id("/foo/bar/baz.rar") # => <ID>
```

### Account
You can null your account by deleting all data involved. Be carefull with it, all data will be lost:
```ruby
api.erase_all_data!
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request