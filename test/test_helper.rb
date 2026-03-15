ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module AdminTestHelper
  def login_as_admin
    post admin_login_path, params: { password: admin_password }
  end

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
  end
end

class ActionDispatch::IntegrationTest
  include AdminTestHelper
end
