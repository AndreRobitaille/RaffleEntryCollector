require "test_helper"

class DemoPopulatorTest < ActiveSupport::TestCase
  setup do
    # Clear fixtures so DB is empty
    RaffleDraw.delete_all
    Entrant.delete_all
  end

  test "populate! inserts 300 entrants" do
    DemoPopulator.populate!
    assert_equal 300, Entrant.count
  end

  test "most demo entrants are eligible" do
    DemoPopulator.populate!
    assert_operator Entrant.where(eligibility_status: "eligible").count, :>=, 270
  end

  test "includes duplicate_review entrants" do
    DemoPopulator.populate!
    assert_operator Entrant.where(eligibility_status: "duplicate_review").count, :>=, 5
  end

  test "includes excluded sponsor companies" do
    DemoPopulator.populate!
    sponsor_excluded = Entrant.where(eligibility_status: "excluded_admin", exclusion_reason: "CypherCon sponsor employee")
    assert_operator sponsor_excluded.count, :>=, 6
    companies = sponsor_excluded.pluck(:company).uniq
    assert_operator companies.length, :>=, 2
  end

  test "includes individual exclusions with varied reasons" do
    DemoPopulator.populate!
    individual_excluded = Entrant.where(eligibility_status: "excluded_admin")
                                 .where.not(exclusion_reason: "CypherCon sponsor employee")
    assert_operator individual_excluded.count, :>=, 2
    reasons = individual_excluded.pluck(:exclusion_reason).uniq
    assert_operator reasons.length, :>=, 2
  end

  test "demo entrants have varied interest areas" do
    DemoPopulator.populate!
    interest_counts = Entrant.all.map { |e| e.interest_areas.length }.uniq
    assert interest_counts.length > 1, "Expected varied interest area counts"
  end

  test "interest_areas round-trips correctly through insert_all" do
    DemoPopulator.populate!
    entrant = Entrant.first
    assert_kind_of Array, entrant.interest_areas
    entrant.interest_areas.each do |area|
      assert_includes Entrant::INTEREST_AREA_OPTIONS, area
    end
  end

  test "demo entrants have valid emails" do
    DemoPopulator.populate!
    Entrant.find_each do |e|
      assert_match URI::MailTo::EMAIL_REGEXP, e.email
    end
  end

  test "populate! raises if entrants exist" do
    Entrant.create!(
      first_name: "Test", last_name: "User", email: "test@example.com",
      company: "TestCo", job_title: "Tester", eligibility_confirmed: true
    )
    assert_raises(DemoPopulator::DatabaseNotEmpty) { DemoPopulator.populate! }
  end

  test "demo entrants have spread of created_at timestamps" do
    DemoPopulator.populate!
    timestamps = Entrant.pluck(:created_at)
    assert timestamps.min < timestamps.max, "Expected spread of timestamps"
  end
end
