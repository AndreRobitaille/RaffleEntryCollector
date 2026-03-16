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

  WINNERS_CSV_HEADERS = %w[draw_type first_name last_name email company job_title drawn_at].freeze

  def index
    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.count
    @excluded_count = Entrant.where(eligibility_status: %w[excluded_admin duplicate_review]).count
    @winners_count = RaffleDraw.count
  end

  def download
    if export_type == "winners"
      csv_data = generate_winners_csv
      filename = "raffle-winners-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
    else
      entries = export_scope
      csv_data = generate_csv(entries)
      filename = "raffle-entries-#{export_type}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
    end

    send_data csv_data, filename: filename, type: "text/csv", disposition: "attachment"
  end

  private

  def export_type
    %w[eligible all winners].include?(params[:type]) ? params[:type] : "eligible"
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

  def generate_winners_csv
    draws = RaffleDraw.includes(:winner).order(id: :asc)
    alternate_index = 0

    CSV.generate do |csv|
      csv << WINNERS_CSV_HEADERS
      draws.each do |draw|
        label = if draw.draw_type == "winner"
          "Winner"
        else
          alternate_index += 1
          "Alternate ##{alternate_index}"
        end

        entrant = draw.winner
        csv << [
          label,
          entrant.first_name,
          entrant.last_name,
          entrant.email,
          entrant.company,
          entrant.job_title,
          draw.created_at
        ]
      end
    end
  end
end
