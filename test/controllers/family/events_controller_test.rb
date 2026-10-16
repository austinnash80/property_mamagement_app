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
  test "creates annual birthday and displays next year's occurrence" do
    post family_events_path, params: { family_event: {
      title: "Birthday", starts_on: "2026-05-12", repeat_frequency: "annually"
    } }
    birthday = Family::Event.last
    assert_equal "annually", birthday.repeat_frequency
    get family_calendar_path(month: "2027-05")
    assert_response :success
    assert_select "a.fa-cal-event[href=?]", family_event_path(birthday, occurrence_on: "2027-05-12"), text: /Birthday/
    get family_event_path(birthday, occurrence_on: "2027-05-12")
    assert_response :success
    assert_match "May 12, 2027", response.body
    assert_select "a", text: "Edit this occurrence"
    assert_select "a", text: "Edit series"
  end

  test "repeat options and optional end date are available on the form" do
    get new_family_event_path
    assert_select "select#family_event_repeat_frequency option", count: 5
    assert_select "input#family_event_repeat_until[type=date]"
  end

  test "edits and deletes one occurrence without changing the series" do
    birthday = Family::Event.create!(title: "Birthday", starts_on: "2020-05-12", repeat_frequency: "annually")
    get edit_family_event_path(birthday, occurrence_on: "2027-05-12")
    assert_response :success
    assert_select "form[action=?]", family_event_path(birthday, occurrence_on: "2027-05-12")
    assert_select "input[name='family_event[starts_on]'][value='2027-05-12']"
    assert_select "select#family_event_repeat_frequency", count: 0
    patch family_event_path(birthday, occurrence_on: "2027-05-12"), params: {
      family_event: { title: "Birthday party", starts_on: "2027-05-13", location: "Park" }
    }
    assert_redirected_to family_event_path(birthday, occurrence_on: "2027-05-12")
    assert_equal "Birthday", birthday.reload.title
    assert_empty Family::Event.occurrences_between(Date.new(2027, 5, 12)..Date.new(2027, 5, 12))
    get family_calendar_path(month: "2027-05")
    assert_response :success
    assert_select "a.fa-cal-event", text: /Birthday party/
    get family_event_path(birthday, occurrence_on: "2027-05-12")
    assert_match "May 13, 2027", response.body
    patch family_event_path(birthday, occurrence_on: "2027-05-12"), params: { family_event: { title: "Revised party" } }
    assert_equal 1, birthday.recurrence_overrides.count
    delete family_event_path(birthday, occurrence_on: "2027-05-12")
    assert_redirected_to family_calendar_path(month: "2027-05")
    assert_empty Family::Event.occurrences_between(Date.new(2027, 5, 13)..Date.new(2027, 5, 13))
    assert_equal "Birthday", birthday.occurrence_on(Date.new(2028, 5, 12)).title
  end

  test "whole series can be edited and deleted and invalid changes show errors" do
    birthday = Family::Event.create!(title: "Birthday", starts_on: "2020-05-12", repeat_frequency: "annually")
    patch family_event_path(birthday), params: { family_event: { title: "Annual birthday" } }
    assert_redirected_to family_event_path(birthday)
    assert_equal "Annual birthday", birthday.reload.occurrence_on(Date.new(2027, 5, 12)).title
    patch family_event_path(birthday, occurrence_on: "2027-05-12"), params: { family_event: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "form[action=?]", family_event_path(birthday, occurrence_on: "2027-05-12")
    assert_equal 0, birthday.recurrence_overrides.count
    delete family_event_path(birthday)
    assert_not Family::Event.exists?(birthday.id)
  end

  test "invalid occurrence dates cannot alter the series" do
    birthday = Family::Event.create!(title: "Birthday", starts_on: "2020-05-12", repeat_frequency: "annually")
    ["bad-date", "2027-05-13", "2019-05-12"].each do |day|
      assert_raises(ActiveRecord::RecordNotFound) do
        patch family_event_path(birthday, occurrence_on: day), params: { family_event: { title: "Wrong" } }
      end
    end
    assert_equal "Birthday", birthday.reload.title
  end

  test "repeat events appear in the dashboard and upcoming list" do
    travel_to Time.zone.local(2030, 5, 10, 12) do
      Family::Event.create!(title: "Birthday", starts_on: "2020-05-12", repeat_frequency: "annually")
      get family_root_path
      assert_response :success
      assert_match "Next up: Birthday, May 12", response.body
      assert_match "1 event in the next 7 days", response.body
      get family_calendar_path
      assert_response :success
      assert_select ".fa-task-title a", text: "Birthday"
    end
  end

  test "ordinary event details and editing still work" do
    event = Family::Event.create!(title: "Dentist", starts_on: Family.today, location: "Office")
    get family_event_path(event)
    assert_response :success
    assert_select "a", text: "Edit"
    assert_select "a", text: "Delete event"
    assert_select "a", text: "Edit this occurrence", count: 0
    get edit_family_event_path(event)
    assert_response :success
    patch family_event_path(event), params: { family_event: { notes: "Bring paperwork" } }
    assert_redirected_to family_event_path(event)
    assert_equal "Bring paperwork", event.reload.notes
  end

  test "invalid repeat frequency and cutoff redisplay create errors" do
    assert_no_difference -> { Family::Event.count } do
      post family_events_path, params: { family_event: {
        title: "Bad repeat", starts_on: "2026-05-12", repeat_frequency: "hourly"
      } }
    end
    assert_response :unprocessable_entity
    assert_select "select#family_event_repeat_frequency"
    post family_events_path, params: { family_event: {
      title: "Bad cutoff", starts_on: "2026-05-12", repeat_frequency: "weekly", repeat_until: "2026-05-01"
    } }
    assert_response :unprocessable_entity
  end

end
