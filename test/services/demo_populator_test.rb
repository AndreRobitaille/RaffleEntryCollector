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

  test "all demo entrants are eligible" do
    DemoPopulator.populate!
    assert Entrant.where.not(eligibility_status: "eligible").empty?
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
