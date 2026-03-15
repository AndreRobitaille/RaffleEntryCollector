require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/login renders login form" do
    get admin_login_path
    assert_response :success
    assert_select "form"
  end

  test "POST /admin/login with correct password sets session and redirects" do
    post admin_login_path, params: { password: admin_password }
    assert_redirected_to admin_root_path
    follow_redirect!
    assert_response :success
  end

  test "POST /admin/login with wrong password re-renders form" do
    post admin_login_path, params: { password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "GET /admin without auth redirects to login" do
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "DELETE /admin/logout clears session" do
    post admin_login_path, params: { password: admin_password }
    delete admin_logout_path
    assert_redirected_to admin_login_path

    get admin_root_path
    assert_redirected_to admin_login_path
  end

  private

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
  end
end
