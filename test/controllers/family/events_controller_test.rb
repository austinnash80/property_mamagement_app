require "test_helper"

class Family::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = User.create!(email: "family-events@example.com", name: "Austin", password: "test-pass", role: "family")
    @other = User.create!(email: "family-other@example.com",  name: "Christina", password: "test-pass", role: "family")
    post login_path, params: { email: @user.email, password: "test-pass" }
  end

  test "new event defaults who it's for to the signed-in person, with other choices still offered" do
    get new_family_event_path
    assert_response :success

    assert_select "select#family_event_person_id" do
      assert_select "option[selected][value=?]", @user.id.to_s, text: "Austin"
      assert_select "option[value=?]", @other.id.to_s, text: "Christina"
      assert_select "option[value='']", text: "Everyone"
    end
  end

  test "calendar shows events but not to-dos" do
    list = Family::List.create!(name: "Home improvement")
    Family::Task.create!(list: list, title: "Fix the gate latch")
    Family::Event.create!(title: "Dentist", starts_on: Family.today)

    get family_calendar_path
    assert_response :success
    assert_select "a.fa-cal-event", text: /Dentist/
    assert_select "a.fa-cal-task", 0
    assert_no_match "Fix the gate latch", response.body
  end

  test "event titles lose stray spaces, so the morning digest reads cleanly" do
    event = Family::Event.create!(title: "Gym - Reformer lesson ", starts_on: Family.today, start_time: "14:00")
    assert_equal "Gym - Reformer lesson", event.title
    assert_equal "Gym - Reformer lesson 2p (both)", Family::Digest.body_for([event], Family.today)
  end
end
