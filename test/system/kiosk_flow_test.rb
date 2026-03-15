require "application_system_test_case"

class KioskFlowTest < ApplicationSystemTestCase
  test "form fields are disabled until eligibility checkbox is checked" do
    visit enter_path

    assert page.has_field?("entrant[first_name]", disabled: true)
    assert page.has_field?("entrant[last_name]", disabled: true)
    assert page.has_field?("entrant[email]", disabled: true)
    assert page.has_field?("entrant[company]", disabled: true)
    assert page.has_field?("entrant[job_title]", disabled: true)
    assert page.has_button?("Submit Entry", disabled: true)

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."

    assert page.has_field?("entrant[first_name]", disabled: false)
    assert page.has_field?("entrant[last_name]", disabled: false)
    assert page.has_field?("entrant[email]", disabled: false)
    assert page.has_field?("entrant[company]", disabled: false)
    assert page.has_field?("entrant[job_title]", disabled: false)
    assert page.has_button?("Submit Entry", disabled: false)
  end

  test "unchecking eligibility re-disables fields" do
    visit enter_path

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    assert page.has_field?("entrant[first_name]", disabled: false)

    uncheck "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    assert page.has_field?("entrant[first_name]", disabled: true)
    assert page.has_button?("Submit Entry", disabled: true)
  end

  test "interest area checkboxes are disabled until eligibility checked" do
    visit enter_path

    assert page.has_field?("entrant[interest_areas][]", disabled: true)

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."

    assert page.has_field?("entrant[interest_areas][]", disabled: false)
  end

  test "full entry flow from attract to success" do
    visit root_path
    click_link "Enter the Raffle"

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"
    fill_in "Work Email", with: "ada@example.com"
    fill_in "Company", with: "Babbage Inc"
    fill_in "Job Title", with: "Engineer"
    click_button "Submit Entry"

    assert_text "You're entered in the raffle"
    click_link "Start New Entry"
    assert_text "Win a Commodore 64 Ultimate"
  end

  test "idle timeout redirects to attract screen after inactivity" do
    visit enter_path

    # Override to 1-second timeout via the Stimulus controller instance
    page.execute_script(<<~JS)
      const el = document.querySelector('[data-controller*="idle-timeout"]')
      const ctrl = window.Stimulus.getControllerForElementAndIdentifier(el, 'idle-timeout')
      ctrl.secondsValue = 1
      ctrl.resetTimer()
    JS

    assert_text "Win a Commodore 64 Ultimate", wait: 3
  end

  test "success screen auto-redirects to attract screen" do
    visit root_path
    click_link "Enter the Raffle"

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    fill_in "First name", with: "Test"
    fill_in "Last name", with: "User"
    fill_in "Work Email", with: "test@example.com"
    fill_in "Company", with: "TestCo"
    fill_in "Job Title", with: "Tester"
    click_button "Submit Entry"

    assert_text "You're entered in the raffle"

    # Override to 1-second timeout via the Stimulus controller instance
    page.execute_script(<<~JS)
      const el = document.querySelector('[data-controller*="auto-redirect"]')
      const ctrl = window.Stimulus.getControllerForElementAndIdentifier(el, 'auto-redirect')
      clearTimeout(ctrl.timer)
      ctrl.timer = setTimeout(() => {
        window.location.href = ctrl.redirectUrlValue
      }, 1000)
    JS

    assert_text "Win a Commodore 64 Ultimate", wait: 3
  end

  test "rules modal opens and closes" do
    visit enter_path

    click_button "Rules & Drawing Info"
    assert_text "One entry per person"

    click_button "\u00D7"
    assert_no_selector "dialog[open]"
  end

  test "submitting with missing fields shows validation errors" do
    visit enter_path

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    fill_in "First name", with: "Ada"
    # Leave other fields blank
    click_button "Submit Entry"

    assert_selector ".form-field--error", minimum: 1
    # Form retains the value we entered
    assert_field "First name", with: "Ada"
  end

  test "submitting with invalid email shows error" do
    visit enter_path

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"
    fill_in "Work Email", with: "notanemail"
    fill_in "Company", with: "Babbage"
    fill_in "Job Title", with: "Engineer"

    # Disable HTML5 native validation so the invalid email reaches the server
    page.execute_script("document.querySelector('form').setAttribute('novalidate', true)")
    click_button "Submit Entry"

    assert_selector ".form-field--error"
    assert_text "is invalid"
  end

  test "selected interest areas persist after submission" do
    visit enter_path

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"
    fill_in "Work Email", with: "ada-interest@example.com"
    fill_in "Company", with: "Babbage"
    fill_in "Job Title", with: "Engineer"
    check "Penetration Testing"
    # Use JS click to avoid the sticky footer intercepting the click on this checkbox
    page.execute_script("document.getElementById('interest_application-security').click()")
    click_button "Submit Entry"

    assert_text "You're entered in the raffle"
    entrant = Entrant.find_by(email: "ada-interest@example.com")
    assert_includes entrant.interest_areas, "Penetration Testing"
    assert_includes entrant.interest_areas, "Application Security"
  end

  test "unchecking eligibility after filling form disables fields and submit" do
    visit enter_path

    check "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."
    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"

    uncheck "I confirm that I am not employed by CypherCon or a CypherCon sponsor and am eligible under the raffle rules."

    assert page.has_field?("entrant[first_name]", disabled: true)
    assert page.has_button?("Submit Entry", disabled: true)
  end
end
