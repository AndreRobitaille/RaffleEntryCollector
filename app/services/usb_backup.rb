require "open3"

class UsbBackup
  DEFAULT_STATUS_FILE = Rails.root.join("tmp", "backup_status.json")
  USB_LABEL = "RAFFLE_BACKUP"

  class_attribute :status_file, default: DEFAULT_STATUS_FILE

  def self.perform(target_dir: find_usb_mount)
    return failure("No backup target found") unless target_dir && Dir.exist?(target_dir.to_s)

    db_path = ActiveRecord::Base.connection_db_config.database
    backup_db_path = File.join(target_dir, "raffle.sqlite3")

    unless backup_database(db_path, backup_db_path)
      return failure("sqlite3 backup command failed")
    end

    if log_path.exist?
      FileUtils.cp(log_path, File.join(target_dir, "submissions.jsonl"))
    end

    record_status(success: true)
    { success: true, backed_up_at: Time.current }
  rescue => e
    record_status(success: false, error: e.message)
    failure(e.message)
  end

  def self.last_status
    path = Pathname.new(status_file)
    return {} unless path.exist?
    JSON.parse(path.read, symbolize_names: true)
  end

  def self.log_path
    Rails.root.join("log", "submissions.jsonl")
  end

  def self.find_usb_mount
    stdout, status = Open3.capture2("findmnt", "-rn", "-S", "LABEL=#{USB_LABEL}", "-o", "TARGET")
    mount_point = stdout.strip
    status.success? && !mount_point.empty? ? mount_point : nil
  end

  def self.backup_database(db_path, backup_db_path)
    system("sqlite3", db_path, ".backup '#{backup_db_path}'")
  end
  private_class_method :backup_database

  def self.failure(message)
    { success: false, error: message }
  end
  private_class_method :failure

  def self.record_status(success:, error: nil)
    status = { success: success, last_backup_at: Time.current.iso8601, error: error }
    File.write(self.status_file, status.to_json)
  end
  private_class_method :record_status
end
