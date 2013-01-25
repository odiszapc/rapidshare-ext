# Rapidshare::Ext

Makes your interactions with the Rapidshare API more pleasant by providing new handy features: creating/moving/deleting files/folders in a user friendly way, upload files, etc.

Until Jan 2013 this gem has extended the existing one - https://github.com/defkode/rapidshare, so it has all features have been implemented by the authors of the original gem at the moment.
From Jan 2013 Rapidshare-Ext gem has branched out and ships as a standalone library.

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

### Files

Now you can perform file download in two ways: by HTTP/HTTPS url or by absolute path.

First, by the HTTP url, as it has worked before:
```ruby
@rs.download 'https://rapidshare.com/files/4226120320/upload_file_1.txt',
  :downloads_dir => '/tmp',
  :save_as => 'file2.txt' # This doesn't work in the original gem at the moment because of Rapidshare API changes

  # With a default local file name
  @rs.download 'https://rapidshare.com/files/4226120320/upload_file_1.txt',
    :downloads_dir => '/tmp'
```

Download by absolute path from account you owned:
```ruby
@rs.download '/foo/bar/baz/upload_file_1.txt',
  :downloads_dir => '/tmp'
```

In both the first and second samples the result will be the same.

It's possible to implement a custom progress bar functionality by providing a codeblock to #download method
```ruby
@rs.download '/foo/bar.txt', :downloads_dir => '/tmp'
do |chunk_size, downloaded, total, progress|
  # chunk_size has the default value of 16384 bytes for Ruby 1.9
  # downloaded is a aggregated size of file part has already been downloaded at the moment
  # total represents a file total size
  # progress is a progress bar value in percents
  #
  # Example: While user downloading a 102598 bytes file the valuse will be as follows:
  # Iter 1: chunk_size=0,     downloaded=0, total=102598, progress=0
  # Iter 2: chunk_size=16384, downloaded=0, total=102598, progress=15.97
  # Iter 3: chunk_size=16384, downloaded=0, total=102598, progress=31.94
  # Iter 4: chunk_size=16384, downloaded=0, total=102598, progress=47.91
  # Iter 5: chunk_size=16384, downloaded=0, total=102598, progress=63.88
  # Iter 6: chunk_size=16384, downloaded=0, total=102598, progress=79.85
  # Iter 7: chunk_size=16384, downloaded=0, total=102598, progress=95.81
  # Iter 8: chunk_size=4294,  downloaded=0, total=102598, progress=100.00
end
```

File uploading is also became very simple:
```ruby
api.upload('/home/odiszapc/my_damn_cat.mov', :to => '/gallery/video', :as => 'cat1.mov')
# => {
#  :id         => 1,
#  :size       => 12345, # File size in bytes
#  :checksum   => <MD5>,
#  :url        => <DOWNLOAD_URL>, # https://rapidshare/.......
#  :already_exists? => true/false # Does the file already exists within a specific folder, real uploading will not being performed in this case
#}
```
Destination folder will be created automatically.
After uploading has been completed the file will be stored in a Rapidshare as '/gallery/video/cat1.mov'
You can easily get a download url after uploading:
```ruby
result = api.upload('/home/odiszapc/my_damn_cat.mov', :to => '/gallery/video', :as => 'cat1.mov')
result[:url]
```

By default, file is uploaded into the root folder:
```ruby
api.upload('/home/odiszapc/my_damn_humster.mov')
```

Rapidshare allows to store multiple files having equal names under the same folder. I believe this behaviour is absolutely wrong.
Therefore, each time upload performed it checks if the file with the given name already exists in a folder.
If it's true, the upload() just returns info about the existing file with the :already_exists? flag is set to true without any real upload being performed.
To force file being overwritten set the :overwrite parameter to true:

```ruby
api.upload '/home/odiszapc/my_damn_cat.mov',
    :to => '/gallery/video',
    :as => 'cat1.mov'

# No upload will be performed
api.upload '/home/odiszapc/my_damn_cat.mov',
    :to => '/gallery/video',
    :as => 'cat1.mov'

# With the following notation file will be uploaded with overwriting the existing one
api.upload '/home/odiszapc/my_damn_cat.mov',
    :to => '/gallery/video',
    :as => 'cat1.mov',
    :overwrite => true
```

Deleting files:
```ruby
api.remove_file('/putin/is/a/good/reason/to/live/abroad/ticket_to_Nicaragua.jpg')
```

Renaming files:
```ruby
api.rename_file('/foo/bar.rar', 'baz.rar')
```

Moving files:
```ruby
api.move_file('/foo/bar/baz.rar', :to => '/foo') # new file path: '/foo/baz.rar'
api.move_file('/foo/bar/baz.rar') # move to a root folder
```

Get the file ID:
```ruby
api.file_id('/foo/bar/baz.rar') # => <ID>
```

### Folders
As you note it's possible having a hierarchy of folders in your account.

Creating folder hierarchy:
```ruby
folder_id = api.add_folder 'a/b/c' # => <FOLDER ID>
```

Deleting folders:
```ruby
api.remove_folder('/a/b/c')
```

Moving folders:
```ruby
api.move_folder('/a/b/c', :to => '/a')
```
This moves the folder 'c' from the directory '/a/b/' and places it under the directory '/a'

You can get hierarchy of all the folders in account:
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

Note, that after the folder hierarchy is generated first time it's cached permanently to improve performance.

So, if you want to invalidate the cache just call the above method with trailing '!':
```ruby
api.folders_hierarchy!
```

If folder tree is inconsistent (orphans are found, see next paragraph for details) the Exception will be thrown when you perform #folders_hierarchy.
To automatically normalize the tree, call the method with the :consistent flag:
```ruby
api.folders_hierarchy :consistent => true
```
Be careful with the tree consistency, orphan folders may contain a critical data.

A more secure way to deal with folder consistency is to fix all orphans first and then generate folder tree:
```ruby
api.add_folder '/garbage'
api.move_orphans :to => '/garbage' # Collect all orphans and place them under the /garbage folder
tree = api.folders_hierarchy
```

Get the folder ID or path:
```ruby
id = api.folder_id('/foo/bar') # <ID>
api.folder_path(id) # '/foo/bar'
```

### Orphans
As mentioned earlier, the Rapidshare has its common problem: the chance of orphan folders to be appeared.
What does it mean? When you delete parent folder by its ID the folder will be deleted without any of its child folders being deleted.
For example, let we have the basic directory tree:
```
ROOT
`-a  <- Raw Rapidshare API allows you to delete JUST THIS folder, so hierarchy relation between folders will be lost and the folders 'c' and 'b' will became orphans
  `-b
    `-c
```

**Know-how:** orphan folders become invisible in your File Manager on the Rapidshare web site, so you may want to hide all the data in this way (stupid idea)

So, the best way to delete a directory tree without washing away consistency of account folder hierarchy is the following:
```ruby
api.remove_folder '/a' # This will delete all the child directories correctly
```

However, if you already have orphans in your account there is possible to fix them.
So ,the next method detects all orphan folders in your account and moves them into a specific folder:
```ruby
api.move_orphans :to => '/'
```

Or we can just delete all of them (be careful):
```ruby
api.remove_orphans!
```

### Account
You can null your account by deleting all the data stored inside:
```ruby
api.erase_all_data!
```

**Be careful with it, because you stake losing all your data**

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
6. Open beer