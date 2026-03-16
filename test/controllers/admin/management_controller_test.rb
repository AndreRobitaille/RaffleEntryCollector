require "test_helper"

class Admin::ManagementControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_admin
  end

  test "GET /admin/management without auth redirects to login" do
    reset!
    get admin_management_path
    assert_redirected_to admin_login_path
  end

  test "show displays management page" do
    get admin_management_path
    assert_response :success
    assert_select "h1", /Management/i
  end

  # --- Reset Drawing ---

  test "POST reset_drawing without auth redirects to login" do
    reset!
    post reset_drawing_admin_management_path
    assert_redirected_to admin_login_path
  end

  test "reset_drawing resets winner statuses to eligible" do
    # winner_carol fixture has eligibility_status: "winner"
    post reset_drawing_admin_management_path
    assert_redirected_to admin_management_path

    entrants(:winner_carol).reload
    assert_equal "eligible", entrants(:winner_carol).eligibility_status
  end

  test "reset_drawing deletes all raffle_draw records" do
    # Create a draw first
    RaffleDraw.perform_full_draw!
    assert RaffleDraw.exists?

    post reset_drawing_admin_management_path
    assert_not RaffleDraw.exists?
  end

  test "reset_drawing when no draw exists shows notice" do
    RaffleDraw.delete_all
    post reset_drawing_admin_management_path
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--notice"
  end

  # --- Populate Demo ---

  test "POST populate_demo without auth redirects to login" do
    reset!
    post populate_demo_admin_management_path
    assert_redirected_to admin_login_path
  end

  test "populate_demo creates 300 entrants when DB is empty" do
    RaffleDraw.delete_all
    Entrant.delete_all

    post populate_demo_admin_management_path
    assert_redirected_to admin_management_path
    assert_equal 300, Entrant.count
  end

  test "populate_demo fails when entrants exist" do
    assert Entrant.exists? # fixtures loaded
    post populate_demo_admin_management_path
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--alert"
  end
end
