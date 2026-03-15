require "test_helper"

class Admin::RaffleControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_admin
    # Clear any existing draws from other tests
    RaffleDraw.delete_all
  end

  test "GET /admin/raffle without auth redirects to login" do
    reset!
    get admin_raffle_path
    assert_redirected_to admin_login_path
  end

  test "POST /admin/raffle/draw without auth redirects to login" do
    reset!
    post draw_admin_raffle_path
    assert_redirected_to admin_login_path
  end

  test "show displays draw dashboard with stats" do
    get admin_raffle_path
    assert_response :success
    assert_select "button", text: /Draw Winner/i
  end

  test "show displays entry counts" do
    get admin_raffle_path
    assert_response :success
    assert_select ".admin-stat__count", minimum: 3
  end

  test "draw creates a raffle draw and redirects with notice" do
    post draw_admin_raffle_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_response :success
    assert_equal 1, RaffleDraw.count
  end

  test "draw shows winner name in flash notice" do
    post draw_admin_raffle_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    draw = RaffleDraw.last
    assert_match draw.winner.first_name, flash[:notice]
  end

  test "draw with no eligible entries shows error" do
    Entrant.update_all(eligibility_status: "excluded_admin")
    post draw_admin_raffle_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--alert", /no eligible/i
  end

  test "show displays draw history after a draw" do
    RaffleDraw.perform_draw!
    get admin_raffle_path
    assert_response :success
    assert_select "table tbody tr", count: 1
  end

  test "draw last eligible entry then fail on next draw" do
    # Exclude all but one eligible entry
    Entrant.eligible.where.not(id: entrants(:ada).id).update_all(eligibility_status: "excluded_admin")

    post draw_admin_raffle_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_equal 1, RaffleDraw.count
    assert_equal "winner", entrants(:ada).reload.eligibility_status

    # Now no eligible entries remain
    post draw_admin_raffle_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--alert", /no eligible/i
    assert_equal 1, RaffleDraw.count
  end
end
