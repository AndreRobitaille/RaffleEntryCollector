require "test_helper"

class Admin::EntriesControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/entries without auth redirects to login" do
    get admin_entries_path
    assert_redirected_to admin_login_path
  end

  test "GET /admin/entries/:id without auth redirects to login" do
    get admin_entry_path(entrants(:ada))
    assert_redirected_to admin_login_path
  end

  test "PATCH /admin/entries/:id/exclude without auth redirects to login" do
    patch exclude_admin_entry_path(entrants(:ada))
    assert_redirected_to admin_login_path
  end

  test "PATCH /admin/entries/:id/reinstate without auth redirects to login" do
    patch reinstate_admin_entry_path(entrants(:excluded_eve))
    assert_redirected_to admin_login_path
  end

  test "GET /admin/entries shows entries and stats" do
    login_as_admin
    get admin_entries_path
    assert_response :success
    assert_select ".admin-stat__count", minimum: 4
    assert_select "table" do
      assert_select "tr td", text: "Ada"
      assert_select "tr td", text: "Grace"
    end
  end

  test "GET /admin/entries with search filters by name" do
    login_as_admin
    get admin_entries_path, params: { q: "Ada" }
    assert_response :success
    assert_select "table tr td", text: "Ada"
    assert_select "table tr td", text: "Grace", count: 0
  end

  test "GET /admin/entries with search filters by email" do
    login_as_admin
    get admin_entries_path, params: { q: "grace@example" }
    assert_response :success
    assert_select "table tr td", text: "Grace"
    assert_select "table tr td", text: "Ada", count: 0
  end

  test "GET /admin/entries with search filters by company" do
    login_as_admin
    get admin_entries_path, params: { q: "Babbage" }
    assert_response :success
    assert_select "table tr td", text: "Ada"
    assert_select "table tr td", text: "Grace", count: 0
  end

  test "GET /admin/entries default sort is company ascending" do
    login_as_admin
    get admin_entries_path
    assert_response :success
    rows = css_select("table tbody tr td:nth-child(4)")
    companies = rows.map(&:text).map(&:strip)
    assert_equal companies, companies.sort
  end

  test "GET /admin/entries respects sort params" do
    login_as_admin
    get admin_entries_path, params: { sort: "last_name", dir: "desc" }
    assert_response :success
    rows = css_select("table tbody tr td:nth-child(3)")
    last_names = rows.map(&:text).map(&:strip)
    assert_equal last_names, last_names.sort.reverse
  end

  test "GET /admin/entries/:id shows entry detail" do
    login_as_admin
    get admin_entry_path(entrants(:ada))
    assert_response :success
    assert_select "h2", text: /Ada Lovelace/
    assert_select ".admin-detail__value", text: "ada@example.com"
    assert_select ".admin-detail__value", text: "Babbage Inc"
    assert_select ".admin-detail__value", text: "Engineer"
  end

  test "GET /admin/entries/:id shows interest areas" do
    login_as_admin
    get admin_entry_path(entrants(:ada))
    assert_response :success
    assert_select ".admin-interest-tag", text: "Penetration Testing"
    assert_select ".admin-interest-tag", text: "Application Security"
  end

  test "GET /admin/entries/:id shows exclude form for eligible entry" do
    login_as_admin
    get admin_entry_path(entrants(:ada))
    assert_response :success
    assert_select ".admin-action--exclude form"
  end

  test "GET /admin/entries/:id shows reinstate button for excluded entry" do
    login_as_admin
    get admin_entry_path(entrants(:excluded_eve))
    assert_response :success
    assert_select ".admin-action--reinstate form"
    assert_select ".admin-detail__value", text: "CypherCon sponsor employee"
  end

  test "GET /admin/entries/:id shows both actions for duplicate_review entry" do
    login_as_admin
    get admin_entry_path(entrants(:duplicate_alan))
    assert_response :success
    assert_select ".admin-action--exclude form"
    assert_select ".admin-action--reinstate form"
  end

  test "GET /admin/entries/:id shows info box for self_attested_ineligible" do
    login_as_admin
    get admin_entry_path(entrants(:ineligible_bob))
    assert_response :success
    assert_select ".admin-action--info", text: /did not confirm eligibility/
  end

  test "PATCH exclude updates status and saves reason" do
    login_as_admin
    entrant = entrants(:ada)
    patch exclude_admin_entry_path(entrant), params: { exclusion_reason: "Sponsor employee" }
    assert_redirected_to admin_entry_path(entrant)
    entrant.reload
    assert_equal "excluded_admin", entrant.eligibility_status
    assert_equal "Sponsor employee", entrant.exclusion_reason
  end

  test "PATCH exclude works without a reason" do
    login_as_admin
    entrant = entrants(:grace)
    patch exclude_admin_entry_path(entrant)
    assert_redirected_to admin_entry_path(entrant)
    entrant.reload
    assert_equal "excluded_admin", entrant.eligibility_status
    assert_nil entrant.exclusion_reason
  end

  test "PATCH reinstate updates status and clears reason" do
    login_as_admin
    entrant = entrants(:excluded_eve)
    patch reinstate_admin_entry_path(entrant)
    assert_redirected_to admin_entry_path(entrant)
    entrant.reload
    assert_equal "reinstated_admin", entrant.eligibility_status
    assert_nil entrant.exclusion_reason
  end

  test "PATCH exclude does not modify a winner" do
    login_as_admin
    entrant = entrants(:winner_carol)
    patch exclude_admin_entry_path(entrant), params: { exclusion_reason: "test" }
    assert_redirected_to admin_entry_path(entrant)
    follow_redirect!
    assert_select ".admin-flash--alert", text: /Cannot modify/
    entrant.reload
    assert_equal "winner", entrant.eligibility_status
  end

  test "PATCH reinstate does not modify a winner" do
    login_as_admin
    entrant = entrants(:winner_carol)
    patch reinstate_admin_entry_path(entrant)
    assert_redirected_to admin_entry_path(entrant)
    follow_redirect!
    assert_select ".admin-flash--alert", text: /Cannot modify/
    entrant.reload
    assert_equal "winner", entrant.eligibility_status
  end

  test "GET /admin/entries/:id shows no actions for winner" do
    login_as_admin
    get admin_entry_path(entrants(:winner_carol))
    assert_response :success
    assert_select ".admin-action--exclude", count: 0
    assert_select ".admin-action--reinstate", count: 0
  end

  test "PATCH reinstate works on duplicate_review entry" do
    login_as_admin
    entrant = entrants(:duplicate_alan)
    patch reinstate_admin_entry_path(entrant)
    assert_redirected_to admin_entry_path(entrant)
    entrant.reload
    assert_equal "reinstated_admin", entrant.eligibility_status
  end

  private

  def login_as_admin
    post admin_login_path, params: { password: admin_password }
  end

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
  end
end
