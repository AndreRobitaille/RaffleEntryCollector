require "test_helper"

class Admin::RaffleControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_admin
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
    assert_select ".admin-stat__count", minimum: 3
  end

  test "show displays draw button when no draw has occurred" do
    get admin_raffle_path
    assert_select "button", text: /Draw Winner/i
  end

  test "draw creates winner and two alternates" do
    assert_difference "RaffleDraw.count", 3 do
      post draw_admin_raffle_path
    end
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--notice"
  end

  test "draw shows error when fewer than 3 eligible" do
    # Leave only 2 eligible
    Entrant.eligible.where.not(id: Entrant.eligible.limit(2).pluck(:id)).update_all(eligibility_status: "excluded_admin")

    assert_no_difference "RaffleDraw.count" do
      post draw_admin_raffle_path
    end
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--alert"
  end

  test "draw with no eligible entries shows error" do
    Entrant.update_all(eligibility_status: "excluded_admin")
    post draw_admin_raffle_path
    assert_redirected_to admin_raffle_path
    follow_redirect!
    assert_select ".admin-flash--alert"
  end

  test "show displays winner cards after draw" do
    post draw_admin_raffle_path
    get admin_raffle_path

    assert_select ".admin-winner-card", 3
    assert_select ".admin-winner-card--winner", 1
    assert_select ".admin-winner-card--alternate", 2
  end

  test "show hides draw button after draw is complete" do
    post draw_admin_raffle_path
    get admin_raffle_path

    assert_select ".admin-draw-action", 0
  end

  test "show displays draw history after a draw" do
    post draw_admin_raffle_path
    get admin_raffle_path
    assert_select "table tbody tr", count: 3
  end

  test "show displays instructions before draw" do
    get admin_raffle_path
    assert_select ".admin-info-panel"
  end
end
