require 'test_helper'

class RapidshareExtTest < Test::Unit::TestCase
  context 'Interface' do
    should 'Respond to certain methods' do
      assert_respond_to @rs, :add_folder
      assert_respond_to @rs, :remove_folder
      assert_respond_to @rs, :move_folder
      assert_respond_to @rs, :upload
      assert_respond_to @rs, :remove_file
      assert_respond_to @rs, :rename_file
      assert_respond_to @rs, :folders_hierarchy
      assert_respond_to @rs, :folders_hierarchy!
      assert_respond_to @rs, :slice_tree
      assert_respond_to @rs, :remove_orphans!
      assert_respond_to @rs, :move_orphans
      assert_respond_to @rs, :detect_gaps
      assert_respond_to @rs, :erase_all_data!
      assert_respond_to @rs, :root_folder?
      assert_respond_to @rs, :gap?
      assert_respond_to @rs, :orphan?
      assert_respond_to @rs, :folder_path
      assert_respond_to @rs, :folder_id
      assert_respond_to @rs, :file_info
      assert_respond_to @rs, :file_id
    end
  end
end