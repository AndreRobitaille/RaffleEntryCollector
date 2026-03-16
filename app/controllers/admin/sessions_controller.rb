class Admin::SessionsController < ApplicationController
  include Admin::Authentication
  layout "admin"

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
    reset_session
    redirect_to root_path
  end
end
