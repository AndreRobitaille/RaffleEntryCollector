class Entrant < ApplicationRecord
  ELIGIBILITY_STATUSES = %w[
    eligible
    self_attested_ineligible
    duplicate_review
    excluded_admin
    reinstated_admin
    winner
    alternate_winner
  ].freeze

  INTEREST_AREA_OPTIONS = [
    "Penetration Testing",
    "Red Team / Adversary Simulation",
    "Application Security",
    "Cloud & Infrastructure Security",
    "Hardware / IoT Security",
    "Space Systems Security",
    "Security Training"
  ].freeze

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :company, presence: true
  validates :job_title, presence: true
  validates :eligibility_confirmed, acceptance: { accept: true }, on: :create
  validates :eligibility_status, inclusion: { in: ELIGIBILITY_STATUSES }

  validate :interest_areas_must_be_array

  has_many :raffle_draws, foreign_key: :winner_id

  scope :eligible, -> { where(eligibility_status: %w[eligible reinstated_admin]) }
  scope :duplicates, -> { where(eligibility_status: "duplicate_review") }
  scope :excluded, -> { where(eligibility_status: "excluded_admin") }

  private

  def interest_areas_must_be_array
    errors.add(:interest_areas, "must be an array") unless interest_areas.is_a?(Array)
  end
end
