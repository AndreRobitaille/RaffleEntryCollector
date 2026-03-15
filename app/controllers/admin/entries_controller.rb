class Admin::EntriesController < Admin::BaseController
  SORTABLE_COLUMNS = %w[first_name last_name company eligibility_status email created_at].freeze

  def index
    @entrants = Entrant.all

    if params[:q].present?
      sanitized = Entrant.sanitize_sql_like(params[:q])
      query = "%#{sanitized}%"
      @entrants = @entrants.where(
        "first_name LIKE ? OR last_name LIKE ? OR email LIKE ? OR company LIKE ?",
        query, query, query, query
      )
    end

    default_sort = params[:q].present? ? "last_name" : "company"
    sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : default_sort
    sort_direction = params[:dir] == "desc" ? "desc" : "asc"
    @entrants = @entrants.order("#{sort_column} #{sort_direction}")

    @sort_column = sort_column
    @sort_direction = sort_direction
    @query = params[:q]

    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.count
    @excluded_count = Entrant.excluded.count
    @duplicate_count = Entrant.duplicates.count
  end

  def show
    @entrant = Entrant.find(params[:id])
  end

  def exclude
    @entrant = Entrant.find(params[:id])
    if @entrant.eligibility_status.in?(%w[winner alternate_winner])
      redirect_to admin_entry_path(@entrant), alert: "Cannot modify a winner's status."
      return
    end
    @entrant.update_columns(
      eligibility_status: "excluded_admin",
      exclusion_reason: params[:exclusion_reason].presence,
      updated_at: Time.current
    )
    redirect_to admin_entry_path(@entrant), notice: "Entry excluded."
  end

  def reinstate
    @entrant = Entrant.find(params[:id])
    if @entrant.eligibility_status.in?(%w[winner alternate_winner])
      redirect_to admin_entry_path(@entrant), alert: "Cannot modify a winner's status."
      return
    end
    @entrant.update_columns(
      eligibility_status: "reinstated_admin",
      exclusion_reason: nil,
      updated_at: Time.current
    )
    redirect_to admin_entry_path(@entrant), notice: "Entry reinstated."
  end
end
