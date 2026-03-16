require "test_helper"

class Admin::ManagementControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_admin
  end

  test "GET /admin/management without auth redirects to login" do
    reset!
    get admin_management_path
    assert_redirected_to admin_login_path
  end

  test "show displays management page" do
    get admin_management_path
    assert_response :success
    assert_select "h1", /Management/i
  end

  # --- Reset Drawing ---

  test "POST reset_drawing without auth redirects to login" do
    reset!
    post reset_drawing_admin_management_path
    assert_redirected_to admin_login_path
  end

  test "reset_drawing resets winner statuses to eligible" do
    # winner_carol fixture has eligibility_status: "winner"
    post reset_drawing_admin_management_path
    assert_redirected_to admin_management_path

    entrants(:winner_carol).reload
    assert_equal "eligible", entrants(:winner_carol).eligibility_status
  end

  test "reset_drawing deletes all raffle_draw records" do
    # Create a draw first
    RaffleDraw.perform_full_draw!
    assert RaffleDraw.exists?

    post reset_drawing_admin_management_path
    assert_not RaffleDraw.exists?
  end

  test "reset_drawing when no draw exists shows notice" do
    RaffleDraw.delete_all
    post reset_drawing_admin_management_path
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--notice"
  end

  # --- Populate Demo ---

  test "POST populate_demo without auth redirects to login" do
    reset!
    post populate_demo_admin_management_path
    assert_redirected_to admin_login_path
  end

  test "populate_demo creates 300 entrants when DB is empty" do
    RaffleDraw.delete_all
    Entrant.delete_all

    post populate_demo_admin_management_path
    assert_redirected_to admin_management_path
    assert_equal 300, Entrant.count
  end

  test "populate_demo fails when entrants exist" do
    assert Entrant.exists? # fixtures loaded
    post populate_demo_admin_management_path
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--alert"
  end

  # --- Clear Entrants ---

  test "POST clear_entrants without auth redirects to login" do
    reset!
    post clear_entrants_admin_management_path, params: { confirmation: "reset" }
    assert_redirected_to admin_login_path
  end

  test "clear_entrants deletes all entrants and raffle_draws" do
    RaffleDraw.perform_full_draw!
    assert Entrant.exists?
    assert RaffleDraw.exists?

    post clear_entrants_admin_management_path, params: { confirmation: "reset" }
    assert_redirected_to admin_management_path

    assert_not Entrant.exists?
    assert_not RaffleDraw.exists?
  end

  test "clear_entrants timestamps the submission log" do
    log_dir = Dir.mktmpdir
    log_path = File.join(log_dir, "submissions.jsonl")
    File.write(log_path, '{"test":"data"}' + "\n")

    # Stub the log path used by the controller
    Admin::ManagementController.stub(:submission_log_dir, Pathname.new(log_dir)) do
      post clear_entrants_admin_management_path, params: { confirmation: "reset" }
    end

    assert_not File.exist?(log_path), "Original log should be renamed"
    timestamped = Dir.glob(File.join(log_dir, "submissions-*.jsonl"))
    assert timestamped.any?, "Should have a timestamped log file"
  ensure
    FileUtils.rm_rf(log_dir) if log_dir
  end

  test "clear_entrants rejects wrong confirmation" do
    post clear_entrants_admin_management_path, params: { confirmation: "wrong" }
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--alert"
    assert Entrant.exists?, "Entrants should not be deleted"
  end

  # --- Factory Reset ---

  test "POST factory_reset without auth redirects to login" do
    reset!
    post factory_reset_admin_management_path, params: { confirmation: "delete everything" }
    assert_redirected_to admin_login_path
  end

  test "factory_reset deletes entrants, draws, and logs" do
    log_dir = Dir.mktmpdir
    log_path = File.join(log_dir, "submissions.jsonl")
    archive_path = File.join(log_dir, "submissions-20260316-120000.jsonl")
    File.write(log_path, '{"test":"data"}' + "\n")
    File.write(archive_path, '{"old":"data"}' + "\n")

    Admin::ManagementController.stub(:submission_log_dir, Pathname.new(log_dir)) do
      post factory_reset_admin_management_path, params: { confirmation: "delete everything" }
    end
    assert_redirected_to admin_management_path

    assert_not Entrant.exists?
    assert_not RaffleDraw.exists?
    assert_not File.exist?(log_path)
    assert_not File.exist?(archive_path)
  ensure
    FileUtils.rm_rf(log_dir) if log_dir
  end

  test "factory_reset deletes USB backup files" do
    usb_dir = Dir.mktmpdir
    File.write(File.join(usb_dir, "raffle.sqlite3"), "fake db")
    File.write(File.join(usb_dir, "submissions.jsonl"), '{"data":"usb"}')

    UsbBackup.stub(:find_usb_mount, usb_dir) do
      Admin::ManagementController.stub(:submission_log_dir, Pathname.new(Dir.mktmpdir)) do
        post factory_reset_admin_management_path, params: { confirmation: "delete everything" }
      end
    end

    assert_not File.exist?(File.join(usb_dir, "raffle.sqlite3"))
    assert_not File.exist?(File.join(usb_dir, "submissions.jsonl"))
  ensure
    FileUtils.rm_rf(usb_dir) if usb_dir
  end

  test "factory_reset rejects wrong confirmation" do
    post factory_reset_admin_management_path, params: { confirmation: "wrong" }
    assert_redirected_to admin_management_path
    follow_redirect!
    assert_select ".admin-flash--alert"
    assert Entrant.exists?, "Entrants should not be deleted"
  end
end
