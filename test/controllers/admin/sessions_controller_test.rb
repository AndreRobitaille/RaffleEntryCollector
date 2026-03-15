require "test_helper"
require "minitest/mock"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/login renders login form" do
    get admin_login_path
    assert_response :success
    assert_select "form"
  end

  test "POST /admin/login with correct password sets session and redirects" do
    post admin_login_path, params: { password: Admin::Authentication::DEV_PASSWORD }
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
    post admin_login_path, params: { password: Admin::Authentication::DEV_PASSWORD }
    delete admin_logout_path
    assert_redirected_to admin_login_path

    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "DELETE /admin/logout works even if admin password were misconfigured" do
    login_as_admin
    delete admin_logout_path
    assert_redirected_to admin_login_path
  end

  test "POST /admin/login in production with missing password renders 403" do
    credentials_stub = Struct.new(:admin_password).new(nil)
    Rails.application.stub(:credentials, credentials_stub) do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        post admin_login_path, params: { password: "anything" }
        assert_response :forbidden
      end
    end
  end

  test "GET /admin/login renders 403 misconfigured page when password missing in production" do
    credentials_stub = Struct.new(:admin_password).new(nil)
    Rails.application.stub(:credentials, credentials_stub) do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        get admin_login_path
        assert_response :forbidden
        assert_includes response.body, "Admin Console Unavailable"
      end
    end
  end

  test "public kiosk entry form works regardless of admin password configuration" do
    credentials_stub = Struct.new(:admin_password).new(nil)
    Rails.application.stub(:credentials, credentials_stub) do
      get root_path
      assert_response :success
    end
  end

  test "blank credential password does not allow empty-string authentication" do
    credentials_stub = Struct.new(:admin_password).new("")
    Rails.application.stub(:credentials, credentials_stub) do
      # In test env, "" is converted to nil by .presence, then falls back to DEV_PASSWORD
      # So empty string login should fail
      post admin_login_path, params: { password: "" }
      assert_response :unprocessable_entity
    end
  end
end
