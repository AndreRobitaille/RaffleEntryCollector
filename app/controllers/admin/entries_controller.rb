class Admin::EntriesController < Admin::BaseController
  PER_PAGE = 50
  SORTABLE_COLUMNS = %w[first_name last_name company eligibility_status email created_at].freeze

  def index
    # Restore from session if no explicit params
    if params[:q].nil? && params[:sort].nil? && params[:dir].nil?
      params[:q] = session[:admin_entries_search] if session[:admin_entries_search].present?
      params[:sort] = session[:admin_entries_sort] if session[:admin_entries_sort].present?
      params[:dir] = session[:admin_entries_direction] if session[:admin_entries_direction].present?
    end

    # Store current state in session
    session[:admin_entries_search] = params[:q].presence
    session[:admin_entries_sort] = params[:sort].presence
    session[:admin_entries_direction] = params[:dir].presence

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

    @backup_status = UsbBackup.last_status

    @page = [ params.fetch(:page, 1).to_i, 1 ].max
    @total_pages = (@entrants.count / PER_PAGE.to_f).ceil
    @total_pages = 1 if @total_pages < 1
    @entrants = @entrants.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
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
    @entrant.update!(
      eligibility_status: "excluded_admin",
      exclusion_reason: params[:exclusion_reason].presence
    )
    redirect_to admin_entry_path(@entrant), notice: "Entry excluded."
  end

  def reinstate
    @entrant = Entrant.find(params[:id])
    unless @entrant.eligibility_status.in?(%w[excluded_admin duplicate_review])
      redirect_to admin_entry_path(@entrant), alert: "Cannot reinstate from this status."
      return
    end
    @entrant.update!(
      eligibility_status: "reinstated_admin",
      exclusion_reason: nil
    )
    redirect_to admin_entry_path(@entrant), notice: "Entry reinstated."
  end

  def company_matches
    @entrant = Entrant.find(params[:id])
    company = @entrant.company

    matches = case params[:context]
    when "reinstate"
      Entrant.where("LOWER(company) = LOWER(?)", company)
             .where(eligibility_status: "excluded_admin")
    else
      Entrant.where("LOWER(company) = LOWER(?)", company)
             .where(eligibility_status: %w[eligible duplicate_review reinstated_admin])
    end

    render json: {
      company: company,
      count: matches.count,
      entries: matches.limit(3).map { |e|
        { id: e.id, first_name: e.first_name, last_name: e.last_name, email: e.email }
      }
    }
  end
end
