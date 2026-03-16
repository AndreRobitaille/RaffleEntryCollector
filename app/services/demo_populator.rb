class DemoPopulator
  class DatabaseNotEmpty < StandardError; end

  FIRST_NAMES = %w[
    Alex Jordan Taylor Morgan Casey Riley Quinn Avery Parker Sawyer
    Dakota Hayden Charlie Emerson Blake Rowan Finley Sage Reese Peyton
    Jamie Skyler Cameron Phoenix Drew Kai Logan Harper Bailey Micah
    Elena Sofia Aria Nora Maya Chloe Lily Zara Mila Layla
    Marcus Ethan Liam Noah Owen Caleb Jude Felix Oscar Theo
    Priya Anika Ravi Arjun Sanjay Mei Lin Wei Chen Hiro
    Fatima Omar Amira Hassan Leila Yuki Kenji Soren Astrid Ingrid
    Diego Rosa Lucia Carlos Mateo Gabriela Rafael Valentina Andres Isabel
    Nneka Emeka Amara Kwame Zuri Tendai Chioma Farai Nalini Kofi
    Sasha Ivan Dmitri Katya Nikolai Alena Boris Marta Jakub Petra
  ].freeze

  LAST_NAMES = %w[
    Chen Patel Rodriguez Kim Nguyen Okafor Mueller Yamamoto Johansson Costa
    Singh Park Thompson Garcia Williams Brown Martinez Anderson Jackson Lee
    Hartley Reeves Bishop Vasquez Thornton Callahan Moreau Delgado Erikson Wolff
    Nakamura Fitzgerald Kaur Tanaka Stein Dubois Kowalski Rossi Lindgren Becker
    Shah Adeyemi Bergman Takahashi Molina Holmberg Fernandez Volkov Chandra Nystrom
    Okonkwo Torres Brennan Ishikawa Petrov Magnusson Herrera Kato Larsson Mendez
    Weber Sato Lindqvist Ramirez Akiyama Strand Gutierrez Fujita Berglund Santos
    Iwata Norberg Reyes Shimizu Engstrom Aguilar Hashimoto Hedlund Cruz Ogawa
    Karlsson Dominguez Matsuda Forsberg Castillo Ono Sandberg Guerrero Ueda Ekman
    Navarro Hayashi Sjoberg Medina Watanabe Lund Ortega Morimoto Dahlin Vega
  ].freeze

  COMPANIES = [
    "CrowdStrike", "Palo Alto Networks", "Mandiant", "Recorded Future", "Tenable",
    "Rapid7", "SentinelOne", "Fortinet", "Zscaler", "Snyk",
    "Trail of Bits", "NCC Group", "Bishop Fox", "Coalfire", "Secureworks",
    "Dragos", "Claroty", "Nozomi Networks", "Armis", "Phosphorus",
    "Accenture Security", "Deloitte Cyber", "PwC Cybersecurity", "KPMG Security", "EY Cybersecurity",
    "Google Security", "Microsoft Security", "AWS Security", "Apple Security", "Meta Security",
    "Northrop Grumman", "Raytheon", "Lockheed Martin", "Boeing Defense", "L3Harris",
    "Sandia National Labs", "MITRE", "APL Johns Hopkins", "MIT Lincoln Lab", "JPL",
    "University of Wisconsin", "UW-Milwaukee", "Marquette University", "MSOE", "Carthage College",
    "Northwestern Mutual", "Rockwell Automation", "Johnson Controls", "Harley-Davidson", "Kohl's",
    "Foxconn", "Generac", "Epic Systems", "Exact Sciences", "Oshkosh Corp",
    "Independent Consultant", "Freelance Researcher", "Self-Employed", "Student", "Retired"
  ].freeze

  JOB_TITLES = [
    "Security Engineer", "Senior Security Engineer", "Staff Security Engineer",
    "Penetration Tester", "Senior Penetration Tester", "Red Team Operator",
    "Security Analyst", "Senior Security Analyst", "SOC Analyst",
    "CISO", "VP of Security", "Director of Security", "Security Manager",
    "Application Security Engineer", "Cloud Security Engineer", "DevSecOps Engineer",
    "Threat Intelligence Analyst", "Incident Response Lead", "Forensic Analyst",
    "Security Architect", "Principal Security Architect", "Security Consultant",
    "GRC Analyst", "Compliance Manager", "Risk Analyst",
    "Firmware Engineer", "Embedded Systems Engineer", "IoT Security Researcher",
    "Malware Analyst", "Reverse Engineer", "Vulnerability Researcher",
    "Security Researcher", "Cryptographer", "Privacy Engineer",
    "Network Engineer", "Systems Administrator", "IT Director",
    "Software Engineer", "Full Stack Developer", "Platform Engineer",
    "Student", "Research Assistant", "Intern"
  ].freeze

  INTEREST_AREAS = Entrant::INTEREST_AREA_OPTIONS

  SPONSOR_COMPANIES = [
    "CypherCon Events LLC",
    "Badger State Brewing Co",
    "MKE Tech Solutions"
  ].freeze

  INDIVIDUAL_EXCLUSIONS = [
    { reason: "Requested removal from raffle" },
    { reason: "Not conference attendee" },
    { reason: "Duplicate badge scan — same person, different email" }
  ].freeze

  def self.populate!
    raise DatabaseNotEmpty, "Cannot populate: entrants already exist" if Entrant.exists?

    now = Time.current
    records = []

    # Generate ~280 normal eligible entrants
    280.times { records << build_entrant(now: now) }

    # ~8 duplicates: resubmissions of existing entrants (same email)
    8.times do
      original = records.sample
      dup = original.dup
      dup[:created_at] = original[:created_at] + rand(60..3600)
      dup[:updated_at] = dup[:created_at]
      dup[:eligibility_status] = "duplicate_review"
      records << dup
    end

    # 3 individual exclusions from random companies
    INDIVIDUAL_EXCLUSIONS.each do |excl|
      record = build_entrant(now: now)
      record[:eligibility_status] = "excluded_admin"
      record[:exclusion_reason] = excl[:reason]
      records << record
    end

    # Sponsor/vendor companies: 3 entrants each, all excluded
    SPONSOR_COMPANIES.each do |company|
      3.times do
        record = build_entrant(now: now, company: company)
        record[:eligibility_status] = "excluded_admin"
        record[:exclusion_reason] = "CypherCon sponsor employee"
        records << record
      end
    end

    Entrant.insert_all(records)
  end

  def self.build_entrant(now:, company: nil)
    first = FIRST_NAMES.sample
    last = LAST_NAMES.sample
    company ||= COMPANIES.sample
    email_domain = company.downcase.gsub(/[^a-z0-9]/, "") + ".com"
    email = "#{first.downcase}.#{last.downcase}@#{email_domain}"
    created = now - rand(0..172_800)

    {
      first_name: first,
      last_name: last,
      email: email,
      company: company,
      job_title: JOB_TITLES.sample,
      interest_areas: INTEREST_AREAS.sample(rand(1..4)),
      eligibility_confirmed: true,
      eligibility_status: "eligible",
      exclusion_reason: nil,
      created_at: created,
      updated_at: created
    }
  end
  private_class_method :build_entrant
end
