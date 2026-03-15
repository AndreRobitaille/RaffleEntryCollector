class KioskController < ApplicationController
  def attract
  end

  def new
    @entrant = Entrant.new
  end

  def create
    @entrant = Entrant.new(entrant_params)

    if @entrant.save
      SubmissionLogger.log(@entrant)
      DuplicateDetector.check(@entrant)
      redirect_to success_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def success
  end

  private

  def entrant_params
    params.require(:entrant).permit(
      :first_name, :last_name, :email, :company, :job_title,
      :eligibility_confirmed, interest_areas: []
    )
  end
end
