# encoding: utf-8
require 'digest/md5'
require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class RapidshareExtTest < Test::Unit::TestCase

  def setup
    FakeWeb.allow_net_connect = true
    @rs = Rapidshare::API.new :cookie =>  ENV['RAPIDSHARE_COOKIE']

    account = @rs.get_account_details

    # Check the account is the actually we wanted, because it will be erased in the next step
    assert_equal ENV['RAPIDSHARE_USERNAME'], account[:username]
    assert_equal ENV['RAPIDSHARE_EMAIL'], account[:email]
    assert_equal ENV['RAPIDSHARE_ACCOUNT_ID'], account[:accountid]

    @rs.erase_all_data!

    @download_dir = File.expand_path(File.dirname(__FILE__) + '/../../tmp')
    File.delete "#@download_dir/file1.txt" if File.exist? "#@download_dir/file1.txt"
    File.delete "#@download_dir/file2.txt" if File.exist? "#@download_dir/file2.txt"
    File.delete "#@download_dir/upload_file_1.txt" if File.exist? "#@download_dir/upload_file_1.txt"

    @upload_file_1 = File.expand_path(File.dirname(__FILE__) + '/../fixtures/files/upload1.txt')
    @upload_file_1_md5 = Digest::MD5.hexdigest(File.read(@upload_file_1))
    @upload_file_1_size = File.size @upload_file_1

    @upload_file_2 = File.expand_path(File.dirname(__FILE__) + '/../fixtures/files/upload2.txt')
    @upload_file_2_md5 = Digest::MD5.hexdigest(File.read(@upload_file_2))
    @upload_file_2_size = File.size @upload_file_2
  end

  context 'Api' do
    should 'upload file' do
      upload_assertion = ->(resp, size_local, digest_local, remote_filename) do
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

      remote_filename = 'upload_file_1.txt'
      remote_dir = 'a/b/c'
      remote_path = "#{remote_dir}/#{remote_filename}"

      # Initial upload
      response = @rs.upload @upload_file_1, :as => remote_filename, :to => remote_dir
      upload_assertion.call response, @upload_file_1_size, @upload_file_1_md5, remote_filename
      assert_false response[:already_exists?]

      # Check file ID
      file_id = @rs.file_id remote_path
      assert_kind_of Integer, file_id
      assert_equal file_id, response[:id]

      # Check file info
      info = @rs.file_info remote_path
      assert_not_nil info
      assert_equal info[:filename], remote_filename
      assert_equal info[:id].to_i, file_id
      assert_equal info[:size].to_i, @upload_file_1_size
      assert_equal info[:md5hex].downcase, @upload_file_1_md5
      assert_equal info[:realfolder].to_i, @rs.folder_id(remote_dir)

      # Upload the same file again
      response = @rs.upload @upload_file_1, :to => remote_dir, :as => remote_filename
      assert_true response[:already_exists?]
      upload_assertion.call response, @upload_file_1_size, @upload_file_1_md5, remote_filename

      # Upload another file under the same path but with overwriting the existing one
      response = @rs.upload @upload_file_2,
                            :to => remote_dir,
                            :as => remote_filename,
                            :overwrite => true

      assert_false response[:already_exists?]
      upload_assertion.call response, @upload_file_2_size, @upload_file_2_md5, remote_filename
    end

    should 'download file' do
      @rs.upload @upload_file_1, :to => '/a/b/c', :as => 'upload_file_1.txt'
      assert_not_nil @rs.file_info('/a/b/c/upload_file_1.txt')

      @rs.download '/a/b/c/upload_file_1.txt', :downloads_dir => @download_dir, :save_as => 'file1.txt'
      assert_path_exist "#@download_dir/file1.txt"
      assert_equal @upload_file_1_size, File.size("#@download_dir/file1.txt")
      assert_equal @upload_file_1_md5, Digest::MD5.hexdigest(File.read("#@download_dir/file1.txt"))

      # Download with default :save_as
      @rs.download '/a/b/c/upload_file_1.txt', :downloads_dir => @download_dir
      assert_path_exist "#@download_dir/upload_file_1.txt"
      assert_equal @upload_file_1_size, File.size("#@download_dir/upload_file_1.txt")
      assert_equal @upload_file_1_md5, Digest::MD5.hexdigest(File.read("#@download_dir/upload_file_1.txt"))

      # Download by http url
      download_url = @rs.file_info('/a/b/c/upload_file_1.txt')[:url]
      @rs.download download_url, :downloads_dir => @download_dir, :save_as => 'file2.txt'
      assert_path_exist "#@download_dir/file2.txt"
      assert_equal @upload_file_1_size, File.size("#@download_dir/file2.txt")
      assert_equal @upload_file_1_md5, Digest::MD5.hexdigest(File.read("#@download_dir/file2.txt"))
    end

    should 'rename file' do
      @rs.upload @upload_file_1, :to => '/a/b/c', :as => 'upload_file_1.txt'
      assert_not_nil @rs.file_info('/a/b/c/upload_file_1.txt')

      @rs.rename_file '/a/b/c/upload_file_1.txt', 'file_2.txt'
      info = @rs.file_info '/a/b/c/file_2.txt'

      assert_not_nil info
      assert_equal info[:filename], 'file_2.txt'
      assert_equal info[:realfolder].to_i, @rs.folder_id('/a/b/c')
      assert_equal info[:size].to_i, @upload_file_1_size
      assert_equal info[:md5hex].downcase, @upload_file_1_md5
    end

    should 'move file' do
      @rs.upload @upload_file_1, :to => '/a/b/c', :as => 'upload_file_1.txt'
      assert_not_nil @rs.file_info('/a/b/c/upload_file_1.txt')

      @rs.move_file '/a/b/c/upload_file_1.txt', :to => '/a/b'
      assert_nil @rs.file_info('/a/b/c/upload_file_1.txt')

      info = @rs.file_info '/a/b/upload_file_1.txt'
      assert_not_nil info
      assert_equal info[:filename], 'upload_file_1.txt'
      assert_equal info[:realfolder].to_i, @rs.folder_id('/a/b')
      assert_equal info[:size].to_i, @upload_file_1_size
      assert_equal info[:md5hex].downcase, @upload_file_1_md5
    end

    should 'delete file' do
      @rs.upload @upload_file_1, :to => '/a/b/c', :as => 'upload_file_1.txt'
      assert_not_nil @rs.file_info('/a/b/c/upload_file_1.txt')

      @rs.remove_file '/a/b/c/upload_file_1.txt'
      assert_nil @rs.file_info('/a/b/c/upload_file_1.txt')
    end

    should 'folder id <=> path conversions' do
      @rs.add_folder '/a/b/c'
      id = @rs.folder_id('/a/b/c')
      assert_equal '/a/b/c', @rs.folder_path(id)
    end

    should 'create folder' do
      folder_id = @rs.add_folder 'a/b/c'
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy

      assert_equal 3, tree.count
      assert_equal '/a/b/c', tree[folder_id][:path]
      assert_equal '/a/b', tree[tree[folder_id][:parent]][:path]
      assert_equal '/a', tree[tree[tree[folder_id][:parent]][:parent]][:path]
    end

    should 'move folder' do
      folder_id = @rs.add_folder '/a/b/c'
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy

      assert_equal 3, tree.count
      assert_equal '/a/b/c', tree[folder_id][:path]
      assert_equal '/a/b', tree[tree[folder_id][:parent]][:path]
      assert_equal '/a', tree[tree[tree[folder_id][:parent]][:parent]][:path]

      @rs.move_folder '/a/b/c', :to => 'a'

      tree = @rs.reload!

      assert_equal 3, tree.count
      assert_equal '/a/c', tree[folder_id][:path]
      assert_equal @rs.folder_id('/a'), tree[folder_id][:parent]
    end

    should 'remove folder' do
      folder_id = @rs.add_folder 'a/b/c'
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy
      assert_equal 3, tree.count

      @rs.remove_folder '/a/b/c'

      tree = @rs.folders_hierarchy!
      assert_equal 2, tree.count


      folder_id = @rs.add_folder '/a/b/c'
      assert_kind_of Integer, folder_id
      assert_not_equal 0, folder_id
      tree = @rs.folders_hierarchy!
      assert_equal 3, tree.count

      @rs.remove_folder '/a'
      tree = @rs.folders_hierarchy!
      assert_equal 0, tree.count
    end


    should 'build folders tree' do
      # Create folders
      folder_a_id = @rs.add_folder '/a'
      assert_kind_of Integer, folder_a_id
      assert_not_equal 0, folder_a_id

      folder_b_id = @rs.add_folder '/a/b'
      assert_kind_of Integer, folder_b_id
      assert_not_equal 0, folder_b_id

      folder_c_id = @rs.add_folder '/a/b/c'
      assert_kind_of Integer, folder_c_id
      assert_not_equal 0, folder_c_id


      tree = @rs.folders_hierarchy
      # Validate tree
      assert_equal 3, tree.count

      assert_equal 'a', tree[folder_a_id][:name]
      assert_equal '/a', tree[folder_a_id][:path]
      assert_equal 0, tree[folder_a_id][:parent]

      assert_equal 'b', tree[folder_b_id][:name]
      assert_equal '/a/b', tree[folder_b_id][:path]
      assert_equal folder_a_id, tree[folder_b_id][:parent]

      assert_equal 'c', tree[folder_c_id][:name]
      assert_equal '/a/b/c', tree[folder_c_id][:path]
      assert_equal folder_b_id, tree[folder_c_id][:parent]

      # Validate subtree
      sub_tree = @rs.folders_hierarchy :from => '/a/b'
      assert_equal 1, sub_tree.count
      assert_equal '/c', sub_tree[folder_c_id][:path]
      assert_equal 'c', sub_tree[folder_c_id][:name]
      assert_equal folder_b_id, sub_tree[folder_c_id][:parent]
    end

    should 'erase all account data' do
      folder_id = @rs.add_folder '/a/b/c'
      assert_kind_of Integer, folder_id

      folder_ids = @rs.folders_hierarchy.keys
      assert_true folder_ids.count > 0

      # Delete all data from account
      @rs.erase_all_data!

      folder_ids = @rs.folders_hierarchy.keys
      assert_equal 0, folder_ids.count
    end

    should 'move orphans' do
      # Create folders
      folder_a_id = @rs.add_folder '/a'
      assert_kind_of Integer, folder_a_id
      assert_not_equal 0, folder_a_id

      folder_b_id = @rs.add_folder '/a/b'
      assert_kind_of Integer, folder_b_id
      assert_not_equal 0, folder_b_id

      folder_c_id = @rs.add_folder '/a/b/c'
      assert_kind_of Integer, folder_c_id
      assert_not_equal 0, folder_c_id

      @rs.reload!

      assert_true @rs.root_folder? folder_a_id
      assert_false @rs.root_folder? folder_b_id
      assert_false @rs.root_folder? folder_c_id

      assert_false @rs.orphan? folder_a_id
      assert_false @rs.orphan? folder_b_id
      assert_false @rs.orphan? folder_c_id

      # Delete just folder '/a' to accomplish tree inconsistency
      @rs.delrealfolder :realfolder => folder_a_id
      @rs.reload! :validate => false

      assert_equal [folder_b_id], @rs.detect_gaps

      assert_false @rs.root_folder? folder_a_id
      assert_false @rs.root_folder? folder_b_id
      assert_false @rs.root_folder? folder_c_id

      assert_false @rs.orphan? folder_a_id
      assert_true @rs.orphan? folder_b_id
      assert_true @rs.orphan? folder_c_id

      # Move orphan folders to root folder
      @rs.move_orphans :to => '/'

      hierarchy_expected = {
        folder_c_id => {:name=>'c', :parent => folder_b_id, :path => '/b/c'},
        folder_b_id => {:name=>'b', :parent => 0, :path => '/b'},
      }
      assert_equal hierarchy_expected, @rs.folders_hierarchy!
    end

    should 'delete orphans' do
      # Create folders
      folder_a_id = @rs.add_folder '/a'
      assert_kind_of Integer, folder_a_id
      assert_not_equal 0, folder_a_id

      folder_b_id = @rs.add_folder '/a/b'
      assert_kind_of Integer, folder_b_id
      assert_not_equal 0, folder_b_id

      folder_c_id = @rs.add_folder '/a/b/c'
      assert_kind_of Integer, folder_c_id
      assert_not_equal 0, folder_c_id

      @rs.reload!

      assert_true @rs.root_folder? folder_a_id
      assert_false @rs.root_folder? folder_b_id
      assert_false @rs.root_folder? folder_c_id

      assert_false @rs.orphan? folder_a_id
      assert_false @rs.orphan? folder_b_id
      assert_false @rs.orphan? folder_c_id

      # Delete just folder '/a' to accomplish tree inconsistency
      @rs.delrealfolder :realfolder => folder_a_id
      @rs.reload! :validate => false

      @rs.remove_orphans!

      hierarchy_expected = {
        folder_c_id => {:name=>'c', :parent => folder_b_id, :path => '/b/c'},
        folder_b_id => {:name=>'b', :parent => 0, :path => '/b'},
      }
      assert_equal ({}), @rs.folders_hierarchy!
    end

    should 'work with invalid tree' do
      # Create folders
      folder_a_id = @rs.add_folder '/a'
      assert_kind_of Integer, folder_a_id
      assert_not_equal 0, folder_a_id

      folder_b_id = @rs.add_folder '/a/b'
      assert_kind_of Integer, folder_b_id
      assert_not_equal 0, folder_b_id

      folder_c_id = @rs.add_folder '/a/b/c'
      assert_kind_of Integer, folder_c_id
      assert_not_equal 0, folder_c_id

      @rs.reload!

      assert_true @rs.root_folder? folder_a_id
      assert_false @rs.root_folder? folder_b_id
      assert_false @rs.root_folder? folder_c_id

      assert_false @rs.orphan? folder_a_id
      assert_false @rs.orphan? folder_b_id
      assert_false @rs.orphan? folder_c_id

      # Delete just folder '/a' to accomplish tree inconsistency
      @rs.delrealfolder :realfolder => folder_a_id

      msg = "Directory tree consistency error. Parent folder ##{folder_a_id} for the folder \"/<undefined>/b\" [#{folder_b_id}] could not be found"
      assert_raise_message(msg) do
        @rs.reload! :validate => true
      end

      # Remedy
      @rs.erase_all_data!
    end
  end
end

