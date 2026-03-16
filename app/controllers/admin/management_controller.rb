class Admin::ManagementController < Admin::BaseController
  class_attribute :submission_log_dir, default: Rails.root.join("log")

  def show
    @entrant_count = Entrant.count
    @draw_exists = RaffleDraw.exists?
  end

  def reset_drawing
    ActiveRecord::Base.transaction do
      Entrant.where(eligibility_status: %w[winner alternate_winner])
             .update_all(eligibility_status: "eligible")
      RaffleDraw.delete_all
    end
    redirect_to admin_management_path, notice: "Drawing has been reset. All winners restored to eligible."
  end

  def populate_demo
    DemoPopulator.populate!
    redirect_to admin_management_path, notice: "300 demo entrants created."
  rescue DemoPopulator::DatabaseNotEmpty
    redirect_to admin_management_path, alert: "Cannot populate: entrants already exist. Clear the database first."
  end

  def clear_entrants
    unless params[:confirmation] == "reset"
      redirect_to admin_management_path, alert: "Confirmation did not match. Type 'reset' to confirm."
      return
    end

    timestamp_submission_log

    ActiveRecord::Base.transaction do
      RaffleDraw.delete_all
      Entrant.delete_all
    end

    redirect_to admin_management_path, notice: "All entrants and draw history cleared. Logs preserved."
  end

  def factory_reset
    unless params[:confirmation] == "delete everything"
      redirect_to admin_management_path, alert: "Confirmation did not match. Type 'delete everything' to confirm."
      return
    end

    ActiveRecord::Base.transaction do
      RaffleDraw.delete_all
      Entrant.delete_all
    end

    # Delete all submission logs
    Dir.glob(self.class.submission_log_dir.join("submissions*.jsonl")).each { |f| File.delete(f) }

    # Delete USB backup files if mounted
    usb_mount = UsbBackup.find_usb_mount
    if usb_mount
      Dir.glob(File.join(usb_mount, "submissions*.jsonl")).each { |f| File.delete(f) }
      db_backup = File.join(usb_mount, "raffle.sqlite3")
      File.delete(db_backup) if File.exist?(db_backup)
    end

    redirect_to admin_management_path, notice: "Factory reset complete. All data, logs, and backups deleted."
  end

  private

  def timestamp_submission_log
    log_path = self.class.submission_log_dir.join("submissions.jsonl")
    return unless File.exist?(log_path) && File.size(log_path) > 0

    timestamp = Time.current.strftime("%Y%m%d-%H%M%S")
    archive_path = self.class.submission_log_dir.join("submissions-#{timestamp}.jsonl")
    File.rename(log_path, archive_path)
  end
end
