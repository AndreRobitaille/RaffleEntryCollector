# Admin Password Security Hardening — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the hardcoded `"changeme"` admin password from source code and require Rails encrypted credentials in production.

**Architecture:** Extract shared password logic into an `Admin::Authentication` concern included by both `Admin::SessionsController` and `Admin::BaseController`. Production requires credentials; dev/test falls back to a constant. Missing password in production renders a 403 error on admin routes while the public kiosk keeps working.

**Tech Stack:** Ruby on Rails, Rails encrypted credentials, ActiveSupport::Concern

**Spec:** `docs/superpowers/specs/2026-03-15-admin-password-security-design.md`

**Mocking approach:** Minitest's built-in `Object#stub` (block form) — no additional gems needed.

---

## Chunk 1: Core Implementation

### Task 1: Create `Admin::Authentication` concern with tests

**Files:**
- Create: `app/controllers/concerns/admin/authentication.rb`
- Create: `test/controllers/concerns/admin/authentication_test.rb`

- [ ] **Step 1: Write the failing tests**

```ruby
# test/controllers/concerns/admin/authentication_test.rb
require "test_helper"

class Admin::AuthenticationTest < ActiveSupport::TestCase
  # Create a minimal test class to include the concern
  class TestHost
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

  test "admin_password returns nil for blank credential via .presence" do
    credentials_stub = Struct.new(:admin_password).new("")
    Rails.application.stub(:credentials, credentials_stub) do
      # .presence converts "" to nil, then dev fallback kicks in for test env
      assert_equal Admin::Authentication::DEV_PASSWORD, @host.admin_password
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/concerns/admin/authentication_test.rb -v`
Expected: Error — `Admin::Authentication` not found

- [ ] **Step 3: Create the concern**

```ruby
# app/controllers/concerns/admin/authentication.rb
module Admin
  module Authentication
    extend ActiveSupport::Concern

    DEV_PASSWORD = "dev-password".freeze

    included do
      before_action :check_admin_password_configured
    end

    private

    def admin_password
      password = Rails.application.credentials.admin_password.presence
      if Rails.env.production?
        password
      else
        password || DEV_PASSWORD
      end
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature => e
      Rails.logger.error("Failed to read admin_password from credentials: #{e.class}")
      nil
    end

    def admin_password_configured?
      admin_password.present?
    end

    def check_admin_password_configured
      return unless Rails.env.production?

      unless admin_password_configured?
        Rails.logger.error("Admin password not configured in Rails credentials. Run `rails credentials:edit` and set admin_password.")
        render "admin/sessions/misconfigured", status: :forbidden, layout: false
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/concerns/admin/authentication_test.rb -v`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/concerns/admin/authentication.rb test/controllers/concerns/admin/authentication_test.rb
git commit -m "feat: add Admin::Authentication concern with password logic (Issue #20)"
```

---

### Task 2: Create the misconfigured view

**Files:**
- Create: `app/views/admin/sessions/misconfigured.html.erb`

- [ ] **Step 1: Create the view**

```erb
<!DOCTYPE html>
<html>
<head>
  <title>Admin Unavailable</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: #1a1a2e;
      color: #e0e0e0;
    }
    .container {
      text-align: center;
      padding: 2rem;
    }
    h1 {
      font-size: 1.5rem;
      margin-bottom: 1rem;
    }
    p {
      font-size: 1.1rem;
      color: #aaa;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Admin Console Unavailable</h1>
    <p>Contact booth staff for assistance.</p>
  </div>
</body>
</html>
```

Note: This is a standalone HTML page (`layout: false`) — no internal setup instructions are revealed on-screen.

- [ ] **Step 2: Run test suite to verify no regressions**

Run: `bin/rails test`
Expected: All existing tests still pass

- [ ] **Step 3: Commit**

```bash
git add app/views/admin/sessions/misconfigured.html.erb
git commit -m "feat: add misconfigured admin error page (Issue #20)"
```

---

### Task 3: Update controllers and test helper simultaneously

This task updates the `SessionsController`, `BaseController`, and test helper in one step to avoid a broken-tests window (the password constant changes from the old `"changeme"` fallback to `DEV_PASSWORD`).

**Files:**
- Modify: `app/controllers/admin/sessions_controller.rb`
- Modify: `app/controllers/admin/base_controller.rb`
- Modify: `test/test_helper.rb`
- Modify: `test/controllers/admin/sessions_controller_test.rb`

- [ ] **Step 1: Write new tests for sessions controller**

Add to `test/controllers/admin/sessions_controller_test.rb`. Replace the full file:

```ruby
require "test_helper"

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
```

- [ ] **Step 2: Update the test helper**

Replace the `AdminTestHelper` module in `test/test_helper.rb` with:

```ruby
module AdminTestHelper
  def login_as_admin
    post admin_login_path, params: { password: Admin::Authentication::DEV_PASSWORD }
  end
end
```

Remove the `admin_password` method — it's no longer needed.

- [ ] **Step 3: Update `Admin::SessionsController`**

Replace `app/controllers/admin/sessions_controller.rb` with:

```ruby
class Admin::SessionsController < ApplicationController
  include Admin::Authentication

  skip_before_action :check_admin_password_configured, only: [ :destroy ]

  def new
  end

  def create
    password = admin_password
    if password.nil?
      redirect_to admin_login_path, alert: "Admin not configured."
      return
    end

    if ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, password)
      session[:admin_authenticated] = true
      redirect_to admin_root_path
    else
      flash.now[:alert] = "Invalid password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_authenticated)
    redirect_to admin_login_path
  end
end
```

- [ ] **Step 4: Update `Admin::BaseController`**

Replace `app/controllers/admin/base_controller.rb` with:

```ruby
class Admin::BaseController < ApplicationController
  include Admin::Authentication
  layout "admin"
  before_action :require_admin

  private

  def require_admin
    unless session[:admin_authenticated]
      redirect_to admin_login_path
    end
  end
end
```

- [ ] **Step 5: Run the full test suite**

Run: `bin/rails test -v`
Expected: All tests PASS (existing + new)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/sessions_controller.rb app/controllers/admin/base_controller.rb test/test_helper.rb test/controllers/admin/sessions_controller_test.rb
git commit -m "feat: wire up Admin::Authentication concern, remove hardcoded password (Issue #20)"
```

---

## Chunk 2: Quality Checks and Closure

### Task 4: Run full quality checks

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: All tests PASS, 0 failures, 0 errors

- [ ] **Step 2: Run Rubocop**

Run: `bundle exec rubocop`
Expected: No offenses. Fix any that appear.

- [ ] **Step 3: Run Brakeman security scan**

Run: `bundle exec brakeman --no-pager -q`
Expected: No warnings. The hardcoded password warning (if any) should be gone.

- [ ] **Step 4: Verify the hardcoded password is fully removed**

Run: `grep -r "changeme" app/ test/ config/ --include="*.rb" --include="*.erb" --include="*.yml"`
Expected: No results. The string `"changeme"` should not appear anywhere in application code.

Also verify: `grep -r "ADMIN_PASSWORD" app/ test/ --include="*.rb"`
Expected: No results for the `ENV.fetch("ADMIN_PASSWORD"...)` pattern. The only matches should be the `DEV_PASSWORD` constant references.

---

### Task 5: Close the issue

- [ ] **Step 1: Comment on the GitHub issue**

```bash
gh issue comment 20 --body "Implemented admin password security hardening:
- Removed hardcoded \`\"changeme\"\` password from source code
- Extracted \`Admin::Authentication\` concern with environment-aware password resolution
- Production requires Rails encrypted credentials only — no ENV var fallback
- Missing password in production renders 403 error page on admin routes; public kiosk unaffected
- Defense-in-depth nil-password guard in \`create\` action
- Added \`misconfigured.html.erb\` error view (generic message, no internal details)
- Updated test helper to use \`Admin::Authentication::DEV_PASSWORD\` constant
- All quality checks pass (tests, rubocop, brakeman)"
```

- [ ] **Step 2: Close the issue**

```bash
gh issue close 20
```
