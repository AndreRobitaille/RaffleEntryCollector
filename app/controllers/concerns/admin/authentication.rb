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
