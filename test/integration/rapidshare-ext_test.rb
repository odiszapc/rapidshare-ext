# encoding: utf-8
require 'digest/md5'
require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class RapidshareExtTest < Test::Unit::TestCase

  def setup
    FakeWeb.allow_net_connect = true
    @rs = Rapidshare::API.new :cookie =>  ENV['RAPIDSHARE_COOKIE']
    @rs.erase_all_data!
  end

  context "Api" do
    should "Upload file" do
      assertion = ->(resp, size_local, digest_local, remote_filename) do
        assert_instance_of Hash, resp
        assert_kind_of Integer, resp[:id]
        assert_kind_of Integer, resp[:size]
        assert_equal size_local, resp[:size]
        assert_instance_of String, resp[:checksum]
        assert_match /[a-z0-9]{32}/, resp[:checksum]
        assert_equal digest_local, resp[:checksum]
        assert_instance_of String, resp[:url]
        assert_equal "https://rapidshare.com/files/#{resp[:id]}/#{URI::encode(remote_filename)}", resp[:url]
      end

      file_info_assertion = ->(info, file_id, digest_local, size_local, remote_filename, remote_dir) do
        assert_equal info[:filename], remote_filename
        assert_equal info[:id].to_i, file_id
        assert_equal info[:md5hex].downcase, digest_local
        assert_equal info[:realfolder].to_i, @rs.folder_id(remote_dir)
        assert_equal info[:size].to_i, size_local
      end

      local_path = File.expand_path(File.dirname(__FILE__) + "/../fixtures/files/upload1.txt")
      remote_filename = "upload_file_1.txt"
      remote_dir = "a/b/c"
      remote_path = "#{remote_dir}/#{remote_filename}"
      digest_local = Digest::MD5.hexdigest(File.read(local_path))
      size_local = File.size local_path

      # Initial upload
      response = @rs.upload local_path, :as => remote_filename, :to => remote_dir
      assertion.call response, size_local, digest_local, remote_filename
      assert_false response[:already_exists?]

      # Check file ID
      file_id = @rs.file_id remote_path
      assert_kind_of Integer, file_id
      assert_equal file_id, response[:id]

      # Check file info
      info = @rs.file_info remote_path
      file_info_assertion.call info, file_id, digest_local, size_local, remote_filename, remote_dir

      # Upload the same file again
      response = @rs.upload local_path, :as => remote_filename, :to => remote_dir
      assertion.call response, size_local, digest_local, remote_filename
      assert_true response[:already_exists?]

      # Rename file
      remote_filename_2 ="foo.txt"
      remote_path_2 = "#{remote_dir}/#{remote_filename_2}"
      @rs.rename_file remote_path, remote_filename_2
      info = @rs.file_info remote_path_2
      file_info_assertion.call info, @rs.file_id(remote_path_2), digest_local, size_local, remote_filename_2, remote_dir

      # Move file
      remote_dir_3 = "a/b"
      remote_path_3 = "#{remote_dir_3}/#{remote_filename_2}"
      @rs.move_file remote_path_2, :to => remote_dir_3

      info = @rs.file_info remote_path_3
      file_info_assertion.call info, @rs.file_id(remote_path_3), digest_local, size_local, remote_filename_2, remote_dir_3

      # Delete file
      @rs.remove_file remote_path_3

      info = @rs.file_info remote_path_3
      assert_nil info
    end

    should "Create folder" do
      folder_id = @rs.add_folder "a/b/c"
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy

      assert_equal 3, tree.count
      assert_equal "a/b/c", tree[folder_id][:path]
      assert_equal "a/b", tree[tree[folder_id][:parent]][:path]
      assert_equal "a", tree[tree[tree[folder_id][:parent]][:parent]][:path]
    end

    should "Move folder" do
      folder_id = @rs.add_folder "a/b/c"
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy

      assert_equal 3, tree.count
      assert_equal "a/b/c", tree[folder_id][:path]
      assert_equal "a/b", tree[tree[folder_id][:parent]][:path]
      assert_equal "a", tree[tree[tree[folder_id][:parent]][:parent]][:path]

      @rs.move_folder "a/b/c", :to => 'a'

      tree = @rs.reload!

      assert_equal 3, tree.count
      assert_equal "a/c", tree[folder_id][:path]
      assert_equal @rs.folder_id("a"), tree[folder_id][:parent]
    end

    should "Build folder tree" do
      # Create folder
      folder_id = @rs.add_folder "a/b/c"
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy

      # Validate tree
      assert_equal 3, tree.count
      assert_equal "a/b/c", tree[folder_id][:path]
      assert_equal "a/b", tree[tree[folder_id][:parent]][:path]
      assert_equal "a", tree[tree[tree[folder_id][:parent]][:parent]][:path]

      # Validate subtree
      sub_tree = @rs.folders_hierarchy :from => 'a/b'
      assert_equal 1, sub_tree.count
      assert_equal "c", sub_tree[folder_id][:path]
    end

    should "Remove folder" do
      folder_id = @rs.add_folder "a/b/c"
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy
      assert_equal 3, tree.count

      @rs.remove_folder "a/b/c"

      tree = @rs.folders_hierarchy!
      assert_equal 2, tree.count


      folder_id = @rs.add_folder "a/b/c"
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy!
      assert_equal 3, tree.count

      @rs.remove_folder "a"
      tree = @rs.folders_hierarchy!
      assert_equal 0, tree.count
    end

    should "Erase account" do
      folder_id = @rs.add_folder "a/b/c"
      assert_kind_of Integer, folder_id

      folder_ids = @rs.folders_hierarchy.keys
      assert_true folder_ids.count > 0

      # Delete all data from account
      @rs.erase_all_data!

      folder_ids = @rs.folders_hierarchy.keys
      assert_equal 0, folder_ids.count
    end
  end
end

