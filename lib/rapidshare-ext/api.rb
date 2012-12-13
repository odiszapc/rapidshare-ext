module Rapidshare
  module Ext
    module API

      FILE_COLUMNS = 'downloads,lastdownload,filename,size,serverid,type,x,y,realfolder,killdeadline,uploadtime,comment,md5hex,licids,sentby'

      # @param [String] path Folder name with absolute path to be created
      # @param [Hash] params
      # @return [Integer]
      #
      # Creates a folder in a Rapidshare virtual filesystem
      #
      #    api.add_folder('/a/b/c') #=> <Random folder ID from Rapidshare>, 1234 for example
      def add_folder(path, params = {})
        path = path_trim path

        @tree = folders_hierarchy
        i = 1
        parent = 0
        folder_id = nil
        while i <= path.split('/').count do
          base_path = path.split('/')[0,i].join('/')
          folder_id = self.folder_id base_path
          if folder_id
            parent = folder_id
            i += 1
          else
            # Create folder
            folder_name = path.split('/')[i-1]
            add_folder_params = {
              :name => folder_name,
              :parent => parent
            }.merge params

             # The following code deals with #{} because of rest client #to_i returns HTTP code
            folder_id = "#{addrealfolder(add_folder_params)}".to_i
            raise 'error while creating folder' if parent < 0
            @tree[folder_id] = {
              :parent => parent,
              :name => folder_name,
              :path => path_canonize((@tree[parent] || {})[:path].to_s + ('/' if @tree[parent]).to_s + folder_name)
            }
            parent = folder_id
            path == base_path + '/' + folder_name
            i += 1
            next
          end
        end
        folder_id
      end

      # Removes a specified folder
      #
      # @param [String] path
      # @param [Hash] params
      # @return [Array]
      #
      #    api.remove_folder('/a/b/c')
      def remove_folder(path, params = {})
        folder_id = self.folder_id path_trim(path)
        raise Exception, "Folder #{path} could not be found" if folder_id.nil?

        # TODO
        tree = folders_hierarchy :from => path
        tree.each_pair do |child_folder_id, data|
          delrealfolder_params = {
            :realfolder => child_folder_id
          }.merge params

          delrealfolder delrealfolder_params
          @tree.delete folder_id
        end

        params = {
          :realfolder => folder_id
        }.merge params

        delrealfolder params

        @tree.delete folder_id
      end

      # Moves folder into a specified one
      #
      # @param [String] source_path
      # @param [Hash] params
      #   :to => <destination folder path>, default: '/'
      #
      #    api.move_folder('/a/b/c', :to => '/a')
      def move_folder(source_path, params = {})
        dest_path = (params.delete(:to) || '/')
        source_folder_id = folder_id(source_path)
        dest_folder_id = folder_id(dest_path)

        params = {
          :realfolder => source_folder_id,
          :newparent => dest_folder_id
        }.merge params

        moverealfolder params

        @tree = folders_hierarchy
        @tree[source_folder_id][:parent] = dest_folder_id
        @tree[source_folder_id][:path] = path_canonize "#{folder_path(dest_folder_id)}/#{@tree[source_folder_id][:name]}"
        true
      end

      # Upload file to a specified folder
      #
      # @param [String] file_path
      # @param [Hash] params
      # <tt>:to</tt>::
      #   Folder to place uploaded file to,  default: '/'
      # <tt>:as</tt>::
      #   The name file will have in storage after it has been uploaded
      # <tt>:overwrite</tt>::
      #   Overwrite file if it already exists in the given folder
      #
      #    api.upload('/home/odiszapc/my_damn_cat.mov', :to => '/gallery/video', :as => 'cat1.mov')
      def upload(file_path, params = {})
        raise Exception unless File.exist? file_path
        dest_path = path_trim(params.delete(:to) || '/')
        folder_id = self.add_folder dest_path
        file_name = params.delete(:as) || File.basename(file_path)
        overwrite = params.delete :overwrite

        # Check file already exists within a folder
        listfiles_params = {
          :realfolder => folder_id,
          :filename => "#{file_name}",
          :fields => 'md5hex,size',
          :parser => :csv
        }
        listfiles_response = self.listfiles listfiles_params

        file_already_exists = ('NONE' != listfiles_response[0][0])
        remove_file "#{dest_path}/#{file_name}" if file_already_exists && overwrite

        # In case of file is not existing then upload it
        if !file_already_exists || overwrite
          upload_server = "rs#{self.nextuploadserver}.rapidshare.com"

          upload_params = {
            :server => upload_server,
            :folder => folder_id,
            :filename => file_name,
            :filecontent => file_path,
            :method => :post,
            :parser => :csv
          }.merge params

          resp = request(:upload, upload_params)
          raise Exception, "File uploading failed: #{resp.inspect}" unless "COMPLETE" == resp[0][0]

          id = resp[1][0].to_i
          md5_hash = resp[1][3]
          size = resp[1][2].to_i
          already_exists = false
        else
          id = listfiles_response[0][0].to_i
          md5_hash = listfiles_response[0][1]
          size = listfiles_response[0][2].to_i
          already_exists = true
        end

        raise Exception, "Invalid File ID: #{resp.inspect}" unless id
        raise Exception, "Invalid MD5 hash: #{resp.inspect}" unless md5_hash
        raise Exception, "Invalid File Size: #{resp.inspect}" unless size

        {
          :id         => id,
          :size       => size,
          :checksum   => md5_hash.downcase,
          :url        => "https://rapidshare.com/files/#{id}/#{URI::encode file_name}",
          :already_exists? => already_exists
        }
      end

      # Delete file
      #
      # @param [String] path
      # @param [Hash] params
      #
      #    api.remove_file('/putin/is/a/good/reason/to/live/abroad/ticket_to_Nikaragua.jpg')
      def remove_file(path, params = {})
        params = {
          :files => file_id(path).to_s
        }.merge params

        deletefiles params
      end

      # Rename file
      #
      # @param [String] remote_path
      # @param [String] name
      # @param [Hash] params
      #
      #    api.rename_file('/foo/bar.rar', 'baz.rar')
      def rename_file(remote_path, name, params = {})
        file_id = file_id remote_path

        params = {
          :fileid => file_id,
          :newname => name
        }.merge params

        renamefile params
        # TODO: duplicates check
      end

      # Moves file to a specified folder
      #
      # @param [String] remote_path
      # @param [Hash] params
      # <tt>:to</tt>::
      #   Destination folder path, default: '/'
      #
      #    api.move_file('/foo/bar/baz.rar', :to => '/foo')
      #    api.move_file('/foo/bar/baz.rar') # move to a root folder
      def move_file(remote_path, params = {})
        file_id = file_id remote_path
        dest_path = path_trim(params.delete(:to) || '/')

        params = {
          :files => file_id,
          :realfolder => folder_id(dest_path)
        }.merge params

        movefilestorealfolder params
      end

      # See #folders_hierarchy method
      def folders_hierarchy!(params = {})
        params[:force] = true
        folders_hierarchy params
      end

      alias :reload! :folders_hierarchy!

      # Build folders hierarchy in the following format:
      # {
      #   <folder ID> => {
      #     :parent => <parent folder ID>,
      #     :name => <folder name>,
      #     :path => <folder absolute path>
      #   },
      #   ...
      # }
      #
      # @param [Hash] params
      # <tt>:force</tt>::
      #   Invalidate cached tree, default: false
      #   After each call of this method the generated tree will be saved as cache
      #   to avoid unnecessary queries to be performed fpr a future calls
      # <tt>:validate</tt>::
      #   Validate tree after it has been generated, default: true
      # <tt>:consistent</tt>::
      #   Delete all found orphans, default: false
      #   Ignored if :validate is set to false
      def folders_hierarchy(params = {})
        force_load = params.delete :force
        from_folder_path = path_trim(params.delete(:from) || '/')
        remove_orphans = params.delete(:consistent)
        perform_validation = params.delete(:validate)
        perform_validation = true if perform_validation.nil?
        remove_orphans = false unless perform_validation

        if @tree && !force_load
          if from_folder_path.empty?
            return @tree
          else
            return slice_tree @tree, :from => from_folder_path
          end
        end

        return @tree if @tree && !force_load # TODO: about slices here (:from parameter)
        @tree = {}

        from_folder_id = folder_id from_folder_path
        raise Exception, "Folder #{from_folder_path} could not be found" if from_folder_id.nil?

        response = listrealfolders

        if 'NONE' == response
          @tree = {}
        else
          intermediate = response.split(' ').map do |str|
            params = str.split ','
            [params[0].to_i, {:parent => params[1].to_i, :name => params[2]}]
          end

          @tree = Hash[intermediate]
        end

        # Kill orphans
        remove_orphans! if remove_orphans

        @tree.each_pair do |folder_id, data|
          @tree[folder_id][:path] = folder_path folder_id
        end

        if perform_validation
          # Validate folder tree consistency
          @tree.each_pair do |folder_id, data|
            parent_id = data[:parent]
            if !parent_id.zero? && @tree[parent_id].nil?
              error = "Directory tree consistency error. Parent folder ##{data[:parent]} for the folder \"#{data[:path]}\" [#{folder_id}] could not be found"
              raise error
            end
          end
        end

        @tree = slice_tree @tree, :from => from_folder_path unless from_folder_path.empty?
        @tree
      end

      # Build tree relative to a specified folder
      # If the source tree is:
      # tree = {
      #   1 => {:parent => 0, :name => 'a', :path => 'a'},
      #   2 => {:parent => 1, :name => 'b', :path => 'a/b'},
      #   3 => {:parent => 2, :name => 'c', :path => 'a/b/c'},
      #   ...
      # }
      # slice_tree tree, :from => '/a'
      # Result will be as follows:
      # {
      #   2 => {:parent => 1, :name => 'b', :path => 'b'},
      #   3 => {:parent => 2, :name => 'c', :path => 'b/c'},
      #   ...
      # }
      def slice_tree(tree, params = {})
        from_folder_path = path_trim(params.delete(:from) || '/')

        result_tree = tree.dup

        unless from_folder_path == ''

          result_tree.keep_if do |folder_id, data|
            path_trim(data[:path]).start_with? "#{from_folder_path}/"
          end

          result_tree.each_pair do |folder_id, data|
            path = result_tree[folder_id][:path]
            result_tree[folder_id][:path] = path_canonize path_trim(path.gsub /#{from_folder_path.gsub /\//, '\/'}\//, '')
          end
        end

        result_tree
      end

      # Fix inconsistent folder tree (Yes, getting a broken folder hierarchy is possible with a stupid Rapidshare API)
      # by deleting orphan folders (folders with no parent folder), this folders are invisible in Rapidshare File Manager
      # So, this method deletes orphan folders
      def remove_orphans!
        @tree = folders_hierarchy :validate => false
        @tree.each_pair do |folder_id, data|
          @tree.delete_if do |folder_id, data|
            if orphan? folder_id
              delrealfolder :realfolder => folder_id
              true
            end
          end
        end
      end

      # Places all existing orphan folders under the specific folder
      # Orphan folder is a folder with non existing parent (yes, it's possible)
      #
      # Example:
      # move_orphans :to => '/'
      def move_orphans(params = {})
        new_folder = path_trim(params.delete(:to) || '/')
        gaps = detect_gaps

        if gaps.any?
          params = {
            :realfolder => gaps.join(','),
            :newparent => new_folder
          }.merge params
          moverealfolder params
        end
      end

      # Returns gap list between folders
      # See #gap? for example
      def detect_gaps
        @tree = folders_hierarchy :validate => false
        @tree.dup.keep_if do |folder_id, data|
          gap? folder_id # This is wrong
        end.keys
      end

      # The name speaks for itself
      # WARNING!!! All data will be lost!!!
      # Use it carefully
      def erase_all_data!
        @tree = folders_hierarchy! :validate => false
        @tree.keys.each do |folder_id|
          delrealfolder :realfolder => folder_id
        end
        folders_hierarchy!
      end

      # Check if folder with given id placed on the bottom of folder hierarchy
      def root_folder?(folder_id)
        @tree = folders_hierarchy :validate => false
        return false if @tree[folder_id].nil?
        @tree[folder_id][:parent].zero?
      end

      # Check if the given folder has no parent
      def gap?(folder_id)
        @tree = folders_hierarchy :validate => false
        parent_id = @tree[folder_id][:parent]
        @tree[parent_id].nil?
      end

      # Check if folder has any gaps in it hierarchy
      # For example we have the following hierarchy:
      #
      # ROOT
      # `-a  <- if we remove just this folder then the folder 'c' and 'b' will become orphans
      #   `-b
      #     `-c
      def orphan?(folder_id)
        @tree = folders_hierarchy :validate => false
        return false if @tree[folder_id].nil?
        parent_id = @tree[folder_id][:parent]
        return false if root_folder? folder_id
        return true if gap? folder_id
        orphan?(parent_id)
      end

      # Translate folder ID to a human readable path
      #
      #    api.folder_path(123) # -> 'foo/bar/baz'
      def folder_path(folder_id)
        @tree = folders_hierarchy

        folder_data = @tree[folder_id] || {:parent => 0, :name => '<undefined>', :path => '<undefined>'}

        parent_id = folder_data[:parent]
        path = (folder_path(parent_id) if parent_id.nonzero?).to_s + ('/' if parent_id.nonzero?).to_s + folder_data[:name]
        parent_id.zero? ? "/#{path}" : path
      end

      # Get folder ID by path
      #
      #    api.folder_id('foo/bar/baz') # -> 123
      def folder_id(folder_path)
        folder_path = path_trim(folder_path)
        return 0 if folder_path.empty?

        @tree = folders_hierarchy
        index = @tree.find_index do |folder_id, data|
          path_trim(data[:path]) == path_trim(folder_path)
        end
        @tree.keys[index] unless index.nil?
      end

      # Get file info in the following format:
      #
      # {
      #   :downloads,
      #   :lastdownload,
      #   :filename,
      #   :size,
      #   :serverid,
      #   :type,
      #   :x,
      #   :y,
      #   :realfolder,
      #   :killdeadline,
      #   :uploadtime,
      #   :comment,
      #   :md5hex,
      #   :licids,
      #   :sentby
      # }
      # See the http://images.rapidshare.com/apidoc.txt for more details
      def file_info(file_path, params = {})
        folder_path = File.dirname file_path
        file_name = File.basename file_path

        folder_id = folder_id folder_path

        listfiles_params = {
          :realfolder => folder_id,
          :filename => "#{file_name}",
          :fields => FILE_COLUMNS,
          :parser => :csv
        }.merge params

        resp = listfiles(listfiles_params)[0]
        return nil if 'NONE' == resp[0]

        response = {}

        fields = listfiles_params[:fields].split(',')
        fields.unshift 'id'
        fields.each_with_index do |value, index|
          response[value.to_sym] = resp[index]
        end

        response[:url] = "https://rapidshare.com/files/#{response[:id]}/#{URI::encode response[:filename]}" if response[:filename]

        response
      end

      # Returns file ID by absolute path
      #
      #    api.file_id('foo/bar/baz/file.rar') # => <FILE_ID>
      def file_id(file_path, params = {})
        params[:fields] = ''
        file_info = file_info file_path, params
        (file_info || {})[:id].to_i
      end

      protected

      def path_trim(path)
        path.gsub(/\A\/+/, '').gsub(/\/+\Z/, '')
      end

      def path_canonize(path)
        '/' + path_trim(path)
      end
    end
  end
end