require "test_helper"
require "csv"

class Admin::ExportsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/export without auth redirects to login" do
    get admin_export_path
    assert_redirected_to admin_login_path
  end

  test "GET /admin/export/download without auth redirects to login" do
    get admin_export_download_path
    assert_redirected_to admin_login_path
  end

  test "GET /admin/export renders export page" do
    login_as_admin
    get admin_export_path
    assert_response :success
  end

  test "GET /admin/export/download with type=eligible returns CSV with only eligible and reinstated entries" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }
    assert_response :success
    assert_equal "text/csv", response.content_type.split(";").first

    csv = CSV.parse(response.body, headers: true)
    statuses = csv.map { |row| row["eligibility_status"] }
    assert_includes statuses, "eligible"
    assert_includes statuses, "reinstated_admin"
    refute_includes statuses, "excluded_admin"
    refute_includes statuses, "duplicate_review"
    refute_includes statuses, "self_attested_ineligible"
    refute_includes statuses, "winner"
  end

  test "GET /admin/export/download with type=all returns CSV with all entries" do
    login_as_admin
    get admin_export_download_path, params: { type: "all" }
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    assert_equal Entrant.count, csv.length
  end

  test "GET /admin/export/download without type defaults to eligible" do
    login_as_admin
    get admin_export_download_path
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    statuses = csv.map { |row| row["eligibility_status"] }.uniq
    statuses.each do |status|
      assert_includes %w[eligible reinstated_admin], status
    end
  end

  test "GET /admin/export/download with invalid type defaults to eligible" do
    login_as_admin
    get admin_export_download_path, params: { type: "garbage" }
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    statuses = csv.map { |row| row["eligibility_status"] }.uniq
    statuses.each do |status|
      assert_includes %w[eligible reinstated_admin], status
    end
  end

  test "CSV has correct Content-Disposition with filename and timestamp" do
    login_as_admin
    get admin_export_download_path, params: { type: "all" }
    disposition = response.headers["Content-Disposition"]
    assert_match(/attachment/, disposition)
    assert_match(/raffle-entries-all-\d{8}-\d{6}\.csv/, disposition)
  end

  test "CSV header row contains expected column names in correct order" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }

    csv = CSV.parse(response.body, headers: true)
    expected_headers = %w[
      first_name last_name email company job_title created_at eligibility_status
      penetration_testing red_team app_security cloud_infra_security
      hardware_iot_security space_systems_security security_training
    ]
    assert_equal expected_headers, csv.headers
  end

  test "interest area columns contain 1 or 0 values" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }

    csv = CSV.parse(response.body, headers: true)
    interest_columns = %w[
      penetration_testing red_team app_security cloud_infra_security
      hardware_iot_security space_systems_security security_training
    ]

    csv.each do |row|
      interest_columns.each do |col|
        assert_includes %w[0 1], row[col], "Expected 0 or 1 for #{col}, got #{row[col]}"
      end
    end
  end

  test "interest area columns reflect entrant data correctly" do
    login_as_admin
    get admin_export_download_path, params: { type: "eligible" }

    csv = CSV.parse(response.body, headers: true)
    ada_row = csv.find { |row| row["email"] == "ada@example.com" }
    assert_equal "1", ada_row["penetration_testing"]
    assert_equal "1", ada_row["app_security"]
    assert_equal "0", ada_row["red_team"]
    assert_equal "0", ada_row["security_training"]

    diana_row = csv.find { |row| row["email"] == "diana@example.com" }
    assert_equal "1", diana_row["cloud_infra_security"]
    assert_equal "1", diana_row["space_systems_security"]
    assert_equal "0", diana_row["penetration_testing"]
  end

  private

  def login_as_admin
    post admin_login_path, params: { password: admin_password }
  end

  def admin_password
    Rails.application.credentials.admin_password || ENV.fetch("ADMIN_PASSWORD", "changeme")
  end
end
