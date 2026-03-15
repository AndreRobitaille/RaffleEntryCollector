require "test_helper"

class DuplicateDetectorTest < ActiveSupport::TestCase
  test "flags older entrant with duplicate email" do
    original = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "Different", last_name: "Person", email: "ada@example.com", company: "Other", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    original.reload
    new_entrant.reload

    assert_equal "duplicate_review", original.eligibility_status
    assert_equal "eligible", new_entrant.eligibility_status
  end

  test "flags older entrant with duplicate name and company" do
    original = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada1@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada2@example.com", company: "Babbage", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    original.reload
    new_entrant.reload

    assert_equal "duplicate_review", original.eligibility_status
    assert_equal "eligible", new_entrant.eligibility_status
  end

  test "does not flag unique entrant" do
    Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "Grace", last_name: "Hopper", email: "grace@example.com", company: "Navy", job_title: "Admiral", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    new_entrant.reload

    assert_equal "eligible", new_entrant.eligibility_status
  end

  test "case-insensitive email matching" do
    original = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "Ada@Example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "X", last_name: "Y", email: "ada@example.com", company: "Other", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    original.reload
    new_entrant.reload

    assert_equal "duplicate_review", original.eligibility_status
    assert_equal "eligible", new_entrant.eligibility_status
  end

  test "case-insensitive name and company matching" do
    original = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada1@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "ADA", last_name: "LOVELACE", email: "ada2@example.com", company: "babbage", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    original.reload
    new_entrant.reload

    assert_equal "duplicate_review", original.eligibility_status
    assert_equal "eligible", new_entrant.eligibility_status
  end

  test "skips check if entrant is not eligible" do
    original = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.create!(first_name: "X", last_name: "Y", email: "ada@example.com", company: "Other", job_title: "Dev", eligibility_confirmed: true)
    new_entrant.update!(eligibility_status: "excluded_admin")

    DuplicateDetector.check(new_entrant)
    original.reload

    assert_equal "eligible", original.eligibility_status
  end

  test "flags multiple older duplicates" do
    first = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    second = Entrant.create!(first_name: "X", last_name: "Y", email: "ada@example.com", company: "Other", job_title: "Dev", eligibility_confirmed: true)
    third = Entrant.create!(first_name: "Z", last_name: "W", email: "ada@example.com", company: "Another", job_title: "PM", eligibility_confirmed: true)

    DuplicateDetector.check(third)
    first.reload
    second.reload
    third.reload

    assert_equal "duplicate_review", first.eligibility_status
    assert_equal "duplicate_review", second.eligibility_status
    assert_equal "eligible", third.eligibility_status
  end

  test "does not overwrite excluded_admin status on older duplicate" do
    excluded = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    excluded.update!(eligibility_status: "excluded_admin")
    new_entrant = Entrant.create!(first_name: "X", last_name: "Y", email: "ada@example.com", company: "Other", job_title: "Dev", eligibility_confirmed: true)

    DuplicateDetector.check(new_entrant)
    excluded.reload

    assert_equal "excluded_admin", excluded.eligibility_status
  end

  test "returns safely when entrant has blank fields" do
    original = Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    new_entrant = Entrant.new(email: nil, first_name: nil, last_name: nil, company: nil, eligibility_status: "eligible")

    assert_nothing_raised { DuplicateDetector.check(new_entrant) }
    original.reload
    assert_equal "eligible", original.eligibility_status
  end

  test "whitespace-padded email does not match trimmed counterpart (see Issue #23)" do
    Entrant.create!(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
                    company: "Babbage", job_title: "Eng", eligibility_confirmed: true)
    padded = Entrant.new(first_name: "X", last_name: "Y", email: " ada@example.com ",
                         company: "Other", job_title: "Dev", eligibility_status: "eligible")
    padded.save!(validate: false)

    DuplicateDetector.check(padded)

    # This SHOULD flag a duplicate but doesn't because email isn't stripped.
    # When Issue #23 is resolved, change this assertion to assert_equal "duplicate_review"
    assert_equal "eligible", Entrant.find_by(email: "ada@example.com").eligibility_status
  end
end
