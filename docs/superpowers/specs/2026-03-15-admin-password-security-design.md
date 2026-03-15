# Admin Password Security Design

## Problem

`Admin::SessionsController` has a plaintext password fallback hardcoded in source code:

```ruby
Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
```

This is committed to a public repository. The default `"changeme"` password is readable by anyone. This is unacceptable, especially for an app deployed at a security conference.

## Design Decisions

1. **Production password source:** Rails encrypted credentials only (`Rails.application.credentials.admin_password`). No environment variable fallback — credentials are encrypted at rest, unlike plaintext in a systemd unit file.
2. **Dev/test behavior:** Development falls back to a hardcoded dev password so local development isn't painful. Tests use a fixed test password in the test helper.
3. **Missing password behavior:** If the admin password credential is not configured in production, the public kiosk entry form continues working normally. Only `/admin/*` routes are affected — they render a misconfiguration error page instead of the login form.

## Changes

### 1. Extract shared logic into `Admin::Authentication` concern

To avoid duplicating password logic between `Admin::BaseController` and `Admin::SessionsController`, extract the shared code into a concern:

```ruby
# app/controllers/concerns/admin/authentication.rb
module Admin::Authentication
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
```

Key points:
- `DEV_PASSWORD` constant avoids string duplication between controller and test helper
- `.presence` converts blank strings to `nil`, preventing empty-password auth
- `rescue` handles corrupted credentials/master key gracefully
- Logs the misconfiguration for diagnosis
- Uses `403 Forbidden` (not `503`) — this is a configuration issue, not a temporary outage

### 2. `Admin::SessionsController`

Include the concern. Add defense-in-depth in the `create` action — do not rely solely on the before_action:

```ruby
class Admin::SessionsController < ApplicationController
  include Admin::Authentication

  # check_admin_password_configured runs via concern, except on destroy
  skip_before_action :check_admin_password_configured, only: [:destroy]

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

  # destroy is excluded from check_admin_password_configured
  # so an authenticated admin can always log out
end
```

### 3. `Admin::BaseController`

Include the concern instead of duplicating the logic:

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

### 4. `test/test_helper.rb`

Reference the constant from the concern:

```ruby
def login_as_admin
  post admin_login_path, params: { password: Admin::Authentication::DEV_PASSWORD }
end
```

### 5. New view: `app/views/admin/sessions/misconfigured.html.erb`

A generic error page — no internal tooling details revealed on-screen (security conference audience):

- Message: "Admin console unavailable — contact booth staff"
- No instructions about `rails credentials:edit` in the HTML (those go in the log message and deployment docs only)

### Test coverage

New test scenarios required:

1. **Misconfiguration rendering** — stub `admin_password` to return `nil`, verify `/admin/login` renders misconfigured page with 403
2. **Kiosk unaffected** — verify public entry routes work regardless of admin password configuration
3. **Dev fallback works** — verify login with `DEV_PASSWORD` succeeds in test environment
4. **Blank password rejected** — verify that setting `admin_password: ""` in credentials does not allow empty-string authentication
5. **Logout always works** — verify `DELETE /admin/logout` is not blocked by misconfiguration check

### What stays the same

- `ActiveSupport::SecurityUtils.secure_compare` for timing-attack resistance
- Session-based authentication flow
- Password parameter filtering in logs
- `autocomplete: "off"` on login form
- All admin routes and controller structure

## Deployment

The `master.key` file must be present on the Pi for credentials decryption. Deployment workflow:

1. On dev machine: `rails credentials:edit`, set `admin_password: <secure value>`
2. Copy `config/master.key` to the Pi (once, during initial setup)
3. `credentials.yml.enc` is deployed via the repo as usual
