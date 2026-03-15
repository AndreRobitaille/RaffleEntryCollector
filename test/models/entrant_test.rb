require "test_helper"

class EntrantTest < ActiveSupport::TestCase
  test "valid entrant with all required fields" do
    entrant = Entrant.new(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada@example.com",
      company: "Babbage Inc",
      job_title: "Engineer",
      eligibility_confirmed: true
    )
    assert entrant.valid?
    assert_equal "eligible", entrant.eligibility_status
  end

  test "invalid without first_name" do
    entrant = Entrant.new(last_name: "X", email: "x@x.com", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:first_name], "can't be blank"
  end

  test "invalid without last_name" do
    entrant = Entrant.new(first_name: "X", email: "x@x.com", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:last_name], "can't be blank"
  end

  test "invalid without email" do
    entrant = Entrant.new(first_name: "X", last_name: "X", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:email], "can't be blank"
  end

  test "invalid without company" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "x@x.com", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:company], "can't be blank"
  end

  test "invalid without job_title" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "x@x.com", company: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:job_title], "can't be blank"
  end

  test "invalid without eligibility_confirmed" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "x@x.com", company: "X", job_title: "X", eligibility_confirmed: false)
    assert_not entrant.valid?
    assert_includes entrant.errors[:eligibility_confirmed], "must be accepted"
  end

  test "email must look like an email" do
    entrant = Entrant.new(first_name: "X", last_name: "X", email: "notanemail", company: "X", job_title: "X", eligibility_confirmed: true)
    assert_not entrant.valid?
    assert_includes entrant.errors[:email], "is invalid"
  end

  test "interest_areas defaults to empty array" do
    entrant = Entrant.new
    assert_equal [], entrant.interest_areas
  end

  test "interest_areas stores array of strings" do
    entrant = Entrant.new(
      first_name: "X", last_name: "X", email: "x@x.com",
      company: "X", job_title: "X", eligibility_confirmed: true,
      interest_areas: [ "Penetration Testing", "Application Security" ]
    )
    assert entrant.valid?
    entrant.save!
    entrant.reload
    assert_equal [ "Penetration Testing", "Application Security" ], entrant.interest_areas
  end

  test "eligibility_status defaults to eligible" do
    entrant = Entrant.create!(
      first_name: "X", last_name: "X", email: "x@x.com",
      company: "X", job_title: "X", eligibility_confirmed: true
    )
    assert_equal "eligible", entrant.eligibility_status
  end

  test "eligibility_status validates inclusion" do
    entrant = Entrant.new(eligibility_status: "bogus")
    assert_not entrant.valid?
    assert_includes entrant.errors[:eligibility_status], "is not included in the list"
  end

  test "interest_areas rejects non-array values" do
    entrant = Entrant.new(
      first_name: "X", last_name: "X", email: "x@x.com",
      company: "X", job_title: "X", eligibility_confirmed: true,
      interest_areas: "not an array"
    )
    assert_not entrant.valid?
    assert_includes entrant.errors[:interest_areas], "must be an array"
  end

  test "scope eligible returns only eligible and reinstated entries" do
    attrs = { company: "X", job_title: "X", eligibility_confirmed: true }
    eligible = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", eligibility_status: "eligible", **attrs)
    reinstated = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", eligibility_status: "reinstated_admin", **attrs)
    excluded = Entrant.create!(first_name: "C", last_name: "C", email: "c@x.com", eligibility_status: "excluded_admin", **attrs)
    duplicate = Entrant.create!(first_name: "D", last_name: "D", email: "d@x.com", eligibility_status: "duplicate_review", **attrs)
    winner = Entrant.create!(first_name: "E", last_name: "E", email: "e@x.com", eligibility_status: "winner", **attrs)

    result = Entrant.eligible
    assert_includes result, eligible
    assert_includes result, reinstated
    assert_not_includes result, excluded
    assert_not_includes result, duplicate
    assert_not_includes result, winner
  end

  test "scope duplicates returns only duplicate_review entries" do
    attrs = { company: "X", job_title: "X", eligibility_confirmed: true }
    duplicate = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", eligibility_status: "duplicate_review", **attrs)
    eligible = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", eligibility_status: "eligible", **attrs)
    excluded = Entrant.create!(first_name: "C", last_name: "C", email: "c@x.com", eligibility_status: "excluded_admin", **attrs)

    result = Entrant.duplicates
    assert_includes result, duplicate
    assert_not_includes result, eligible
    assert_not_includes result, excluded
  end

  test "scope excluded returns only excluded_admin entries" do
    attrs = { company: "X", job_title: "X", eligibility_confirmed: true }
    excluded = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", eligibility_status: "excluded_admin", **attrs)
    eligible = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", eligibility_status: "eligible", **attrs)
    duplicate = Entrant.create!(first_name: "C", last_name: "C", email: "c@x.com", eligibility_status: "duplicate_review", **attrs)

    result = Entrant.excluded
    assert_includes result, excluded
    assert_not_includes result, eligible
    assert_not_includes result, duplicate
  end

  test "has_many raffle_draws returns draws where entrant is winner" do
    attrs = { company: "X", job_title: "X", eligibility_confirmed: true }
    entrant = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", **attrs)
    draw = RaffleDraw.create!(winner: entrant, eligible_count: 5, draw_type: "winner")

    assert_includes entrant.raffle_draws, draw
  end
end
