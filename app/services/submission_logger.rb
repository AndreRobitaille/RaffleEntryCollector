class SubmissionLogger
  DEFAULT_LOG_PATH = Rails.root.join("log", "submissions.jsonl")

  def self.log(entrant, log_path: DEFAULT_LOG_PATH)
    entry = {
      id: entrant.id,
      first_name: entrant.first_name,
      last_name: entrant.last_name,
      email: entrant.email,
      company: entrant.company,
      job_title: entrant.job_title,
      interest_areas: entrant.interest_areas,
      eligibility_confirmed: entrant.eligibility_confirmed,
      created_at: entrant.created_at&.iso8601,
      logged_at: Time.current.iso8601
    }

    File.open(log_path, "a") do |f|
      f.puts(entry.to_json)
      f.flush
      f.fsync
    end
  end
end
