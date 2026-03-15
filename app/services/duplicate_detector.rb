class DuplicateDetector
  def self.check(entrant)
    return if entrant.eligibility_status != "eligible"
    return if entrant.email.blank? || entrant.first_name.blank? ||
              entrant.last_name.blank? || entrant.company.blank?

    Entrant
      .where.not(id: entrant.id)
      .where(eligibility_status: "eligible")
      .where(
        "LOWER(email) = :email OR (LOWER(first_name) = :first AND LOWER(last_name) = :last AND LOWER(company) = :company)",
        email: entrant.email.downcase,
        first: entrant.first_name.downcase,
        last: entrant.last_name.downcase,
        company: entrant.company.downcase
      )
      .update_all(eligibility_status: "duplicate_review")
  end
end
