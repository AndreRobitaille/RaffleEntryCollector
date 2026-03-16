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
    log_dir = Dir.mktmpdir("usb_log_test")
    log_path = Pathname.new(File.join(log_dir, "submissions.jsonl"))
    File.write(log_path, "{\"test\": true}\n")

    UsbBackup.stub(:backup_database, true) do
      UsbBackup.stub(:log_path, log_path) do
        result = UsbBackup.perform(target_dir: @backup_dir)
        assert result[:success]
        assert File.exist?(File.join(@backup_dir, "submissions.jsonl"))
      end
    end
  ensure
    FileUtils.rm_rf(log_dir)
  end

  test "succeeds without JSONL log file" do
    log_path = Pathname.new("/tmp/nonexistent_#{Process.pid}_submissions.jsonl")

    UsbBackup.stub(:backup_database, true) do
      UsbBackup.stub(:log_path, log_path) do
        result = UsbBackup.perform(target_dir: @backup_dir)
        assert result[:success]
        assert_not File.exist?(File.join(@backup_dir, "submissions.jsonl"))
      end
    end
  end

  test "returns failure when find_usb_mount returns nil" do
    UsbBackup.stub(:find_usb_mount, nil) do
      result = UsbBackup.perform
      assert_not result[:success]
      assert_equal "No backup target found", result[:error]
    end
  end

  test "uses find_usb_mount result as target_dir when not specified" do
    UsbBackup.stub(:find_usb_mount, @backup_dir) do
      UsbBackup.stub(:backup_database, true) do
        result = UsbBackup.perform
        assert result[:success]
      end
    end
  end

  test "overwrites existing backup file without error" do
    File.write(File.join(@backup_dir, "raffle.sqlite3"), "old data")

    UsbBackup.stub(:backup_database, true) do
      result = UsbBackup.perform(target_dir: @backup_dir)
      assert result[:success]
    end
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

  test "returns failure when sqlite3 backup command fails" do
    # Use a non-writable path to force sqlite3 backup failure
    readonly_dir = File.join(@backup_dir, "readonly")
    Dir.mkdir(readonly_dir)
    File.chmod(0o444, readonly_dir)

    result = UsbBackup.perform(target_dir: readonly_dir)
    assert_not result[:success]
    assert_equal "sqlite3 backup command failed", result[:error]
  ensure
    File.chmod(0o755, readonly_dir) if File.exist?(readonly_dir)
  end
end
