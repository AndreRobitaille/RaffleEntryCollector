class Admin::SessionsController < ApplicationController
  def new
  end

  def create
    if params[:password] == admin_password
      session[:admin_authenticated] = true
      redirect_to admin_root_path
    else
      flash.now[:alert] = "Invalid password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_authenticated)
    redirect_to admin_login_path
  end

  private

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
  end
end
