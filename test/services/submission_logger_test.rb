require "test_helper"
require "json"

class SubmissionLoggerTest < ActiveSupport::TestCase
  setup do
    @log_path = Rails.root.join("tmp", "test_submissions.jsonl")
    @log_path.delete if @log_path.exist?
  end

  teardown do
    @log_path.delete if @log_path.exist?
  end

  test "appends a JSON line for an entrant" do
    entrant = Entrant.create!(
      first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
      company: "Babbage", job_title: "Eng", eligibility_confirmed: true,
      interest_areas: ["Application Security"]
    )

    SubmissionLogger.log(entrant, log_path: @log_path)

    lines = @log_path.readlines
    assert_equal 1, lines.size

    data = JSON.parse(lines.first)
    assert_equal "Ada", data["first_name"]
    assert_equal "ada@example.com", data["email"]
    assert_equal ["Application Security"], data["interest_areas"]
    assert data.key?("logged_at")
  end

  test "appends multiple entries without overwriting" do
    entrant1 = Entrant.create!(first_name: "A", last_name: "A", email: "a@x.com", company: "X", job_title: "X", eligibility_confirmed: true)
    entrant2 = Entrant.create!(first_name: "B", last_name: "B", email: "b@x.com", company: "X", job_title: "X", eligibility_confirmed: true)

    SubmissionLogger.log(entrant1, log_path: @log_path)
    SubmissionLogger.log(entrant2, log_path: @log_path)

    lines = @log_path.readlines
    assert_equal 2, lines.size
  end
end
