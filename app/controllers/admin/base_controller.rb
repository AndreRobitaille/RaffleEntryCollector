class Admin::BaseController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    unless session[:admin_authenticated]
      redirect_to admin_login_path
    end
  end
end
