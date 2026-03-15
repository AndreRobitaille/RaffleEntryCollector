require "test_helper"

class KioskControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders attract screen" do
    get root_path
    assert_response :success
    assert_select "a", text: /Enter the Raffle/i
  end

  test "GET /enter renders entry form" do
    get enter_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='entrant[first_name]']"
    assert_select "input[name='entrant[email]']"
  end

  test "POST /enter creates entrant and redirects to success" do
    assert_difference "Entrant.count", 1 do
      post enter_path, params: {
        entrant: {
          first_name: "Ada",
          last_name: "Lovelace",
          email: "ada@example.com",
          company: "Babbage Inc",
          job_title: "Engineer",
          eligibility_confirmed: "1",
          interest_areas: [ "Penetration Testing" ]
        }
      }
    end
    assert_redirected_to success_path
  end

  test "POST /enter with invalid data re-renders form" do
    assert_no_difference "Entrant.count" do
      post enter_path, params: {
        entrant: { first_name: "", last_name: "", email: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "GET /success renders success screen" do
    get success_path
    assert_response :success
    assert_select "a", text: /Start New Entry/i
  end

  test "successful submission writes to JSONL log" do
    log_path = Rails.root.join("log", "submissions.jsonl")
    log_path.delete if log_path.exist?

    post enter_path, params: {
      entrant: {
        first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
        company: "Babbage", job_title: "Eng", eligibility_confirmed: "1"
      }
    }

    assert log_path.exist?
    lines = log_path.readlines
    assert lines.size >= 1
  end
end
