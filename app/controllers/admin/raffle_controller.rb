class Admin::RaffleController < Admin::BaseController
  def show
    @total_count = Entrant.count
    @eligible_count = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner]).count
    @excluded_count = Entrant.where(eligibility_status: %w[excluded_admin duplicate_review]).count
    @draws = RaffleDraw.includes(:winner).order(created_at: :desc)
  end

  def draw
    draw = RaffleDraw.perform_draw!
    redirect_to admin_raffle_path, notice: "Winner drawn: #{draw.winner.first_name} #{draw.winner.last_name}"
  rescue RaffleDraw::NoEligibleEntrants
    redirect_to admin_raffle_path, alert: "No eligible entrants for drawing."
  end
end
