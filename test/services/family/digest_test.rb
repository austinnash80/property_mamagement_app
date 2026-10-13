require "test_helper"

class Family::DigestTest < ActiveSupport::TestCase
  setup do
    @austin    = User.create!(email: "digest-austin@example.com",    name: "Austin",    password: "test-pass", role: "family")
    @christina = User.create!(email: "digest-christina@example.com", name: "Christina", password: "test-pass", role: "family")
    @day = Date.new(2026, 10, 14)
  end

  def body_for(user)
    events = Family::Event.overlapping(@day..@day).to_a
    Family::Digest.body_for(Family::Digest.events_for(events, user.id), @day)
  end

  test "each person gets their own events plus everyone's, never someone else's" do
    Family::Event.create!(title: "Reformer lesson", starts_on: @day, start_time: "14:00", person: @austin)
    Family::Event.create!(title: "Dentist", starts_on: @day, start_time: "15:30", person: @christina)
    Family::Event.create!(title: "Dinner at Mom's", starts_on: @day, start_time: "18:00")

    assert_equal "Dentist 3:30p · Dinner at Mom's 6p (both)", body_for(@christina)
    assert_equal "Reformer lesson 2p · Dinner at Mom's 6p (both)", body_for(@austin)
  end

  test "a free day still gets a ping" do
    Family::Event.create!(title: "Reformer lesson", starts_on: @day, person: @austin)
    assert_equal Family::Digest::FREE_DAY, body_for(@christina)
  end

  test "multi-day events say which day it is and only show the time on day one" do
    Family::Event.create!(title: "Tahoe", starts_on: @day - 1, ends_on: @day + 1, start_time: "09:00")
    assert_equal "Tahoe (both, day 2 of 3)", body_for(@christina)
  end

  test "more than three events end with a count" do
    4.times { |i| Family::Event.create!(title: "Thing #{i}", starts_on: @day, person: @christina) }
    assert_match(/ · \+1 more\z/, body_for(@christina))
  end

  test "send_morning! sends every device its own line, once a day" do
    sub = Family::PushSubscription.create!(user: @christina, endpoint: "https://push.example/1", p256dh: "k", auth: "a")
    sent = []
    Family::Notifier.stub(:deliver, ->(s, **msg) { sent << [s.id, msg[:body]]; true }) do
      Family::Digest.send_morning!(@day)
      Family::Digest.send_morning!(@day)
    end
    assert_equal [[sub.id, Family::Digest::FREE_DAY]], sent
  end

  test "to-dos assigned to that person are counted every day, nobody else's" do
    list = Family::List.create!(name: "Home improvement")
    Family::Task.create!(list: list, title: "Fix the gate latch", assignee: @christina)
    Family::Task.create!(list: list, title: "Paint the fence", assignee: @christina)
    Family::Task.create!(list: list, title: "Old one", assignee: @christina, done_at: Time.current)
    Family::Task.create!(list: list, title: "Clean gutters", assignee: @austin)
    Family::Task.create!(list: list, title: "Anyone's", assignee: nil)
    Family::Event.create!(title: "Dentist", starts_on: @day, start_time: "15:30", person: @christina)
    sub = Family::PushSubscription.create!(user: @christina, endpoint: "https://push.example/2", p256dh: "k", auth: "a")

    sent = []
    Family::Notifier.stub(:deliver, ->(s, **msg) { sent << msg[:body]; true }) do
      Family::Digest.send_morning!(@day)
    end
    assert_equal ["Dentist 3:30p · 2 to-dos for you"], sent
  end

  test "a free day with one to-do" do
    assert_equal "Nothing on the calendar today · 1 to-do for you", Family::Digest.body_for([], @day, todos: 1)
  end
end
