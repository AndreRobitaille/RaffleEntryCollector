class Admin::RaffleController < Admin::BaseController
  def show
    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner]).count
    @excluded_count = Entrant.where(eligibility_status: %w[excluded_admin duplicate_review]).count
    @draws = RaffleDraw.includes(:winner).order(id: :asc)
    @draw_complete = @draws.exists?(draw_type: "winner")
  end

  def draw
    RaffleDraw.perform_full_draw!
    redirect_to admin_raffle_path, notice: "Winner and 2 alternates drawn!"
  rescue RaffleDraw::InsufficientEntrants
    redirect_to admin_raffle_path, alert: "Need at least #{RaffleDraw::MINIMUM_ELIGIBLE} eligible entrants to draw."
  rescue RaffleDraw::NoEligibleEntrants
    redirect_to admin_raffle_path, alert: "No eligible entrants for drawing."
  end
end
