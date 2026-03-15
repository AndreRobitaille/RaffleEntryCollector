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
