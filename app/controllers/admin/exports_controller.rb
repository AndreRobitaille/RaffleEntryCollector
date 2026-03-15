require "csv"

class Admin::ExportsController < Admin::BaseController
  INTEREST_AREA_COLUMNS = {
    "Penetration Testing" => "penetration_testing",
    "Red Team / Adversary Simulation" => "red_team",
    "Application Security" => "app_security",
    "Cloud & Infrastructure Security" => "cloud_infra_security",
    "Hardware / IoT Security" => "hardware_iot_security",
    "Space Systems Security" => "space_systems_security",
    "Security Training" => "security_training"
  }.freeze

  CSV_FIXED_HEADERS = %w[first_name last_name email company job_title created_at eligibility_status].freeze

  def index
    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.count
  end

  def download
    entries = export_scope
    csv_data = generate_csv(entries)
    filename = "raffle-entries-#{export_type}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"

    send_data csv_data, filename: filename, type: "text/csv", disposition: "attachment"
  end

  private

  def export_type
    %w[eligible all].include?(params[:type]) ? params[:type] : "eligible"
  end

  def export_scope
    export_type == "all" ? Entrant.all : Entrant.eligible
  end

  def generate_csv(entries)
    headers = CSV_FIXED_HEADERS + INTEREST_AREA_COLUMNS.values

    CSV.generate do |csv|
      csv << headers
      entries.find_each do |entrant|
        row = [
          entrant.first_name,
          entrant.last_name,
          entrant.email,
          entrant.company,
          entrant.job_title,
          entrant.created_at,
          entrant.eligibility_status
        ]
        INTEREST_AREA_COLUMNS.each_key do |area_name|
          row << (entrant.interest_areas.include?(area_name) ? 1 : 0)
        end
        csv << row
      end
    end
  end
end
