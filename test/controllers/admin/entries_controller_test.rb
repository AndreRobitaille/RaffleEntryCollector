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
    assert_select ".admin-flash--alert", text: /Cannot reinstate/
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

  test "PATCH reinstate does not modify self_attested_ineligible entry" do
    login_as_admin
    entrant = entrants(:ineligible_bob)
    patch reinstate_admin_entry_path(entrant)
    assert_redirected_to admin_entry_path(entrant)
    follow_redirect!
    assert_select ".admin-flash--alert", text: /Cannot reinstate/
    entrant.reload
    assert_equal "self_attested_ineligible", entrant.eligibility_status
  end

  test "GET /admin/entries shows backup status card" do
    login_as_admin
    get admin_entries_path
    assert_response :success
    assert_select ".admin-stat__label", text: "USB Backup"
  end

  # Pagination tests (Task 7)

  test "GET /admin/entries page 1 returns entries" do
    login_as_admin
    get admin_entries_path, params: { page: 1 }
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "GET /admin/entries page 2 returns next batch after creating enough entries" do
    login_as_admin
    51.times do |i|
      Entrant.create!(first_name: "Page#{i}", last_name: "Test", email: "page#{i}@x.com",
                      company: "X", job_title: "X", eligibility_confirmed: true)
    end
    get admin_entries_path, params: { page: 2 }
    assert_response :success
    # Page 2 should have the overflow entries (total > 50, so page 2 is non-empty)
    assert_select "table tbody tr", minimum: 1
  end

  test "GET /admin/entries out-of-range page returns empty table body" do
    login_as_admin
    get admin_entries_path, params: { page: 999 }
    assert_response :success
    assert_select "table tbody tr", count: 0
  end

  test "GET /admin/entries page param combined with search" do
    login_as_admin
    get admin_entries_path, params: { q: "Ada", page: 1 }
    assert_response :success
    assert_select "table tr td", text: "Ada"
  end

  # Exclusion reason buttons tests (Task 8)

  test "show displays exclusion reason buttons for eligible entry" do
    login_as_admin
    get admin_entry_path(entrants(:ada))
    assert_select ".admin-exclude-reasons"
    assert_select ".admin-exclude-reasons form", 5
  end

  test "show displays exclusion reason buttons for duplicate_review entry" do
    login_as_admin
    get admin_entry_path(entrants(:duplicate_alan))
    assert_select ".admin-exclude-reasons"
    assert_select ".admin-exclude-reasons form", 5
  end

  test "exclude with preset reason stores correct reason" do
    login_as_admin
    patch exclude_admin_entry_path(entrants(:ada)), params: { exclusion_reason: "FFS Employee" }
    assert_equal "FFS Employee", entrants(:ada).reload.exclusion_reason
  end

  test "show does not display text field for exclusion reason" do
    login_as_admin
    get admin_entry_path(entrants(:ada))
    assert_select "input[type=text][name*=exclusion_reason]", 0
  end

  # Edge case tests

  test "GET /admin/entries/:id for non-existent entry returns 404" do
    login_as_admin
    get admin_entry_path(id: 999_999)
    assert_response :not_found
  end

  test "GET /admin/entries with invalid sort column falls back to default" do
    login_as_admin
    get admin_entries_path, params: { sort: "DROP TABLE entrants", dir: "asc" }
    assert_response :success
    # Falls back to default sort (company) — page renders without error
    assert_select "table tbody tr", minimum: 1
  end

  test "GET /admin/entries search with special characters returns safely" do
    login_as_admin
    get admin_entries_path, params: { q: "O'Brien & \"Co\" <script>" }
    assert_response :success
    # No error, no unescaped HTML in response
    refute_includes response.body, "<script>"
  end

  # Session persistence tests (Task 2)

  test "index stores search query in session" do
    login_as_admin
    get admin_entries_path, params: { q: "Ada" }
    assert_equal "Ada", session[:admin_entries_search]
  end

  test "index stores sort params in session" do
    login_as_admin
    get admin_entries_path, params: { sort: "last_name", dir: "desc" }
    assert_equal "last_name", session[:admin_entries_sort]
    assert_equal "desc", session[:admin_entries_direction]
  end

  test "index restores search from session when no params given" do
    login_as_admin
    get admin_entries_path, params: { q: "Ada" }
    get admin_entries_path
    assert_select "table tr td", text: "Ada"
    assert_select "table tr td", text: "Grace", count: 0
  end

  test "index restores sort from session when no params given" do
    login_as_admin
    get admin_entries_path, params: { sort: "last_name", dir: "desc" }
    get admin_entries_path
    rows = css_select("table tbody tr td:nth-child(3)")
    last_names = rows.map(&:text).map(&:strip)
    assert_equal last_names, last_names.sort.reverse
  end

  test "index explicit params override session state" do
    login_as_admin
    get admin_entries_path, params: { q: "Ada" }
    get admin_entries_path, params: { q: "Grace" }
    assert_select "table tr td", text: "Grace"
    assert_select "table tr td", text: "Ada", count: 0
  end

  test "index clears session search when visiting with empty search" do
    login_as_admin
    get admin_entries_path, params: { q: "Ada" }
    get admin_entries_path, params: { q: "" }
    assert_nil session[:admin_entries_search]
  end

  # company_matches tests (Task 4)

  test "GET company_matches without auth redirects to login" do
    get company_matches_admin_entry_path(entrants(:ada))
    assert_redirected_to admin_login_path
  end

  test "GET company_matches for exclude context returns eligible entries from same company" do
    login_as_admin
    peer = Entrant.create!(
      first_name: "Charles", last_name: "Babbage", email: "charles@babbage.com",
      company: "Babbage Inc", job_title: "Inventor", eligibility_confirmed: true
    )
    get company_matches_admin_entry_path(entrants(:ada)), params: { context: "exclude" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Babbage Inc", json["company"]
    assert_equal 2, json["count"]
    assert json["entries"].any? { |e| e["first_name"] == "Ada" }
    assert json["entries"].any? { |e| e["first_name"] == "Charles" }
  end

  test "GET company_matches for exclude context excludes already-excluded entries" do
    login_as_admin
    # excluded_eve is excluded_admin — should not appear in exclude context
    # sponsor_frank is eligible (same company), sponsor_gina is excluded_admin
    get company_matches_admin_entry_path(entrants(:excluded_eve)), params: { context: "exclude" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["count"]  # only sponsor_frank (eligible)
    assert json["entries"].any? { |e| e["first_name"] == "Frank" }
  end

  test "GET company_matches for reinstate context returns excluded entries from same company" do
    login_as_admin
    # excluded_eve and sponsor_gina are both excluded_admin from CypherCon Sponsor LLC
    get company_matches_admin_entry_path(entrants(:excluded_eve)), params: { context: "reinstate" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "CypherCon Sponsor LLC", json["company"]
    assert_equal 2, json["count"]  # excluded_eve + sponsor_gina
  end

  test "GET company_matches uses case-insensitive company matching" do
    login_as_admin
    Entrant.create!(
      first_name: "Lower", last_name: "Case", email: "lower@babbage.com",
      company: "babbage inc", job_title: "Tester", eligibility_confirmed: true
    )
    get company_matches_admin_entry_path(entrants(:ada)), params: { context: "exclude" }
    json = JSON.parse(response.body)
    assert_equal 2, json["count"]  # ada + the lowercase entry
  end

  test "GET company_matches limits entries array to 3" do
    login_as_admin
    4.times do |i|
      Entrant.create!(
        first_name: "Person#{i}", last_name: "Test", email: "p#{i}@babbage.com",
        company: "Babbage Inc", job_title: "Tester", eligibility_confirmed: true
      )
    end
    get company_matches_admin_entry_path(entrants(:ada)), params: { context: "exclude" }
    json = JSON.parse(response.body)
    assert_equal 5, json["count"]  # ada + 4 new
    assert_equal 3, json["entries"].length
  end
end
