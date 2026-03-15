require "test_helper"
require "minitest/mock"

class Admin::AuthenticationTest < ActiveSupport::TestCase
  # Create a minimal test class to include the concern.
  # before_action is a Rails controller macro — stub it out so the concern
  # can be included into a plain Ruby object for unit testing.
  class TestHost
    def self.before_action(*); end

    include Admin::Authentication

    # Make private methods accessible for testing
    public :admin_password, :admin_password_configured?
  end

  setup do
    @host = TestHost.new
  end

  test "DEV_PASSWORD is a frozen string" do
    assert_kind_of String, Admin::Authentication::DEV_PASSWORD
    assert Admin::Authentication::DEV_PASSWORD.frozen?
  end

  test "admin_password returns DEV_PASSWORD in test environment when credentials not set" do
    assert_equal Admin::Authentication::DEV_PASSWORD, @host.admin_password
  end

  test "admin_password_configured? returns true when password available" do
    assert @host.admin_password_configured?
  end

  test "admin_password returns DEV_PASSWORD for blank credential via .presence" do
    fake_creds = Struct.new(:admin_password).new("")
    Rails.application.stub(:credentials, fake_creds) do
      assert_equal Admin::Authentication::DEV_PASSWORD, @host.admin_password
    end
  end
end
