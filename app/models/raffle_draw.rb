class RaffleDraw < ApplicationRecord
  class NoEligibleEntrants < StandardError; end
  class InsufficientEntrants < StandardError; end

  MINIMUM_ELIGIBLE = 3

  belongs_to :winner, class_name: "Entrant"

  validates :eligible_count, presence: true, numericality: { greater_than: 0 }
  validates :draw_type, inclusion: { in: %w[winner alternate_winner] }

  def self.perform_draw!(admin_note: nil)
    eligible = Entrant.eligible.where.not(eligibility_status: %w[winner alternate_winner])
    raise NoEligibleEntrants, "No eligible entrants for drawing" if eligible.empty?

    pool_size = eligible.count
    is_alternate = RaffleDraw.exists?
    selected = eligible.offset(SecureRandom.random_number(pool_size)).first
    status = is_alternate ? "alternate_winner" : "winner"

    transaction do
      selected.update!(eligibility_status: status)
      create!(
        winner: selected,
        eligible_count: pool_size,
        draw_type: status,
        admin_note: admin_note
      )
    end
  end
end
