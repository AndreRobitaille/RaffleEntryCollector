require "test_helper"

class UsbBackupTest < ActiveSupport::TestCase
  setup do
    @backup_dir = Dir.mktmpdir("usb_backup_test")
    @status_file = Pathname.new(File.join(@backup_dir, "backup_status.json"))
    UsbBackup.status_file = @status_file
  end

  teardown do
    UsbBackup.status_file = UsbBackup::DEFAULT_STATUS_FILE
    FileUtils.rm_rf(@backup_dir)
  end

  test "performs backup when target dir exists" do
    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:success]
    assert File.exist?(File.join(@backup_dir, "raffle.sqlite3"))
  end

  test "copies JSONL log if it exists" do
    log_path = Rails.root.join("log", "submissions.jsonl")
    File.write(log_path, "{\"test\": true}\n")

    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:success]
    assert File.exist?(File.join(@backup_dir, "submissions.jsonl"))
  ensure
    log_path.delete if log_path.exist?
  end

  test "returns failure when target dir does not exist" do
    result = UsbBackup.perform(target_dir: "/nonexistent/path")
    assert_not result[:success]
  end

  test "records backup timestamp" do
    UsbBackup.perform(target_dir: @backup_dir)
    status = UsbBackup.last_status
    assert status[:last_backup_at].present?
    assert status[:success]
  end

  test "returns backed_up_at timestamp on success" do
    result = UsbBackup.perform(target_dir: @backup_dir)
    assert result[:backed_up_at].present?
  end

  test "last_status returns empty hash when no backup has run" do
    assert_equal({}, UsbBackup.last_status)
  end
end
