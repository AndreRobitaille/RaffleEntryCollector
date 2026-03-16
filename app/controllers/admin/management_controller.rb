class Admin::ManagementController < Admin::BaseController
  def show
    @entrant_count = Entrant.count
    @draw_exists = RaffleDraw.exists?
  end

  def reset_drawing
    ActiveRecord::Base.transaction do
      Entrant.where(eligibility_status: %w[winner alternate_winner])
             .update_all(eligibility_status: "eligible")
      RaffleDraw.delete_all
    end
    redirect_to admin_management_path, notice: "Drawing has been reset. All winners restored to eligible."
  end
end
