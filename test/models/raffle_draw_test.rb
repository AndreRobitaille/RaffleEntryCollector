require "test_helper"

class RaffleDrawTest < ActiveSupport::TestCase
  setup do
    # Clear fixtures — we create our own entrants for these tests
    RaffleDraw.delete_all
    Entrant.delete_all

    3.times do |i|
      Entrant.create!(first_name: "User#{i}", last_name: "Test", email: "user#{i}@example.com",
                      company: "Co", job_title: "Dev", eligibility_confirmed: true)
    end
    Entrant.create!(first_name: "Excluded", last_name: "User", email: "ex@example.com",
                    company: "Co", job_title: "Dev", eligibility_confirmed: true, eligibility_status: "excluded_admin")
  end

  test "perform_draw selects a winner from eligible entries" do
    draw = RaffleDraw.perform_draw!
    assert draw.persisted?
    assert_equal 3, draw.eligible_count
    assert draw.winner.present?
    assert_equal "winner", draw.winner.eligibility_status
  end

  test "perform_draw does not select excluded entries" do
    10.times do
      draw = RaffleDraw.perform_draw!
      assert_not_equal "Excluded", draw.winner.first_name
      # Reset for next iteration
      draw.winner.update!(eligibility_status: "eligible")
      draw.destroy!
    end
  end

  test "alternate draw excludes previous winners" do
    first_draw = RaffleDraw.perform_draw!
    second_draw = RaffleDraw.perform_draw!

    assert_equal "alternate_winner", second_draw.winner.eligibility_status
    assert_not_equal first_draw.winner_id, second_draw.winner_id
  end

  test "draw fails when no eligible entries" do
    Entrant.eligible.update_all(eligibility_status: "excluded_admin")
    assert_raises(RaffleDraw::NoEligibleEntrants) do
      RaffleDraw.perform_draw!
    end
  end

  test "perform_draw saves admin_note when provided" do
    draw = RaffleDraw.perform_draw!(admin_note: "Primary draw at conference")
    assert_equal "Primary draw at conference", draw.admin_note
  end

  test "draw_type is winner for first draw and alternate_winner for subsequent" do
    first_draw = RaffleDraw.perform_draw!
    assert_equal "winner", first_draw.draw_type

    second_draw = RaffleDraw.perform_draw!
    assert_equal "alternate_winner", second_draw.draw_type
  end
end
